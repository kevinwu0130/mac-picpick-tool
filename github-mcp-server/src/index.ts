#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import { initClient } from "./github-client.js";
import { registerRepoTools } from "./tools/repos.js";
import { registerIssueTools } from "./tools/issues.js";
import { registerPRTools } from "./tools/pull-requests.js";
import { registerBranchTools } from "./tools/branches.js";
import { registerContentsTools } from "./tools/contents.js";
import { registerSearchTools } from "./tools/search.js";
import { registerUserTools } from "./tools/users.js";

const token = process.env.GITHUB_TOKEN;
if (!token) {
  console.error("ERROR: GITHUB_TOKEN environment variable is required");
  process.exit(1);
}

initClient(token);

function createServer(): McpServer {
  const server = new McpServer({
    name: "github-mcp-server",
    version: "1.0.0",
  });
  registerRepoTools(server);
  registerIssueTools(server);
  registerPRTools(server);
  registerBranchTools(server);
  registerContentsTools(server);
  registerSearchTools(server);
  registerUserTools(server);
  return server;
}

async function runStdio(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("GitHub MCP server running via stdio");
}

async function runHttp(): Promise<void> {
  const app = express();
  app.use(express.json());

  app.post("/mcp", async (req, res) => {
    const server = createServer();
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });
    res.on("close", () => transport.close());
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  });

  // Health check
  app.get("/health", (_req, res) => {
    res.json({ status: "ok", server: "github-mcp-server" });
  });

  const port = parseInt(process.env.PORT ?? "3000");
  app.listen(port, "0.0.0.0", () => {
    console.error(`GitHub MCP server running on http://0.0.0.0:${port}/mcp`);
  });
}

const transport = process.env.TRANSPORT ?? "stdio";
const runner = transport === "http" ? runHttp() : runStdio();

runner.catch((error: unknown) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
