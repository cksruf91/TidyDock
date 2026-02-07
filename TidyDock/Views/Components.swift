import AppKit
import SwiftUI

struct SystemUsageCard: View {
    let title: String
    let totalCount: Int
    let activeCount: Int
    let totalSize: Int64
    let reclaimableSize: Int64
    let highlight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(activeCount)/\(totalCount) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(formatBytes(totalSize))
                .font(.title3)
                .bold()
            HStack {
                Text("Reclaimable")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatBytes(reclaimableSize))
            }
            .font(.subheadline)
        }
        .padding(12)
        .cardBackground(highlight: highlight)
    }
}

private struct CardBackground: ViewModifier {
    let highlight: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let cornerRadius: CGFloat = 16
        let baseFill = colorScheme == .light ? TidyTheme.lightCard : TidyTheme.darkCard
        let highlightFill = colorScheme == .light ? TidyTheme.lightHighlight : TidyTheme.darkHighlight
        let stroke = colorScheme == .light ? TidyTheme.lightStroke : TidyTheme.darkStroke
        let darkShadowOpacity = colorScheme == .light ? 0.15 : 0.40
        let lightShadowOpacity = colorScheme == .light ? 0.95 : 0.12

        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(highlight ? highlightFill : Color.clear)
                    )
                    .shadow(color: Color.black.opacity(darkShadowOpacity), radius: 10, x: 10, y: 20)
                    .shadow(color: Color.white.opacity(lightShadowOpacity), radius: 16, x: -2, y: -2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke)
            )
    }
}

extension View {
    func cardBackground(highlight: Bool) -> some View {
        modifier(CardBackground(highlight: highlight))
    }

    func deleteButtonStyle() -> some View {
        modifier(DeleteButtonStyle())
    }
}

private struct DeleteButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.22))
            )
    }
}

struct TooltipArea: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}

func copyToClipboard(_ value: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
}

func truncatedImageName(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 12 else { return trimmed }
    let isHex = trimmed.unicodeScalars.allSatisfy { scalar in
        switch scalar {
        case "0"..."9", "a"..."f", "A"..."F":
            return true
        default:
            return false
        }
    }
    return isHex ? String(trimmed.prefix(12)) : trimmed
}

func truncatedId(_ value: String) -> String {
    let normalized = value.hasPrefix("sha256:") ? String(value.dropFirst(7)) : value
    return String(normalized.prefix(12))
}

func formatBytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
}

func formattedNetworkDate(_ network: DockerNetwork) -> String {
    if let createdAt = network.createdAt {
        return createdAt.formatted(date: .numeric, time: .shortened)
    }
    return network.createdRaw
}

func booleanText(_ value: Bool?) -> String {
    guard let value else { return "-" }
    return value ? "true" : "false"
}

func formattedLabels(_ labels: [String: String]) -> String {
    guard !labels.isEmpty else { return "-" }
    return labels
        .keys
        .sorted()
        .map { key in
            if let value = labels[key], !value.isEmpty {
                return "\(key)=\(value)"
            }
            return key
        }
        .joined(separator: ", ")
}

extension DockerSystemImage {
    var effectiveSizeBytes: Int64 {
        max(0, sizeBytes - sharedSizeBytes)
    }

    var displayName: String {
        if let tag = repoTags.first, !tag.isEmpty {
            return tag
        }
        if let digest = repoDigests.first, !digest.isEmpty {
            return digest
        }
        return truncatedId(id)
    }
}

struct KeyValueRow: View {
    let label: String
    let value: String
    private let valueWidth: CGFloat = 130

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)
                .background(TooltipArea(text: value))
                .frame(width: valueWidth, alignment: .leading)
        }
        .font(.subheadline)
    }
}

struct KeyValueList: View {
    let title: String
    let items: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if items.isEmpty {
                Text("-")
                    .foregroundColor(.secondary)
            } else {
                ForEach(items.keys.sorted(), id: \.self) { key in
                    KeyValueRow(label: key, value: items[key] ?? "-")
                }
            }
        }
    }
}
