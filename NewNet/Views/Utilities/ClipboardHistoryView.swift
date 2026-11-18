import AppKit
import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var clipboardService: ClipboardHistoryService
    @State private var copiedItemID: UUID? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                Text("Clipboard History")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(clipboardService.items.count) item\(clipboardService.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Header with search & clear
            searchAndFilterBar

            // History list
            if clipboardService.filteredItems.isEmpty {
                emptyStateView
            } else {
                itemsListView
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Search & Filters

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Search clipboard…", text: $clipboardService.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !clipboardService.searchQuery.isEmpty {
                        Button {
                            clipboardService.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .liquidGlassControl()

                if !clipboardService.items.isEmpty {
                    Button {
                        withAnimation(DesignTokens.Animation.transition) {
                            clipboardService.clearHistory()
                        }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                    .help("Clear unpinned history")
                }
            }

            // Filter pills
            HStack(spacing: 6) {
                ForEach(ClipboardItemKind.allCases, id: \.self) { kind in
                    let isSelected = clipboardService.selectedFilter == kind
                    Button {
                        withAnimation(DesignTokens.Animation.transition) {
                            clipboardService.selectedFilter = kind
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: kind.iconName)
                                .font(.system(size: 10))
                            Text(kind.title)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .liquidGlassPill(
                            tint: isSelected ? Color.blue : nil,
                            isActive: isSelected
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // MARK: - Items List

    private var itemsListView: some View {
        VStack(spacing: 6) {
            ForEach(clipboardService.filteredItems) { item in
                clipboardRow(item: item)
            }
        }
    }

    private func clipboardRow(item: ClipboardItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon or thumbnail
            if item.kind == .image, let data = item.imageThumbnailData, let nsImg = NSImage(data: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(itemKindColor(item.kind).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.kind.iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(itemKindColor(item.kind))
                }
            }

            // Content text & meta
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(timeAgo(from: item.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if item.charCount > 0 && item.kind != .image {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Text("\(item.charCount) chars")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if item.isPinned {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer(minLength: 4)

            // Action buttons
            HStack(spacing: 4) {
                // Pin button
                Button {
                    withAnimation(DesignTokens.Animation.hover) {
                        clipboardService.togglePin(item)
                    }
                } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundStyle(item.isPinned ? .orange : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(LiquidGlassButtonStyle(isCircular: true))
                .help(item.isPinned ? "Unpin item" : "Pin item to top")

                // Copy button
                Button {
                    clipboardService.copyToPasteboard(item)
                    withAnimation(DesignTokens.Animation.hover) {
                        copiedItemID = item.id
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if copiedItemID == item.id {
                            withAnimation { copiedItemID = nil }
                        }
                    }
                } label: {
                    Image(systemName: copiedItemID == item.id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: copiedItemID == item.id ? .bold : .medium))
                        .foregroundStyle(copiedItemID == item.id ? .green : .primary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(LiquidGlassButtonStyle(isCircular: true))
                .help("Copy to clipboard")

                // Delete button
                Button(role: .destructive) {
                    withAnimation(DesignTokens.Animation.transition) {
                        clipboardService.deleteItem(item)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(LiquidGlassButtonStyle(isCircular: true))
                .help("Delete from history")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlassCard()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text(clipboardService.searchQuery.isEmpty ? "No clipboard items yet" : "No matches found")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            if clipboardService.searchQuery.isEmpty {
                Text("Copied text, links, files, and images will appear here automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .liquidGlassCard()
    }

    // MARK: - Helpers

    private func itemKindColor(_ kind: ClipboardItemKind) -> Color {
        switch kind {
        case .all: return .primary
        case .text: return .blue
        case .link: return .purple
        case .image: return .green
        case .files: return .orange
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
