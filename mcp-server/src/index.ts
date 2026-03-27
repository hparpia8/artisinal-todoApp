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
// Lookup helpers — resolve a todo by number, title substring, or UUID
// ---------------------------------------------------------------------------

function findTodo(
  todos: TodoItem[],
  query: { id?: string; title?: string; number?: number }
): { item: TodoItem; index: number } | { error: string } {
  if (query.number !== undefined) {
    const idx = query.number - 1; // 1-based → 0-based
    if (idx < 0 || idx >= todos.length) {
      return { error: `No todo at #${query.number}. Use list_todos to see current numbers.` };
    }
    return { item: todos[idx], index: idx };
  }

  if (query.id) {
    const idx = todos.findIndex((t) => t.id === query.id);
    if (idx === -1) return { error: `No todo found with that id.` };
    return { item: todos[idx], index: idx };
  }

  if (query.title) {
    const lower = query.title.toLowerCase();
    const matches = todos
      .map((t, i) => ({ item: t, index: i }))
      .filter((e) => e.item.title.toLowerCase().includes(lower));

    if (matches.length === 0) return { error: `No todo matching "${query.title}".` };
    if (matches.length === 1) return matches[0];

    const list = matches
      .map((m) => `  ${m.index + 1}. ${m.item.title}`)
      .join("\n");
    return { error: `Multiple matches for "${query.title}":\n${list}\nPlease specify by number or a more specific title.` };
  }

  return { error: "Provide a number, title, or id to identify the todo." };
}

const todoQuerySchema = {
  number: z.number().int().positive().optional()
    .describe("Position number from list_todos (e.g. 1, 2, 3)"),
  title: z.string().optional()
    .describe("Case-insensitive substring to match against todo titles"),
  id: z.string().uuid().optional()
    .describe("UUID — used internally, never shown to the user"),
};

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
        { type: "text", text: `Added: "${item.title}"` },
      ],
    };
  }
);

// --- list_todos -------------------------------------------------------------

server.tool(
  "list_todos",
  "Return all todo items — both pending and completed. Items are numbered so the user can refer to them by number.",
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
        const num = todos.indexOf(t) + 1;
        lines.push(`${num}. - [ ] ${t.title}`);
      }
    }
    if (completed.length > 0) {
      if (lines.length > 0) lines.push("");
      lines.push("**Completed:**");
      for (const t of completed) {
        const num = todos.indexOf(t) + 1;
        lines.push(`${num}. - [x] ${t.title}`);
      }
    }

    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

// --- complete_todo ----------------------------------------------------------

server.tool(
  "complete_todo",
  "Mark a todo item as completed. Identify the item by its list number, a title substring, or UUID.",
  todoQuerySchema,
  async (query) => {
    const todos = readTodos();
    const result = findTodo(todos, query);
    if ("error" in result) {
      return { content: [{ type: "text", text: result.error }], isError: true };
    }
    const { item, index } = result;
    if (item.isCompleted) {
      return {
        content: [{ type: "text", text: `"${item.title}" is already completed.` }],
      };
    }
    todos[index].isCompleted = true;
    todos[index].completedAt = new Date().toISOString();
    writeTodos(todos);
    return {
      content: [{ type: "text", text: `Completed: "${item.title}"` }],
    };
  }
);

// --- delete_todo ------------------------------------------------------------

server.tool(
  "delete_todo",
  "Permanently delete a todo item. Identify the item by its list number, a title substring, or UUID.",
  todoQuerySchema,
  async (query) => {
    const todos = readTodos();
    const result = findTodo(todos, query);
    if ("error" in result) {
      return { content: [{ type: "text", text: result.error }], isError: true };
    }
    const [removed] = todos.splice(result.index, 1);
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
