import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var completedAt: Date?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isCompleted = isCompleted
    }

    mutating func complete() {
        isCompleted = true
        completedAt = Date()
    }

    mutating func restore() {
        isCompleted = false
        completedAt = nil
    }
}
