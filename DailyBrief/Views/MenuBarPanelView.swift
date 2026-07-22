import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var viewModel: DailyBriefViewModel
    @FocusState private var focusedField: EntryField?

    var body: some View {
        VStack(spacing: 16) {
            DateHeaderView(viewModel: viewModel)
                .padding(.top, 2)

            VStack(spacing: 14) {
                EntrySectionView(
                    title: "Standup Updates",
                    placeholder: "What did you work on today?",
                    field: .standup,
                    text: $viewModel.standup,
                    focusedField: $focusedField
                )

                EntrySectionView(
                    title: "Achievements",
                    placeholder: "What did you accomplish or smash today?",
                    field: .achievements,
                    text: $viewModel.achievements,
                    focusedField: $focusedField
                )

                EntrySectionView(
                    title: "Gratitude",
                    placeholder: "What made you smile or feel thankful for today?",
                    field: .gratitude,
                    text: $viewModel.gratitude,
                    focusedField: $focusedField
                )
            }

            Divider()

            SettingsFooterView(viewModel: viewModel)
        }
        .padding(18)
        .frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                focusedField = .standup
            }
        }
        .onDisappear {
            viewModel.saveImmediately()
        }
    }
}
