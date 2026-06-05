import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { githubRequest, handleGitHubError, truncateIfNeeded } from "../github-client.js";
import { ResponseFormat, type GitHubRepo } from "../types.js";
import { CHARACTER_LIMIT, DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from "../constants.js";

function formatRepo(r: GitHubRepo): string {
  return [
    `## ${r.full_name}`,
    r.description ? `> ${r.description}` : "",
    `- **URL**: ${r.html_url}`,
    `- **Language**: ${r.language ?? "N/A"} | **Stars**: ${r.stargazers_count} | **Forks**: ${r.forks_count} | **Open Issues**: ${r.open_issues_count}`,
    `- **Default Branch**: ${r.default_branch} | **Private**: ${r.private}`,
    `- **Last Push**: ${new Date(r.pushed_at).toLocaleString()}`,
  ].filter(Boolean).join("\n");
}

export function registerRepoTools(server: McpServer): void {
  server.registerTool(
    "github_get_repo",
    {
      title: "Get GitHub Repository",
      description: `Fetch details of a single GitHub repository.

Args:
  - owner (string): Repository owner (user or org login)
  - repo (string): Repository name

Returns: Repository metadata including description, stars, forks, language, default branch, visibility.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, response_format }) => {
      try {
        const data = await githubRequest<GitHubRepo>(`/repos/${owner}/${repo}`);
        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
        }
        return { content: [{ type: "text", text: formatRepo(data) }] };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_list_repos",
    {
      title: "List GitHub Repositories",
      description: `List repositories for a user or organization.

Args:
  - owner (string): User or org login
  - type ('all' | 'owner' | 'member' | 'public' | 'private'): Filter by repo type (default: 'owner')
  - sort ('created' | 'updated' | 'pushed' | 'full_name'): Sort field (default: 'updated')
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: List of repositories with pagination metadata.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("User or org login"),
        type: z.enum(["all", "owner", "member", "public", "private"]).default("owner").describe("Filter by repo type"),
        sort: z.enum(["created", "updated", "pushed", "full_name"]).default("updated").describe("Sort field"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, type, sort, per_page, page, response_format }) => {
      try {
        // Try org endpoint first, fall back to user endpoint
        let repos: GitHubRepo[];
        try {
          repos = await githubRequest<GitHubRepo[]>(`/orgs/${owner}/repos`, "GET", undefined, { type, sort, per_page, page });
        } catch {
          repos = await githubRequest<GitHubRepo[]>(`/users/${owner}/repos`, "GET", undefined, { type, sort, per_page });
        }

        const output = {
          count: repos.length,
          page,
          has_more: repos.length === per_page,
          ...(repos.length === per_page ? { next_page: page + 1 } : {}),
          repos: repos.map(r => ({
            full_name: r.full_name, description: r.description, private: r.private,
            language: r.language, stars: r.stargazers_count, forks: r.forks_count,
            open_issues: r.open_issues_count, default_branch: r.default_branch,
            pushed_at: r.pushed_at, html_url: r.html_url,
          })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [`# Repositories for ${owner} (page ${page})`, `Found ${repos.length} repos`, ""];
        for (const r of repos) lines.push(formatRepo(r), "");
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_search_repos",
    {
      title: "Search GitHub Repositories",
      description: `Search GitHub repositories using GitHub's search syntax.

Args:
  - query (string): Search query, supports GitHub qualifiers e.g. "language:typescript stars:>100"
  - sort ('stars' | 'forks' | 'help-wanted-issues' | 'updated'): Sort field (default: best match)
  - order ('asc' | 'desc'): Sort order (default: 'desc')
  - per_page (number): Results per page, 1-100 (default: 30)
  - page (number): Page number (default: 1)
  - response_format: Output format

Returns: Matching repositories with total count and pagination metadata.`,
      inputSchema: z.object({
        query: z.string().min(1).describe("Search query with optional GitHub qualifiers"),
        sort: z.enum(["stars", "forks", "help-wanted-issues", "updated"]).optional().describe("Sort field"),
        order: z.enum(["asc", "desc"]).default("desc").describe("Sort order"),
        per_page: z.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE).describe("Results per page"),
        page: z.number().int().min(1).default(1).describe("Page number"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ query, sort, order, per_page, page, response_format }) => {
      try {
        const data = await githubRequest<{ total_count: number; items: GitHubRepo[] }>(
          "/search/repositories", "GET", undefined,
          { q: query, sort, order, per_page, page }
        );

        const output = {
          total_count: data.total_count, count: data.items.length, page,
          has_more: page * per_page < data.total_count,
          ...(page * per_page < data.total_count ? { next_page: page + 1 } : {}),
          repos: data.items.map(r => ({
            full_name: r.full_name, description: r.description, language: r.language,
            stars: r.stargazers_count, forks: r.forks_count, html_url: r.html_url,
          })),
        };

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
        }

        const lines = [`# Search Results: "${query}"`, `Total: ${data.total_count} (showing ${data.items.length}, page ${page})`, ""];
        for (const r of data.items) lines.push(formatRepo(r), "");
        const text = truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT);
        return { content: [{ type: "text", text }], structuredContent: output };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );
}
