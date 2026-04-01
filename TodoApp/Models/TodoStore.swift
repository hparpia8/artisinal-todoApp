import Foundation
import Combine
import WidgetKit
import SQLite3

// sqlite3_bind_text expects SQLITE_TRANSIENT to copy the string — recreate it
// from the C macro since Swift doesn't expose it directly.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let fileURL: URL
    private var fileWatcher: DispatchSourceFileSystemObject?

    static var storeURL: URL {
        // Only use the App Group container if it already exists on disk —
        // i.e., the app is properly signed with the group entitlement.
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.artisanal.todo"
        ), FileManager.default.fileExists(atPath: groupURL.path) {
            return groupURL.appendingPathComponent("todos.db")
        }
        // Fallback for unsigned/development builds
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ArtisanalTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.db")
    }

    /// Production initializer — uses the default store path and starts file watching.
    convenience init() {
        self.init(fileURL: Self.storeURL, watch: true)
    }

    /// Testable initializer — accepts a custom file URL and optionally disables file watching.
    init(fileURL: URL, watch: Bool = false) {
        self.fileURL = fileURL
        createTableIfNeeded()
        load()
        if watch {
            startWatching()
        }
    }

    // MARK: - Date formatting

    // Try fractional seconds first (MCP server writes "2026-03-31T15:00:00.123Z"),
    // then fall back to plain for any legacy entries.
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ str: String) -> Date? {
        isoFractional.date(from: str) ?? isoPlain.date(from: str)
    }

    private static func formatDate(_ date: Date) -> String {
        isoFractional.string(from: date)
    }

    // MARK: - SQLite helpers

    private func openDatabase() -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            print("[TodoStore] ⚠️ Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_close(db)
            return nil
        }
        return db
    }

    private func createTableIfNeeded() {
        guard let db = openDatabase() else { return }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS todos (
                id          TEXT    NOT NULL PRIMARY KEY,
                title       TEXT    NOT NULL,
                createdAt   TEXT    NOT NULL,
                completedAt TEXT,
                isCompleted INTEGER NOT NULL DEFAULT 0,
                sortOrder   INTEGER NOT NULL DEFAULT 0
            )
        """, nil, nil, nil)
    }

    // MARK: - Persistence

    func load() {
        guard let db = openDatabase() else { return }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT id, title, createdAt, completedAt, isCompleted FROM todos ORDER BY sortOrder ASC"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        var loaded: [TodoItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(stmt, 0),
                  let titleText = sqlite3_column_text(stmt, 1),
                  let createdAtText = sqlite3_column_text(stmt, 2) else { continue }

            let idStr = String(cString: idText)
            let title = String(cString: titleText)
            let createdAtStr = String(cString: createdAtText)
            let completedAtStr = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let isCompleted = sqlite3_column_int(stmt, 4) != 0

            guard let uuid = UUID(uuidString: idStr),
                  let createdAt = Self.parseDate(createdAtStr) else { continue }

            loaded.append(TodoItem(
                id: uuid,
                title: title,
                createdAt: createdAt,
                completedAt: completedAtStr.flatMap { Self.parseDate($0) },
                isCompleted: isCompleted
            ))
        }
        items = loaded
    }

    private func save() {
        guard let db = openDatabase() else { return }
        defer { sqlite3_close(db) }

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM todos", nil, nil, nil)

        var stmt: OpaquePointer?
        let sql = """
            INSERT INTO todos (id, title, createdAt, completedAt, isCompleted, sortOrder)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return
        }
        defer { sqlite3_finalize(stmt) }

        for (i, item) in items.enumerated() {
            sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, item.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, Self.formatDate(item.createdAt), -1, SQLITE_TRANSIENT)
            if let completedAt = item.completedAt {
                sqlite3_bind_text(stmt, 4, Self.formatDate(completedAt), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_int(stmt, 5, item.isCompleted ? 1 : 0)
            sqlite3_bind_int(stmt, 6, Int32(i))
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }

        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - File watching

    // Watches the database file for external writes (e.g. from the MCP server).
    // The MCP server closes its connection after each write, which checkpoints
    // the WAL and updates the main .db file, triggering this watcher.
    private func startWatching() {
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.load()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileWatcher = source
    }

    // MARK: - Public API

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[i].isCompleted {
            var restored = items.remove(at: i)
            restored.restore()
            items.insert(restored, at: 0)
        } else {
            items[i].complete()
        }
        save()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    var pending: [TodoItem] {
        items.filter { !$0.isCompleted }
    }

    var completed: [TodoItem] {
        items.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt) }
    }
}
