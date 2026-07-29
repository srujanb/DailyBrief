import SwiftUI

struct MenuBarPanelView: View {
    private enum PanelMode {
        case editor
        case searchResults
        case searchDetail
    }

    @ObservedObject var viewModel: DailyBriefViewModel
    @State private var focusedField: EntryField?
    @State private var panelMode: PanelMode = .editor
    @State private var activeSearchResult: EntrySearchResult?

    var body: some View {
        ZStack(alignment: .top) {
            if panelMode != .editor {
                EntrySearchView(
                    viewModel: viewModel,
                    isActive: panelMode == .searchResults,
                    onClose: closeSearch,
                    onOpenResult: openSearchResult
                )
                .opacity(panelMode == .searchResults ? 1 : 0)
                .allowsHitTesting(panelMode == .searchResults)
                .accessibilityHidden(panelMode != .searchResults)
            }

            if panelMode != .searchResults {
                editorContent
                    .opacity(panelMode == .searchResults ? 0 : 1)
                    .allowsHitTesting(panelMode != .searchResults)
                    .accessibilityHidden(panelMode == .searchResults)
            }
        }
        .padding(20)
        .frame(width: 438)
        .background(panelBackground)
        .onAppear {
            if panelMode == .editor {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    focusedField = .standup
                }
            }
        }
        .onDisappear {
            resetAfterPanelDismissal()
        }
        .onChange(of: viewModel.selectedDateKey, perform: handleSelectedDateChange)
        .onExitCommand(perform: handleExitCommand)
    }

    private var editorContent: some View {
        VStack(spacing: 17) {
            editorHeader
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

            SettingsFooterView(
                viewModel: viewModel,
                onSearch: panelMode == .editor ? beginSearch : nil
            )
        }
    }

    @ViewBuilder
    private var editorHeader: some View {
        if panelMode == .searchDetail, let activeSearchResult {
            SearchDetailHeaderView(
                result: activeSearchResult,
                onBack: returnToSearchResults
            )
        } else {
            DateHeaderView(viewModel: viewModel)
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

    private func beginSearch() {
        focusedField = nil
        activeSearchResult = nil
        panelMode = .searchResults
        viewModel.beginSearch()
    }

    private func openSearchResult(_ result: EntrySearchResult) {
        guard viewModel.openSearchResult(result) else {
            return
        }

        activeSearchResult = result
        panelMode = .searchDetail

        DispatchQueue.main.async {
            focusedField = result.field
        }
    }

    private func returnToSearchResults() {
        viewModel.saveImmediately()
        focusedField = nil
        panelMode = .searchResults
    }

    private func closeSearch() {
        viewModel.endSearch()
        activeSearchResult = nil
        panelMode = .editor

        DispatchQueue.main.async {
            focusedField = .standup
        }
    }

    private func resetAfterPanelDismissal() {
        viewModel.saveImmediately()
        viewModel.endSearch()
        activeSearchResult = nil
        focusedField = nil
        panelMode = .editor
    }

    private func handleSelectedDateChange(_ dateKey: String) {
        guard
            panelMode == .searchDetail,
            activeSearchResult?.dateKey != dateKey
        else {
            return
        }

        viewModel.endSearch()
        activeSearchResult = nil
        panelMode = .editor
        focusedField = .standup
    }

    private func handleExitCommand() {
        switch panelMode {
        case .editor:
            break
        case .searchResults:
            closeSearch()
        case .searchDetail:
            returnToSearchResults()
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
