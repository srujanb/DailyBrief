import SwiftUI

struct ActivityCalendarView: View {
    @ObservedObject var viewModel: DailyBriefViewModel
    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 6), count: 7)
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    init(viewModel: DailyBriefViewModel) {
        self.viewModel = viewModel
        _displayedMonth = State(initialValue: viewModel.selectedDate)
    }

    var body: some View {
        VStack(spacing: 13) {
            HStack {
                Button {
                    displayedMonth = monthOffset(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(CalendarIconButtonStyle())

                Text(monthFormatter.string(from: displayedMonth))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)

                Button {
                    displayedMonth = monthOffset(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(CalendarIconButtonStyle())
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34)
                }

                ForEach(calendarDays) { day in
                    if let date = day.date {
                        Button {
                            viewModel.selectDate(date)
                        } label: {
                            dayCell(for: date)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 34, height: 38)
                    }
                }
            }

            HStack(spacing: 10) {
                legendDot(.blue)
                Text("Standup")
                legendDot(.green)
                Text("Achievements")
                legendDot(.red)
                Text("Gratitude")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(4)
        .frame(width: 292)
        .onAppear {
            displayedMonth = viewModel.selectedDate
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let activity = viewModel.activity(for: date)

        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 26, height: 22)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isToday && !isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                )

            HStack(spacing: 2.5) {
                calendarDot(.blue, isVisible: activity.hasStandup)
                calendarDot(.green, isVisible: activity.hasAchievements)
                calendarDot(.red, isVisible: activity.hasGratitude)
            }
            .frame(height: 6)
        }
        .frame(width: 34, height: 38)
        .contentShape(Rectangle())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var calendarDays: [CalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else {
            return []
        }

        var days: [CalendarDay] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            let date = calendar.isDate(cursor, equalTo: displayedMonth, toGranularity: .month) ? cursor : nil
            days.append(CalendarDay(date: date))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? lastWeek.end
        }
        return days
    }

    private func monthOffset(_ offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    private func calendarDot(_ color: Color, isVisible: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .opacity(isVisible ? 1 : 0)
            .frame(width: 5, height: 5)
    }

    private func legendDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
}

private struct CalendarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04))
            )
    }
}
