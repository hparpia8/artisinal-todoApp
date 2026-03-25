import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TodoEntry: TimelineEntry {
    let date: Date
    let items: [TodoItem]
}

// MARK: - Provider

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), items: sampleItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(TodoEntry(date: Date(), items: loadPending()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let entry = TodoEntry(date: Date(), items: loadPending())
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // MARK: - Data loading

    private func loadPending() -> [TodoItem] {
        let fileURL: URL
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.artisanal.todo"
        ) {
            fileURL = groupURL.appendingPathComponent("todos.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            fileURL = appSupport.appendingPathComponent("ArtisanalTodo/todos.json")
        }

        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let all = (try? decoder.decode([TodoItem].self, from: data)) ?? []
        return all.filter { !$0.isCompleted }
    }

    private var sampleItems: [TodoItem] {
        [
            TodoItem(title: "Buy fresh coffee beans"),
            TodoItem(title: "Read for 30 minutes"),
            TodoItem(title: "Call the dentist"),
            TodoItem(title: "Water the plants"),
            TodoItem(title: "Take a short walk"),
        ]
    }
}

// MARK: - Widget Entry View

struct TodoWidgetEntryView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) var family

    var maxItems: Int {
        switch family {
        case .systemSmall:  return 3
        case .systemMedium: return 5
        default:            return 10
        }
    }

    var displayItems: [TodoItem] { Array(entry.items.prefix(maxItems)) }
    var overflow: Int { max(0, entry.items.count - maxItems) }

    var body: some View {
        ZStack {
            Color("AppBackground")

            VStack(alignment: .leading, spacing: 0) {
                widgetHeader
                Rectangle()
                    .fill(Color("AppPaperLine"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                if entry.items.isEmpty {
                    allDoneView
                } else {
                    itemList
                }

                Spacer(minLength: 0)
            }
        }
    }

    var widgetHeader: some View {
        HStack {
            Text("todo")
                .font(.system(size: 13, weight: .light, design: .serif))
                .foregroundStyle(Color("AppPrimaryText"))
            Spacer()
            if !entry.items.isEmpty {
                Text("\(entry.items.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color("AppMutedText"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    var itemList: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: 7) {
                    Circle()
                        .stroke(Color("AppCheckboxBorder"), lineWidth: 1)
                        .frame(width: 11, height: 11)
                    Text(item.title)
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .foregroundStyle(Color("AppPrimaryText"))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)

                if idx < displayItems.count - 1 {
                    Rectangle()
                        .fill(Color("AppPaperLine"))
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                }
            }

            if overflow > 0 {
                Text("+ \(overflow) more")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color("AppMutedText"))
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
        }
    }

    var allDoneView: some View {
        HStack {
            Spacer()
            Text("all done")
                .font(.system(size: 12, weight: .light, design: .serif))
                .foregroundStyle(Color("AppMutedText"))
            Spacer()
        }
        .padding(.top, 14)
    }
}

// MARK: - Widget Configuration

struct TodoWidget: Widget {
    let kind = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Artisanal Todo")
        .description("Your tasks, always at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
