import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { githubRequest, handleGitHubError } from "../github-client.js";
import { ResponseFormat, type GitHubUser } from "../types.js";

export function registerUserTools(server: McpServer): void {
  server.registerTool(
    "github_get_user",
    {
      title: "Get GitHub User",
      description: `Fetch public profile information for a GitHub user or organization.
Omit the login parameter to get the authenticated user's own profile.

Args:
  - login (string): GitHub username or org login (optional — omit for authenticated user)
  - response_format: Output format

Returns: User profile including name, bio, company, location, public repo count, followers.`,
      inputSchema: z.object({
        login: z.string().optional().describe("GitHub username (omit for authenticated user)"),
        response_format: z.nativeEnum(ResponseFormat).default(ResponseFormat.MARKDOWN).describe("Output format"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ login, response_format }) => {
      try {
        const path = login ? `/users/${login}` : "/user";
        const user = await githubRequest<GitHubUser>(path);

        if (response_format === ResponseFormat.JSON) {
          return { content: [{ type: "text", text: JSON.stringify(user, null, 2) }] };
        }

        const lines = [
          `## ${user.name ?? user.login} (@${user.login})`,
          user.bio ? `> ${user.bio}` : "",
          user.company ? `- **Company**: ${user.company}` : "",
          user.location ? `- **Location**: ${user.location}` : "",
          user.blog ? `- **Blog**: ${user.blog}` : "",
          user.email ? `- **Email**: ${user.email}` : "",
          `- **Public Repos**: ${user.public_repos} | **Followers**: ${user.followers} | **Following**: ${user.following}`,
          `- **GitHub**: ${user.html_url}`,
          `- **Joined**: ${new Date(user.created_at).toLocaleDateString()}`,
        ].filter(Boolean);

        return {
          content: [{ type: "text", text: lines.join("\n") }],
          structuredContent: {
            login: user.login, name: user.name, bio: user.bio, company: user.company,
            location: user.location, public_repos: user.public_repos,
            followers: user.followers, html_url: user.html_url,
          },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );
}
