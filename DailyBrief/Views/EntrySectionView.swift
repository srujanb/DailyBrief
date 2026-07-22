import SwiftUI

enum EntryField: Hashable {
    case standup
    case achievements
    case gratitude
}

struct EntrySectionView: View {
    let title: String
    let placeholder: String
    let field: EntryField
    @Binding var text: String
    var focusedField: FocusState<EntryField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused(focusedField, equals: field)
                    .padding(8)
            }
            .frame(height: 108)
        }
    }
}
