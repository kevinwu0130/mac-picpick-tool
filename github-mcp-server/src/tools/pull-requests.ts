import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { githubRequest, handleGitHubError, truncateIfNeeded } from "../github-client.js";
import { ResponseFormat, type GitHubPR } from "../types.js";
import { CHARACTER_LIMIT, DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from "../constants.js";

function formatPR(pr: GitHubPR): string {
  return [
    `## #${pr.number}: ${pr.title}`,
    `- **State**: ${pr.state}${pr.draft ? " (draft)" : ""} | **Author**: ${pr.user.login}`,
    `- **Branch**: \`${pr.head.ref}\` → \`${pr.base.ref}\``,
    `- **Merged**: ${pr.merged} | **Mergeable**: ${pr.mergeable ?? "unknown"}`,
    `- **Created**: ${new Date(pr.created_at).toLocaleString()} | **Updated**: ${new Date(pr.updated_at).toLocaleString()}`,
    `- **URL**: ${pr.html_url}`,
    pr.body ? `\n${pr.body.slice(0, 500)}${pr.body.length > 500 ? "..." : ""}` : "",
  ].filter(Boolean).join("\n");
}

export function registerPRTools(server: McpServer): void {
  server.registerTool(
    "github_list_prs",
    {
      title: "List GitHub Pull Requests",
      description: `List pull requests for a repository.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - state ('open' | 'closed' | 'all'): Filter by state (default: 'open')
  - head (string): Filter by head branch (format: 'user:branch')
  - base (string): Filter by base branch name
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: List of pull requests with metadata.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        state: z.enum(["open", "closed", "all"]).default("open").describe("Filter by PR state"),
        head: z.string().optional().describe("Filter by head branch (format: 'user:branch')"),
        base: z.string().optional().describe("Filter by base branch name"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, state, head, base, per_page, page, response_format }) => {
      try {
        const prs = await githubRequest<GitHubPR[]>(
          `/repos/${owner}/${repo}/pulls`, "GET", undefined,
          { state, head, base, per_page, page }
        );

        if (!prs.length) {
          return { content: [{ type: "text", text: `No ${state} pull requests found in ${owner}/${repo}.` }] };
        }

        const output = {
          count: prs.length, page,
          has_more: prs.length === per_page,
          ...(prs.length === per_page ? { next_page: page + 1 } : {}),
          pull_requests: prs.map(pr => ({
            number: pr.number, title: pr.title, state: pr.state, draft: pr.draft,
            user: pr.user.login, head: pr.head.ref, base: pr.base.ref,
            created_at: pr.created_at, html_url: pr.html_url,
          })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [`# Pull Requests in ${owner}/${repo} (${state}, page ${page})`, `Showing ${prs.length} PRs`, ""];
        for (const pr of prs) lines.push(formatPR(pr), "");
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_get_pr",
    {
      title: "Get GitHub Pull Request",
      description: `Fetch a single pull request by number.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - pr_number (number): Pull request number
  - response_format: Output format

Returns: Full PR details including body, branches, merge status.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        pr_number: z.number().int().min(1).describe("Pull request number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, pr_number, response_format }) => {
      try {
        const pr = await githubRequest<GitHubPR>(`/repos/${owner}/${repo}/pulls/${pr_number}`);
        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(pr, null, 2) }] };
        }
        return { content: [{ type: "text", text: formatPR(pr) }] };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_create_pr",
    {
      title: "Create GitHub Pull Request",
      description: `Create a new pull request.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - title (string): PR title
  - head (string): Branch containing changes (e.g. 'feature/my-feature')
  - base (string): Branch to merge into (e.g. 'main')
  - body (string): PR description (Markdown supported)
  - draft (boolean): Create as draft PR (default: false)

Returns: Created PR number and URL.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        title: z.string().min(1).max(256).describe("PR title"),
        head: z.string().min(1).describe("Source branch with changes"),
        base: z.string().min(1).describe("Target branch to merge into"),
        body: z.string().optional().describe("PR description (Markdown)"),
        draft: z.boolean().default(false).describe("Create as draft PR"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async ({ owner, repo, title, head, base, body, draft }) => {
      try {
        const pr = await githubRequest<GitHubPR>(
          `/repos/${owner}/${repo}/pulls`, "POST",
          { title, head, base, body, draft }
        );
        return {
          content: [{ type: "text", text: `Created PR #${pr.number}: ${pr.title}\n${pr.html_url}` }],
          structuredContent: { number: pr.number, title: pr.title, html_url: pr.html_url },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_merge_pr",
    {
      title: "Merge GitHub Pull Request",
      description: `Merge an open pull request.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - pr_number (number): Pull request number
  - merge_method ('merge' | 'squash' | 'rebase'): Merge strategy (default: 'merge')
  - commit_title (string): Custom commit title (optional, for merge/squash)
  - commit_message (string): Custom commit message (optional, for merge/squash)

Returns: Merge SHA and confirmation message.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        pr_number: z.number().int().min(1).describe("Pull request number"),
        merge_method: z.enum(["merge", "squash", "rebase"]).default("merge").describe("Merge strategy"),
        commit_title: z.string().optional().describe("Custom merge commit title"),
        commit_message: z.string().optional().describe("Custom merge commit message"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true },
    },
    async ({ owner, repo, pr_number, merge_method, commit_title, commit_message }) => {
      try {
        const result = await githubRequest<{ sha: string; merged: boolean; message: string }>(
          `/repos/${owner}/${repo}/pulls/${pr_number}/merge`, "PUT",
          { merge_method, commit_title, commit_message }
        );
        return {
          content: [{ type: "text", text: `${result.message}\nSHA: ${result.sha}` }],
          structuredContent: { sha: result.sha, merged: result.merged, message: result.message },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );
}
