import axios, { AxiosError, type AxiosRequestConfig } from "axios";
import { GITHUB_API_BASE } from "./constants.js";

let githubToken: string | undefined;

export function initClient(token: string): void {
  githubToken = token;
}

export async function githubRequest<T>(
  path: string,
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE" = "GET",
  data?: unknown,
  params?: Record<string, unknown>
): Promise<T> {
  const config: AxiosRequestConfig = {
    method,
    url: `${GITHUB_API_BASE}${path}`,
    headers: {
      Authorization: `Bearer ${githubToken}`,
      Accept: "application/vnd.github.v3+json",
      "Content-Type": "application/json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    timeout: 30000,
    ...(data ? { data } : {}),
    ...(params ? { params } : {}),
  };

  const response = await axios(config);
  return response.data as T;
}

export function handleGitHubError(error: unknown): string {
  if (error instanceof AxiosError) {
    if (error.response) {
      const status = error.response.status;
      const message = (error.response.data as { message?: string })?.message ?? "";
      switch (status) {
        case 401:
          return "Error: Authentication failed. Check your GITHUB_TOKEN.";
        case 403:
          return `Error: Permission denied. ${message || "You don't have access to this resource."}`;
        case 404:
          return "Error: Resource not found. Check the owner, repo, or resource ID.";
        case 409:
          return `Error: Conflict. ${message || "The resource already exists or is in a conflicting state."}`;
        case 422:
          return `Error: Validation failed. ${message}`;
        case 429:
          return "Error: Rate limit exceeded. Please wait before making more requests.";
        default:
          return `Error: GitHub API returned status ${status}. ${message}`;
      }
    } else if (error.code === "ECONNABORTED") {
      return "Error: Request timed out. Please try again.";
    }
  }
  return `Error: ${error instanceof Error ? error.message : String(error)}`;
}

export function truncateIfNeeded(text: string, limit: number): string {
  if (text.length <= limit) return text;
  return text.slice(0, limit) + `\n\n[Response truncated at ${limit} characters. Use pagination or filters to narrow results.]`;
}
