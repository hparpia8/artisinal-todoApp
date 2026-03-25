import Foundation
import Combine
import WidgetKit

class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let fileURL: URL

    static var storeURL: URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.artisanal.todo"
        ) {
            return groupURL.appendingPathComponent("todos.json")
        }
        // Fallback for unsigned/development builds
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ArtisanalTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }

    init() {
        fileURL = Self.storeURL
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([TodoItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[i].isCompleted {
            items[i].restore()
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
