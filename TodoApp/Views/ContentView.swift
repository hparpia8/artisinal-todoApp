import SwiftUI

struct ContentView: View {
    @StateObject private var store = TodoStore()
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool
    @AppStorage("colorScheme") private var colorSchemePreference: String = "auto"

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            thinDivider
            scrollContent
            thinDivider
            inputBar
        }
        .background(AppTheme.background)
        .frame(minWidth: 380, idealWidth: 460, minHeight: 500, idealHeight: 650)
    }

    // MARK: - Header

    var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("todo")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.primaryText)
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer()

            HStack(spacing: 14) {
                if store.pending.count > 0 {
                    Text("\(store.pending.count) remaining")
                        .font(AppTheme.captionFont.monospacedDigit())
                        .foregroundStyle(AppTheme.mutedText)
                }
                colorSchemePicker
            }
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.top, 32) // clear traffic-light buttons
        .padding(.bottom, 12)
        .background(AppTheme.background)
    }

    var colorSchemePicker: some View {
        HStack(spacing: 1) {
            ForEach(AppColorScheme.allCases, id: \.rawValue) { mode in
                Button {
                    colorSchemePreference = mode.rawValue
                } label: {
                    Image(systemName: mode.systemIcon)
                        .font(.system(size: 11))
                        .frame(width: 26, height: 22)
                        .foregroundStyle(
                            colorSchemePreference == mode.rawValue
                                ? AppTheme.accent
                                : AppTheme.mutedText
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    colorSchemePreference == mode.rawValue
                                        ? AppTheme.accent.opacity(0.12)
                                        : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
                .help(mode.label)
            }
        }
    }

    // MARK: - Scroll content

    var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {

                    // Completed history (oldest → newest, scrolled above)
                    if !store.completed.isEmpty {
                        completedHeader
                        ForEach(store.completed) { item in
                            TodoRowView(item: item) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    store.toggle(item)
                                }
                            }
                        }
                        nowDivider
                    }

                    // Active / pending items
                    if store.pending.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.pending) { item in
                            TodoRowView(item: item) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    store.toggle(item)
                                }
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    withAnimation { store.delete(item) }
                                }
                            }
                        }
                    }

                    // Bottom anchor — app opens scrolled here
                    Spacer(minLength: 32)
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    var completedHeader: some View {
        HStack(spacing: 10) {
            Text("completed")
                .font(AppTheme.monoFont)
                .tracking(1.5)
                .foregroundStyle(AppTheme.mutedText)
            Rectangle()
                .fill(AppTheme.paperLine)
                .frame(height: 0.5)
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    var nowDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(AppTheme.paperLine)
                .frame(height: 0.5)
            Text("now")
                .font(AppTheme.monoFont)
                .tracking(1.5)
                .foregroundStyle(AppTheme.accent)
            Rectangle()
                .fill(AppTheme.paperLine)
                .frame(height: 0.5)
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.vertical, 18)
    }

    var emptyState: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 60)
            Text("nothing pending")
                .font(.system(size: 14, weight: .light, design: .serif))
                .foregroundStyle(AppTheme.completedText)
            Text("type below to add a task")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.completedText.opacity(0.6))
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input bar

    var inputBar: some View {
        HStack(spacing: 12) {
            Circle()
                .stroke(AppTheme.checkboxBorder.opacity(0.35), lineWidth: 1)
                .frame(width: 18, height: 18)

            TextField("add a task...", text: $newItemText)
                .textFieldStyle(.plain)
                .font(AppTheme.inputFont)
                .foregroundStyle(AppTheme.primaryText)
                .focused($inputFocused)
                .onSubmit { addItem() }

            if !newItemText.isEmpty {
                Button(action: addItem) {
                    Image(systemName: "return")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.vertical, 14)
        .background(AppTheme.background)
        .animation(.easeInOut(duration: 0.15), value: newItemText.isEmpty)
    }

    var thinDivider: some View {
        Rectangle()
            .fill(AppTheme.paperLine)
            .frame(height: 0.5)
    }

    // MARK: - Actions

    func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            store.add(newItemText)
        }
        newItemText = ""
    }
}
