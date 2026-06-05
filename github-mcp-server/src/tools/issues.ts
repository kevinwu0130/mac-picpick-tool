import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { githubRequest, handleGitHubError, truncateIfNeeded } from "../github-client.js";
import { ResponseFormat, type GitHubIssue } from "../types.js";
import { CHARACTER_LIMIT, DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from "../constants.js";

function formatIssue(issue: GitHubIssue): string {
  const labels = issue.labels.map(l => l.name).join(", ") || "none";
  const assignees = issue.assignees.map(a => a.login).join(", ") || "none";
  return [
    `## #${issue.number}: ${issue.title}`,
    `- **State**: ${issue.state} | **Author**: ${issue.user.login}`,
    `- **Labels**: ${labels} | **Assignees**: ${assignees}`,
    issue.milestone ? `- **Milestone**: ${issue.milestone.title}` : "",
    `- **Created**: ${new Date(issue.created_at).toLocaleString()} | **Updated**: ${new Date(issue.updated_at).toLocaleString()}`,
    `- **URL**: ${issue.html_url}`,
    issue.body ? `\n${issue.body.slice(0, 500)}${issue.body.length > 500 ? "..." : ""}` : "",
  ].filter(Boolean).join("\n");
}

export function registerIssueTools(server: McpServer): void {
  server.registerTool(
    "github_list_issues",
    {
      title: "List GitHub Issues",
      description: `List issues for a repository. Does not include pull requests.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - state ('open' | 'closed' | 'all'): Filter by state (default: 'open')
  - labels (string): Comma-separated label names to filter by
  - assignee (string): Filter by assignee login
  - milestone (string): Milestone number or '*' for any, 'none' for no milestone
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: List of issues with metadata.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        state: z.enum(["open", "closed", "all"]).default("open").describe("Filter by issue state"),
        labels: z.string().optional().describe("Comma-separated label names"),
        assignee: z.string().optional().describe("Filter by assignee login"),
        milestone: z.string().optional().describe("Milestone number, '*' for any, 'none' for no milestone"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, state, labels, assignee, milestone, per_page, page, response_format }) => {
      try {
        const allItems = await githubRequest<GitHubIssue[]>(
          `/repos/${owner}/${repo}/issues`, "GET", undefined,
          { state, labels, assignee, milestone, per_page, page }
        );
        // Filter out pull requests
        const issues = allItems.filter(i => !i.pull_request);

        if (!issues.length) {
          return { content: [{ type: "text", text: `No ${state} issues found in ${owner}/${repo}.` }] };
        }

        const output = {
          count: issues.length, page,
          has_more: allItems.length === per_page,
          ...(allItems.length === per_page ? { next_page: page + 1 } : {}),
          issues: issues.map(i => ({
            number: i.number, title: i.title, state: i.state,
            labels: i.labels.map(l => l.name), assignees: i.assignees.map(a => a.login),
            created_at: i.created_at, updated_at: i.updated_at, html_url: i.html_url,
          })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [`# Issues in ${owner}/${repo} (${state}, page ${page})`, `Showing ${issues.length} issues`, ""];
        for (const i of issues) lines.push(formatIssue(i), "");
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_get_issue",
    {
      title: "Get GitHub Issue",
      description: `Fetch a single issue by number from a repository.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - issue_number (number): Issue number
  - response_format: Output format

Returns: Full issue details including body, labels, assignees, and timeline metadata.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        issue_number: z.number().int().min(1).describe("Issue number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, issue_number, response_format }) => {
      try {
        const issue = await githubRequest<GitHubIssue>(`/repos/${owner}/${repo}/issues/${issue_number}`);
        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(issue, null, 2) }] };
        }
        return { content: [{ type: "text", text: formatIssue(issue) }] };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_create_issue",
    {
      title: "Create GitHub Issue",
      description: `Create a new issue in a repository.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - title (string): Issue title
  - body (string): Issue body (Markdown supported)
  - labels (string[]): Label names to apply
  - assignees (string[]): Logins of users to assign
  - milestone (number): Milestone number to associate

Returns: Created issue details including number and URL.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        title: z.string().min(1).max(256).describe("Issue title"),
        body: z.string().optional().describe("Issue body (Markdown)"),
        labels: z.array(z.string()).optional().describe("Label names to apply"),
        assignees: z.array(z.string()).optional().describe("User logins to assign"),
        milestone: z.number().int().optional().describe("Milestone number"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async ({ owner, repo, title, body, labels, assignees, milestone }) => {
      try {
        const issue = await githubRequest<GitHubIssue>(
          `/repos/${owner}/${repo}/issues`, "POST",
          { title, body, labels, assignees, milestone }
        );
        return {
          content: [{ type: "text", text: `Created issue #${issue.number}: ${issue.title}\n${issue.html_url}` }],
          structuredContent: { number: issue.number, title: issue.title, html_url: issue.html_url },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_update_issue",
    {
      title: "Update GitHub Issue",
      description: `Update an existing issue's title, body, state, labels, or assignees.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - issue_number (number): Issue number to update
  - title (string): New title (optional)
  - body (string): New body (optional)
  - state ('open' | 'closed'): New state (optional)
  - labels (string[]): Replace all labels with these (optional)
  - assignees (string[]): Replace all assignees with these (optional)
  - milestone (number | null): Set or clear milestone (optional)

Returns: Updated issue details.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        issue_number: z.number().int().min(1).describe("Issue number to update"),
        title: z.string().min(1).max(256).optional().describe("New title"),
        body: z.string().optional().describe("New body"),
        state: z.enum(["open", "closed"]).optional().describe("New state"),
        labels: z.array(z.string()).optional().describe("Replace labels with these"),
        assignees: z.array(z.string()).optional().describe("Replace assignees with these"),
        milestone: z.number().int().nullable().optional().describe("Set or clear milestone"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, issue_number, ...updates }) => {
      try {
        const issue = await githubRequest<GitHubIssue>(
          `/repos/${owner}/${repo}/issues/${issue_number}`, "PATCH",
          Object.fromEntries(Object.entries(updates).filter(([, v]) => v !== undefined))
        );
        return {
          content: [{ type: "text", text: `Updated issue #${issue.number}: ${issue.title}\nState: ${issue.state}\n${issue.html_url}` }],
          structuredContent: { number: issue.number, title: issue.title, state: issue.state, html_url: issue.html_url },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_add_issue_comment",
    {
      title: "Add GitHub Issue Comment",
      description: `Add a comment to an issue or pull request.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - issue_number (number): Issue or PR number
  - body (string): Comment body (Markdown supported)

Returns: Created comment ID and URL.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        issue_number: z.number().int().min(1).describe("Issue or PR number"),
        body: z.string().min(1).describe("Comment body (Markdown)"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async ({ owner, repo, issue_number, body }) => {
      try {
        const comment = await githubRequest<{ id: number; html_url: string }>(
          `/repos/${owner}/${repo}/issues/${issue_number}/comments`, "POST", { body }
        );
        return {
          content: [{ type: "text", text: `Comment added (ID: ${comment.id})\n${comment.html_url}` }],
          structuredContent: { id: comment.id, html_url: comment.html_url },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );
}
