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
        VStack(spacing: 12) {
            HStack {
                Button {
                    displayedMonth = monthOffset(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text(monthFormatter.string(from: displayedMonth))
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button {
                    displayedMonth = monthOffset(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
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

            HStack(spacing: 12) {
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

            HStack(spacing: 2) {
                if activity.hasStandup {
                    calendarDot(.blue)
                }
                if activity.hasAchievements {
                    calendarDot(.green)
                }
                if activity.hasGratitude {
                    calendarDot(.red)
                }
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

    private func calendarDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 4.5, height: 4.5)
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
