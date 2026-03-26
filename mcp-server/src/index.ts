import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { execSync } from "child_process";
import { randomUUID } from "crypto";

// ---------------------------------------------------------------------------
// Types — mirror the Swift TodoItem model
// ---------------------------------------------------------------------------

interface TodoItem {
  id: string;
  title: string;
  createdAt: string;   // ISO 8601
  completedAt: string | null;
  isCompleted: boolean;
}

// ---------------------------------------------------------------------------
// Persistence helpers
// ---------------------------------------------------------------------------

const TODO_DIR = path.join(
  os.homedir(),
  "Library",
  "Application Support",
  "ArtisanalTodo"
);
const TODO_PATH = path.join(TODO_DIR, "todos.json");

function readTodos(): TodoItem[] {
  try {
    const data = fs.readFileSync(TODO_PATH, "utf-8");
    return JSON.parse(data) as TodoItem[];
  } catch {
    return [];
  }
}

function writeTodos(todos: TodoItem[]): void {
  if (!fs.existsSync(TODO_DIR)) {
    fs.mkdirSync(TODO_DIR, { recursive: true });
  }
  fs.writeFileSync(TODO_PATH, JSON.stringify(todos, null, 2), "utf-8");
  // Tell the app + widget to refresh. The app registers artisanaltodo://refresh
  // as a URL scheme handler; if it's not running the open call silently fails.
  try {
    execSync("open artisanaltodo://refresh", { stdio: "ignore" });
  } catch {
    // App is not running — that's fine, the file watcher will catch it on next launch
  }
}

// ---------------------------------------------------------------------------
// MCP server
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "artisanal-todo",
  version: "1.0.0",
});

// --- add_todo ---------------------------------------------------------------

server.tool(
  "add_todo",
  "Add a new pending item to the Artisanal Todo app",
  { title: z.string().min(1).describe("The task to add") },
  async ({ title }) => {
    const todos = readTodos();
    const item: TodoItem = {
      id: randomUUID(),
      title: title.trim(),
      createdAt: new Date().toISOString(),
      completedAt: null,
      isCompleted: false,
    };
    todos.push(item);
    writeTodos(todos);
    return {
      content: [
        { type: "text", text: `Added: "${item.title}" (id: ${item.id})` },
      ],
    };
  }
);

// --- list_todos -------------------------------------------------------------

server.tool(
  "list_todos",
  "Return all todo items — both pending and completed",
  {},
  async () => {
    const todos = readTodos();
    if (todos.length === 0) {
      return { content: [{ type: "text", text: "No todos found." }] };
    }

    const pending = todos.filter((t) => !t.isCompleted);
    const completed = todos.filter((t) => t.isCompleted);
    const lines: string[] = [];

    if (pending.length > 0) {
      lines.push("**Pending:**");
      for (const t of pending) {
        lines.push(`- [ ] ${t.title}  (id: ${t.id})`);
      }
    }
    if (completed.length > 0) {
      if (lines.length > 0) lines.push("");
      lines.push("**Completed:**");
      for (const t of completed) {
        lines.push(`- [x] ${t.title}  (id: ${t.id})`);
      }
    }

    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

// --- complete_todo ----------------------------------------------------------

server.tool(
  "complete_todo",
  "Mark a todo item as completed",
  { id: z.string().uuid().describe("UUID of the todo to complete") },
  async ({ id }) => {
    const todos = readTodos();
    const idx = todos.findIndex((t) => t.id === id);
    if (idx === -1) {
      return {
        content: [{ type: "text", text: `No todo found with id: ${id}` }],
        isError: true,
      };
    }
    if (todos[idx].isCompleted) {
      return {
        content: [
          { type: "text", text: `"${todos[idx].title}" is already completed.` },
        ],
      };
    }
    todos[idx].isCompleted = true;
    todos[idx].completedAt = new Date().toISOString();
    writeTodos(todos);
    return {
      content: [{ type: "text", text: `Completed: "${todos[idx].title}"` }],
    };
  }
);

// --- delete_todo ------------------------------------------------------------

server.tool(
  "delete_todo",
  "Permanently delete a todo item",
  { id: z.string().uuid().describe("UUID of the todo to delete") },
  async ({ id }) => {
    const todos = readTodos();
    const idx = todos.findIndex((t) => t.id === id);
    if (idx === -1) {
      return {
        content: [{ type: "text", text: `No todo found with id: ${id}` }],
        isError: true,
      };
    }
    const [removed] = todos.splice(idx, 1);
    writeTodos(todos);
    return {
      content: [{ type: "text", text: `Deleted: "${removed.title}"` }],
    };
  }
);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

const transport = new StdioServerTransport();
await server.connect(transport);
