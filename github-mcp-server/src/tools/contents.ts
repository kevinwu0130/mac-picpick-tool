import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { githubRequest, handleGitHubError } from "../github-client.js";
import { type GitHubFileContent } from "../types.js";

export function registerContentsTools(server: McpServer): void {
  server.registerTool(
    "github_get_file",
    {
      title: "Get GitHub File Contents",
      description: `Read the contents of a file from a repository.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - path (string): File path within the repository (e.g. 'src/index.ts')
  - ref (string): Branch, tag, or commit SHA (default: repo default branch)

Returns: Decoded file content as a string, plus metadata (size, SHA, URL).
Note: Only works for files up to 1 MB. For larger files, use the download_url.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        path: z.string().min(1).describe("File path within the repository"),
        ref: z.string().optional().describe("Branch, tag, or commit SHA"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, path, ref }) => {
      try {
        const file = await githubRequest<GitHubFileContent>(
          `/repos/${owner}/${repo}/contents/${path}`,
          "GET", undefined,
          ref ? { ref } : undefined
        );

        if (file.type !== "file") {
          return { content: [{ type: "text", text: `Error: '${path}' is a ${file.type}, not a file. Use github_list_directory to browse directories.` }] };
        }

        if (!file.content || !file.encoding) {
          return { content: [{ type: "text", text: `File is too large to read inline. Download from: ${file.download_url}` }] };
        }

        const decoded = Buffer.from(file.content.replace(/\n/g, ""), "base64").toString("utf-8");
        const header = `# ${file.path} (${file.size} bytes, SHA: ${file.sha.slice(0, 7)})\n\n`;
        return {
          content: [{ type: "text", text: header + decoded }],
          structuredContent: { path: file.path, size: file.size, sha: file.sha, html_url: file.html_url, content: decoded },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );

  server.registerTool(
    "github_create_or_update_file",
    {
      title: "Create or Update GitHub File",
      description: `Create a new file or update an existing file in a repository.

Args:
  - owner (string): Repository owner login
  - repo (string): Repository name
  - path (string): File path within the repository (e.g. 'docs/guide.md')
  - message (string): Commit message
  - content (string): New file content (plain text, will be base64 encoded)
  - sha (string): Current file SHA — required when updating an existing file, omit when creating
  - branch (string): Branch to commit to (default: repo default branch)

Returns: Commit SHA and file URL.`,
      inputSchema: z.object({
        owner: z.string().min(1).describe("Repository owner login"),
        repo: z.string().min(1).describe("Repository name"),
        path: z.string().min(1).describe("File path within the repository"),
        message: z.string().min(1).describe("Commit message"),
        content: z.string().describe("File content (plain text)"),
        sha: z.string().optional().describe("Current file SHA — required when updating, omit when creating"),
        branch: z.string().optional().describe("Target branch (default: repo default branch)"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async ({ owner, repo, path, message, content, sha, branch }) => {
      try {
        const encodedContent = Buffer.from(content, "utf-8").toString("base64");
        const result = await githubRequest<{ content: { html_url: string; sha: string }; commit: { sha: string } }>(
          `/repos/${owner}/${repo}/contents/${path}`, "PUT",
          { message, content: encodedContent, sha, branch }
        );
        const action = sha ? "Updated" : "Created";
        return {
          content: [{ type: "text", text: `${action} ${path}\nCommit: ${result.commit.sha.slice(0, 7)}\n${result.content.html_url}` }],
          structuredContent: { commit_sha: result.commit.sha, file_sha: result.content.sha, html_url: result.content.html_url },
        };
      } catch (error) {
        return { content: [{ type: "text", text: handleGitHubError(error) }] };
      }
    }
  );
}
