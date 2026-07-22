import SwiftUI

struct DateHeaderView: View {
    @ObservedObject var viewModel: DailyBriefViewModel
    @State private var showsCalendar = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 14) {
            Button {
                viewModel.selectPreviousDay()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(HeaderIconButtonStyle())
            .help("Previous day")

            Button {
                showsCalendar.toggle()
            } label: {
                Text(dateFormatter.string(from: viewModel.selectedDate))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .popover(isPresented: $showsCalendar, arrowEdge: .top) {
                ActivityCalendarView(viewModel: viewModel)
                    .padding(14)
            }

            Button {
                viewModel.selectNextDay()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(HeaderIconButtonStyle())
            .help("Next day")
        }
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : Color.primary.opacity(0.045))
            )
    }
}
