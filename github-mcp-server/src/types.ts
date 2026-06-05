export enum ResponseFormat {
  MARKDOWN = "markdown",
  JSON = "json",
}

export interface GitHubRepo {
  id: number;
  full_name: string;
  name: string;
  owner: { login: string };
  description: string | null;
  private: boolean;
  html_url: string;
  default_branch: string;
  stargazers_count: number;
  forks_count: number;
  open_issues_count: number;
  language: string | null;
  updated_at: string;
  pushed_at: string;
}

export interface GitHubIssue {
  number: number;
  title: string;
  body: string | null;
  state: string;
  html_url: string;
  user: { login: string };
  labels: Array<{ name: string }>;
  assignees: Array<{ login: string }>;
  milestone: { title: string } | null;
  created_at: string;
  updated_at: string;
  pull_request?: object;
}

export interface GitHubPR {
  number: number;
  title: string;
  body: string | null;
  state: string;
  html_url: string;
  user: { login: string };
  head: { ref: string; sha: string };
  base: { ref: string };
  draft: boolean;
  merged: boolean;
  mergeable: boolean | null;
  created_at: string;
  updated_at: string;
}

export interface GitHubBranch {
  name: string;
  commit: { sha: string; url: string };
  protected: boolean;
}

export interface GitHubCommit {
  sha: string;
  commit: {
    message: string;
    author: { name: string; date: string };
  };
  author: { login: string } | null;
  html_url: string;
}

export interface GitHubFileContent {
  name: string;
  path: string;
  sha: string;
  size: number;
  type: string;
  content?: string;
  encoding?: string;
  html_url: string;
  download_url: string | null;
}

export interface GitHubUser {
  login: string;
  id: number;
  name: string | null;
  email: string | null;
  bio: string | null;
  company: string | null;
  location: string | null;
  blog: string | null;
  public_repos: number;
  followers: number;
  following: number;
  html_url: string;
  created_at: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  count: number;
  has_more: boolean;
  next_page?: number;
}
