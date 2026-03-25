import AppIntents
import WidgetKit
import Foundation

// MARK: - Toggle intent (check / uncheck a todo from the widget)

struct ToggleTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Todo"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Todo ID")
    var todoID: String

    init() { todoID = "" }
    init(todoID: String) { self.todoID = todoID }

    func perform() async throws -> some IntentResult {
        var items = WidgetStore.load()
        guard let idx = items.firstIndex(where: { $0.id.uuidString == todoID }) else {
            return .result()
        }
        if items[idx].isCompleted {
            var item = items.remove(at: idx)
            item.restore()
            items.insert(item, at: 0)   // restored items go to top of active list
        } else {
            items[idx].complete()
        }
        WidgetStore.save(items)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Shared file access used by both the widget and its intents
//
// Reads/writes the App Group container when available (requires proper signing
// with group.com.artisanal.todo). Falls back to Application Support for
// unsigned development builds — changes made via widget intents won't be
// visible in the main app until App Groups are configured.

enum WidgetStore {
    static var fileURL: URL? {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.artisanal.todo"
        ) {
            return groupURL.appendingPathComponent("todos.json")
        }
        // Fallback: widget's own sandbox container (unsigned builds)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("ArtisanalTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }

    static func load() -> [TodoItem] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TodoItem].self, from: data)) ?? []
    }

    static func save(_ items: [TodoItem]) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
