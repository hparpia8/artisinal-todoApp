# Artisanal Todo

A simple, local-only macOS todo app with a warm pen-and-paper feel.

- One continuous scrollable page — active tasks at the bottom, history above
- Fully offline — data never leaves your machine
- macOS desktop widget (3, 5, or 10 tasks at a glance)
- Light, Dark, and Auto (follows system) appearance modes

**Requires macOS 14 (Sonoma) or later.**

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hparpia8/todoApp/main/install.sh | bash
```

Downloads the latest release from GitHub Releases and copies it to `/Applications`. You'll be prompted to launch the app when done.

> **Note:** The curl installer requires a published GitHub Release with a `TodoApp.dmg` attached. See [Publishing a release](#publishing-a-release) below.

---

## How to use

| Action | Result |
|--------|--------|
| Type in the bottom bar + press **Return** | Adds a task |
| Click the circle next to a task | Marks it complete — moves to history |
| Click a completed circle | Restores the task to active |
| Scroll up | Browse all completed history |
| Right-click a task | Delete it |
| ☀ · ◑ · ☾ buttons in the header | Switch Light / Auto / Dark mode |

### Adding the widget

1. Right-click your macOS desktop → **Edit Widgets**
2. Search for **Artisanal Todo**
3. Choose Small (3 tasks), Medium (5), or Large (10)

> The widget requires the app to be installed and launched at least once. For live data, the app must be signed with an Apple Developer account (see [Widget & signing](#widget--signing)).

---

## Build & test locally

**Prerequisites:** Xcode 15+, Homebrew

### Quick start

```bash
git clone https://github.com/hparpia8/todoApp.git
cd todoApp
./setup.sh
```

`setup.sh` installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) via Homebrew and generates `TodoApp.xcodeproj`.

Then open in Xcode:

```bash
open TodoApp.xcodeproj
```

**Important:** In Xcode's toolbar, make sure the scheme is set to **TodoApp** (not `TodoWidgetExtension`) before pressing ⌘R.

```
[TodoApp] > [My Mac]   ▶
```

### Using make

```bash
make setup    # install XcodeGen + generate project
make open     # open in Xcode
make build    # build from the terminal
make archive  # build a release archive
make clean    # remove generated project + build output
```

### Running from the terminal (after building)

```bash
make build
# the app binary lands in Xcode's DerivedData — open it from Xcode with ⌘R
```

---

## Data storage

| Build type | Storage location |
|------------|-----------------|
| Signed (Apple Developer account) | `~/Library/Group Containers/group.com.artisanal.todo/todos.json` |
| Unsigned / development | `~/Library/Application Support/ArtisanalTodo/todos.json` |

To inspect your data at any time:

```bash
cat ~/Library/Application\ Support/ArtisanalTodo/todos.json
```

---

## Widget & signing

The WidgetKit extension is always sandboxed by macOS. For the widget to read live data from the app, both targets must share an **App Group** (`group.com.artisanal.todo`), which requires a valid Apple Developer account.

**To enable for App Store / signed distribution:**

1. Add your Team ID in Xcode → Signing & Capabilities
2. Create the App Group `group.com.artisanal.todo` in your [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list/applicationGroup)
3. In both entitlements files, uncomment the App Groups section:
   ```xml
   <key>com.apple.security.application-groups</key>
   <array><string>group.com.artisanal.todo</string></array>
   ```
4. Enable sandbox in `TodoApp.entitlements` (`com.apple.security.app-sandbox = true`)

For unsigned/development builds the widget shows placeholder data — the main app works fully.

---

## Publishing a release

To make the curl installer work:

1. Archive the app: `make archive` (or Xcode → Product → Archive)
2. Export `TodoApp.app` from the archive
3. Wrap it in a DMG named `TodoApp.dmg`
4. Create a GitHub Release and attach `TodoApp.dmg`

The install script automatically fetches the latest release.

---

## MCP server — use with AI agents

The MCP server lets any AI agent (Claude, Cursor, etc.) read and manage your todos directly. It communicates over stdio and works with any MCP-compatible client.

### Build the server

```bash
cd mcp-server
npm install
npm run build
```

This compiles TypeScript to `mcp-server/dist/index.js`.

### Connect to Claude Desktop

Add the following to your Claude Desktop config file at `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "artisanal-todo": {
      "command": "node",
      "args": ["/absolute/path/to/todoApp/mcp-server/dist/index.js"]
    }
  }
}
```

Replace `/absolute/path/to/todoApp` with the actual path on your machine (e.g. `~/Documents/Projects/todoApp` expanded to a full path). Restart Claude Desktop after saving.

### Connect to Claude Code (CLI)

Add the server to your project's `.mcp.json` file in the repo root:

```json
{
  "mcpServers": {
    "artisanal-todo": {
      "command": "node",
      "args": ["./mcp-server/dist/index.js"]
    }
  }
}
```

Or register it globally for all projects:

```bash
claude mcp add artisanal-todo -- node /absolute/path/to/todoApp/mcp-server/dist/index.js
```

### Available tools

| Tool | Description |
|------|-------------|
| `add_todo` | Add a new task by title |
| `list_todos` | List all pending and completed tasks (output is for the AI, not shown raw to the user) |
| `complete_todo` | Mark a task done — by list number, title substring, or UUID |
| `delete_todo` | Permanently delete a task — by list number, title substring, or UUID |

### Example prompts

Once connected, you can talk to Claude naturally:

- *"Add a todo: review the pull request"*
- *"What's on my todo list?"*
- *"Mark 'review the pull request' as done"*
- *"Delete task 3"*

The server writes to `~/Library/Application Support/ArtisanalTodo/todos.json` and pings the app to refresh immediately after any change.

---

## Project structure

```
todoApp/
├── project.yml              XcodeGen spec — source of truth for the Xcode project
├── setup.sh                 Dev setup (installs XcodeGen + generates project)
├── install.sh               Curl-installable release script
├── Makefile                 Build shortcuts
├── TodoApp/
│   ├── App/                 App entry point (@main)
│   ├── Views/               ContentView, TodoRowView
│   ├── Models/              TodoItem (shared with widget), TodoStore
│   ├── Theme/               AppTheme colors + fonts, AppColorScheme enum
│   └── Assets.xcassets/     7 adaptive color sets (light + dark variants)
├── TodoWidget/              WidgetKit extension (Small / Medium / Large)
└── mcp-server/
    ├── src/
    │   ├── index.ts         MCP server entry point — registers 4 tools
    │   └── todo-store.ts    File I/O and CRUD logic (no side effects, fully tested)
    └── dist/                Compiled output (run `npm run build`)
```

> `TodoApp.xcodeproj` is git-ignored — regenerate it anytime with `xcodegen generate` or `./setup.sh`.

---

## Roadmap

- [ ] App Store release (macOS)
- [ ] iOS companion app
- [ ] Android app
- [ ] Due dates
- [ ] Tags / projects
- [ ] Keyboard shortcuts

---

MIT License
