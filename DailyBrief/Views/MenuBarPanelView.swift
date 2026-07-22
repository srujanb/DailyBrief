import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var viewModel: DailyBriefViewModel
    @State private var focusedField: EntryField?

    var body: some View {
        VStack(spacing: 17) {
            DateHeaderView(viewModel: viewModel)
                .padding(.top, 4)

            VStack(spacing: 15) {
                EntrySectionView(
                    title: "Standup Updates",
                    placeholder: "What did you work on today?",
                    field: .standup,
                    text: $viewModel.standup,
                    focusedField: $focusedField,
                    onTab: moveFocus
                )

                EntrySectionView(
                    title: "Achievements",
                    placeholder: "What did you accomplish or smash today?",
                    field: .achievements,
                    text: $viewModel.achievements,
                    focusedField: $focusedField,
                    onTab: moveFocus
                )

                EntrySectionView(
                    title: "Gratitude",
                    placeholder: "What made you smile or feel thankful for today?",
                    field: .gratitude,
                    text: $viewModel.gratitude,
                    focusedField: $focusedField,
                    onTab: moveFocus
                )
            }

            Divider()
                .overlay(Color.primary.opacity(0.06))

            SettingsFooterView(viewModel: viewModel)
        }
        .padding(20)
        .frame(width: 438)
        .background(panelBackground)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                focusedField = .standup
            }
        }
        .onDisappear {
            viewModel.saveImmediately()
        }
    }

    private var panelBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                    Color.black.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func moveFocus(_ direction: MultilineTextEditor.TabDirection) {
        let fields: [EntryField] = [.standup, .achievements, .gratitude]
        let currentField = focusedField ?? .standup
        guard let currentIndex = fields.firstIndex(of: currentField) else {
            focusedField = .standup
            return
        }

        switch direction {
        case .forward:
            focusedField = fields[(currentIndex + 1) % fields.count]
        case .backward:
            focusedField = fields[(currentIndex + fields.count - 1) % fields.count]
        }
    }
}
