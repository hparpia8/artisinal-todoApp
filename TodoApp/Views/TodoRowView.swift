import SwiftUI

struct TodoRowView: View {
    let item: TodoItem
    let onToggle: () -> Void

    @State private var isHovered = false

    private var isCompleted: Bool { item.isCompleted }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            checkboxButton
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(isCompleted ? AppTheme.completedText : AppTheme.primaryText)
                    .strikethrough(isCompleted, color: AppTheme.completedText)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .animation(.easeInOut(duration: 0.2), value: isCompleted)

                if isCompleted, let completedAt = item.completedAt {
                    Text(completedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.completedText.opacity(0.55))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            if !isCompleted {
                Text(item.createdAt, format: .dateTime.hour().minute())
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.mutedText.opacity(0.7))
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.vertical, AppTheme.rowPaddingV)
        .background(
            Rectangle()
                .fill(isHovered ? AppTheme.paperLine.opacity(0.28) : Color.clear)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        )
        .overlay(
            Rectangle()
                .fill(AppTheme.paperLine.opacity(0.7))
                .frame(height: 0.5)
                .padding(.horizontal, AppTheme.rowPaddingH),
            alignment: .bottom
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    var checkboxButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .stroke(
                        isCompleted
                            ? AppTheme.accent
                            : (isHovered ? AppTheme.accent : AppTheme.checkboxBorder),
                        lineWidth: 1.5
                    )
                    .frame(width: 18, height: 18)

                if isCompleted {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.18))
                        .frame(width: 18, height: 18)

                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
    }
}
