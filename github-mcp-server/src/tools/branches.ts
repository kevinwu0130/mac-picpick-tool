import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { githubRequest, handleGitHubError, truncateIfNeeded } from "../github-client.js";
import { ResponseFormat, type GitHubBranch, type GitHubCommit } from "../types.js";
import { CHARACTER_LIMIT, DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from "../constants.js";

export function registerBranchTools(server: McpServer): void {
  server.registerTool(
    "github_list_branches",
    {
      title: "List GitHub Branches",
      description: `List branches in a repository.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - protected (boolean): Filter to only protected branches (optional)
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: List of branches with latest commit SHA and protection status.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        protected: z.boolean().optional().describe("Filter to only protected branches"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, protected: protectedOnly, per_page, page, response_format }) => {
      try {
        const branches = await githubRequest<GitHubBranch[]>(
          `/repos/${owner}/${repo}/branches`, "GET", undefined,
          { protected: protectedOnly, per_page, page }
        );

        if (!branches.length) {
          return { content: [{ type: "text", text: `No branches found in ${owner}/${repo}.` }] };
        }

        const output = {
          count: branches.length, page,
          has_more: branches.length === per_page,
          ...(branches.length === per_page ? { next_page: page + 1 } : {}),
          branches: branches.map(b => ({ name: b.name, sha: b.commit.sha, protected: b.protected })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [`# Branches in ${owner}/${repo} (page ${page})`, `Showing ${branches.length} branches`, ""];
        for (const b of branches) {
          lines.push(`- **${b.name}**${b.protected ? " 🔒" : ""} — \`${b.commit.sha.slice(0, 7)}\``);
        }
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_list_commits",
    {
      title: "List GitHub Commits",
      description: `List commits in a repository, optionally filtered by branch, path, or author.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - sha (string): Branch name or commit SHA to start from (default: repo default branch)
  - path (string): Only commits touching this file path
  - author (string): Filter by author login or email
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: List of commits with SHA, message, author, and date.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        sha: z.string().optional().describe("Branch name or commit SHA"),
        path: z.string().optional().describe("Only commits touching this file path"),
        author: z.string().optional().describe("Filter by author login or email"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, sha, path, author, per_page, page, response_format }) => {
      try {
        const commits = await githubRequest<GitHubCommit[]>(
          `/repos/${owner}/${repo}/commits`, "GET", undefined,
          { sha, path, author, per_page, page }
        );

        if (!commits.length) {
          return { content: [{ type: "text", text: `No commits found in ${owner}/${repo}.` }] };
        }

        const output = {
          count: commits.length, page,
          has_more: commits.length === per_page,
          ...(commits.length === per_page ? { next_page: page + 1 } : {}),
          commits: commits.map(c => ({
            sha: c.sha.slice(0, 7), full_sha: c.sha,
            message: c.commit.message.split("\n")[0],
            author: c.author?.login ?? c.commit.author.name,
            date: c.commit.author.date,
            html_url: c.html_url,
          })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [`# Commits in ${owner}/${repo} (page ${page})`, `Showing ${commits.length} commits`, ""];
        for (const c of commits) {
          const msg = c.commit.message.split("\n")[0];
          const author = c.author?.login ?? c.commit.author.name;
          const date = new Date(c.commit.author.date).toLocaleString();
          lines.push(`- \`${c.sha.slice(0, 7)}\` **${msg}** — ${author} @ ${date}`);
        }
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_get_commit",
    {
      title: "Get GitHub Commit",
      description: `Fetch details of a single commit including changed files and stats.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - ref (string): Commit SHA, branch name, or tag

Returns: Commit details including author, message, stats, and list of changed files.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        ref: z.string().min(1).describe("Commit SHA, branch name, or tag"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, ref, response_format }) => {
      try {
        const commit = await githubRequest<{
          sha: string;
          commit: { message: string; author: { name: string; date: string } };
          author: { login: string } | null;
          stats: { additions: number; deletions: number; total: number };
          files: Array<{ filename: string; status: string; additions: number; deletions: number }>;
          html_url: string;
        }>(`/repos/${owner}/${repo}/commits/${ref}`);

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(commit, null, 2) }] };
        }

        const author = commit.author?.login ?? commit.commit.author.name;
        const lines = [
          `## Commit \`${commit.sha.slice(0, 7)}\``,
          `**Message**: ${commit.commit.message}`,
          `**Author**: ${author} @ ${new Date(commit.commit.author.date).toLocaleString()}`,
          `**Stats**: +${commit.stats.additions} -${commit.stats.deletions} (${commit.stats.total} changes)`,
          `**URL**: ${commit.html_url}`,
          "",
          "### Changed Files",
          ...commit.files.slice(0, 50).map(f => `- \`${f.status}\` ${f.filename} (+${f.additions}/-${f.deletions})`),
          ...(commit.files.length > 50 ? [`... and ${commit.files.length - 50} more files`] : []),
        ];
        return { content: [{ type: "text", text: lines.join("\n") }] };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );
}
