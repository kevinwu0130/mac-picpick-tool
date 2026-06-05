import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { githubRequest, handleGitHubError, truncateIfNeeded } from "../github-client.js";
import { ResponseFormat, type GitHubIssue } from "../types.js";
import { CHARACTER_LIMIT, DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from "../constants.js";

export function registerSearchTools(server: McpServer): void {
  server.registerTool(
    "github_search_code",
    {
      title: "Search GitHub Code",
      description: `Search for code across GitHub repositories using GitHub's code search syntax.

Args:
  - query (string): Search query. Supports qualifiers like 'repo:owner/name', 'language:typescript', 'path:src/', 'extension:ts'
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: Matching code files with repository info, file path, and URL.
Note: Code search requires authentication and only searches the default branch.`,
      inputSchema: z.object({
        query: z.string().min(1).describe("Code search query with optional qualifiers"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ query, per_page, page, response_format }) => {
      try {
        const data = await githubRequest<{
          total_count: number;
          items: Array<{ name: string; path: string; html_url: string; repository: { full_name: string }; sha: string }>;
        }>("/search/code", "GET", undefined, { q: query, per_page, page });

        const output = {
          total_count: data.total_count, count: data.items.length, page,
          has_more: page * per_page < data.total_count,
          ...(page * per_page < data.total_count ? { next_page: page + 1 } : {}),
          results: data.items.map(i => ({ repo: i.repository.full_name, path: i.path, html_url: i.html_url })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [
          `# Code Search: "${query}"`,
          `Total: ${data.total_count} (showing ${data.items.length}, page ${page})`, "",
          ...data.items.map(i => `- [${i.repository.full_name}] \`${i.path}\` — ${i.html_url}`),
        ];
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_search_issues",
    {
      title: "Search GitHub Issues and PRs",
      description: `Search issues and pull requests across GitHub using GitHub's search syntax.

Args:
  - query (string): Search query. Supports qualifiers like 'repo:owner/name', 'is:issue', 'is:pr', 'is:open', 'label:bug', 'author:login'
  - sort ('comments' | 'reactions' | 'reactions-+1' | 'created' | 'updated'): Sort field (default: best match)
  - order ('asc' | 'desc'): Sort order (default: 'desc')
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: Matching issues/PRs with number, title, state, and URL.`,
      inputSchema: z.object({
        query: z.string().min(1).describe("Issue/PR search query with optional qualifiers"),
        sort: z.enum(["comments", "reactions", "reactions-+1", "created", "updated"]).optional().describe("Sort field"),
        order: z.enum(["asc", "desc"]).default("desc").describe("Sort order"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ query, sort, order, per_page, page, response_format }) => {
      try {
        const data = await githubRequest<{ total_count: number; items: GitHubIssue[] }>(
          "/search/issues", "GET", undefined, { q: query, sort, order, per_page, page }
        );

        const output = {
          total_count: data.total_count, count: data.items.length, page,
          has_more: page * per_page < data.total_count,
          ...(page * per_page < data.total_count ? { next_page: page + 1 } : {}),
          results: data.items.map(i => ({
            number: i.number, title: i.title, state: i.state,
            type: i.pull_request ? "pr" : "issue",
            labels: i.labels.map(l => l.name),
            html_url: i.html_url,
          })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [
          `# Issue/PR Search: "${query}"`,
          `Total: ${data.total_count} (showing ${data.items.length}, page ${page})`, "",
        ];
        for (const i of data.items) {
          const type = i.pull_request ? "PR" : "Issue";
          lines.push(`- [${type} #${i.number}] **${i.title}** (${i.state}) — ${i.html_url}`);
        }
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );
}
