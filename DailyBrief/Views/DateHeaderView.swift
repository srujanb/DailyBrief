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
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
            .help("Next day")
        }
    }
}
