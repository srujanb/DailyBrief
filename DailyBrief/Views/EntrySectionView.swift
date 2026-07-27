import SwiftUI

enum EntryField: Hashable {
    case standup
    case achievements
    case gratitude
}

struct EntrySectionView: View {
    private static let minimumEditorHeight: CGFloat = 110
    private static let maximumEditorHeight: CGFloat = 160

    let title: String
    let placeholder: String
    let field: EntryField
    @Binding var text: String
    @Binding var focusedField: EntryField?
    var onTab: (MultilineTextEditor.TabDirection) -> Void

    @State private var editorContentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(accentColor.opacity(0.9))
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .textBackgroundColor),
                                Color(nsColor: .textBackgroundColor).opacity(0.82)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isFocused ? accentColor.opacity(0.5) : Color.primary.opacity(0.08),
                                lineWidth: isFocused ? 1.5 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.035), radius: 7, x: 0, y: 3)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .allowsHitTesting(false)
                }

                MultilineTextEditor(
                    text: $text,
                    contentHeight: $editorContentHeight,
                    isFocused: isFocused,
                    onFocus: {
                        focusedField = field
                    },
                    onTab: onTab
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .frame(height: editorHeight)
        }
    }

    private var editorHeight: CGFloat {
        min(
            Self.maximumEditorHeight,
            max(Self.minimumEditorHeight, editorContentHeight + 8)
        )
    }

    private var isFocused: Bool {
        focusedField == field
    }

    private var accentColor: Color {
        switch field {
        case .standup:
            return .blue
        case .achievements:
            return .green
        case .gratitude:
            return .red
        }
    }
}
