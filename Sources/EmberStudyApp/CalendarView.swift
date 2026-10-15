import SwiftUI

struct YearCalendarCard: View {
    @ObservedObject var store: StudyStore
    @Binding var selectedDay: StudyDay?
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    private var allDays: [StudyDay] { store.days(in: store.data.selectedYear) }
    private var weeks: [[StudyDay?]] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let first = allDays.first else { return [] }
        let firstWeekday = (calendar.component(.weekday, from: first.date) + 5) % 7
        let weekCount = (allDays.count + firstWeekday + 6) / 7
        var columns = Array(repeating: [StudyDay?](repeating: nil, count: 7), count: weekCount)
        for (index, day) in allDays.enumerated() {
            let position = firstWeekday + index
            columns[position / 7][position % 7] = day
        }
        return columns
    }
    private var monthLabels: [(String, Int)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        var result: [(String, Int)] = []
        var previousMonth = -1
        for (index, week) in weeks.enumerated() {
            guard let day = week.compactMap({ $0 }).first else { continue }
            let month = calendar.component(.month, from: day.date)
            if month != previousMonth {
                result.append((day.date.formatted(.dateTime.month(.abbreviated)), index))
                previousMonth = month
            }
        }
        return result
    }
    var body: some View {
        EmberCard(padding: 17) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your year in focus").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.emberText)
                        Text("A little progress, every day.").font(.system(size: 10)).foregroundStyle(Color.emberMuted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button { store.data.selectedYear -= 1 } label: { Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold)) }
                            .buttonStyle(.plain).foregroundStyle(Color.emberSecondary).frame(width: 23, height: 23).background(Color.emberSoftFill, in: RoundedRectangle(cornerRadius: 6))
                        Text(String(store.data.selectedYear)).font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(Color.emberText).frame(minWidth: 34)
                        Button { store.data.selectedYear += 1 } label: { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)) }
                            .buttonStyle(.plain).foregroundStyle(Color.emberSecondary).frame(width: 23, height: 23).background(Color.emberSoftFill, in: RoundedRectangle(cornerRadius: 6))
                    }
                    Button("Today") { store.data.selectedYear = Calendar.current.component(.year, from: Date()) }
                        .buttonStyle(EmberButtonStyle(compact: true))
                }
                GeometryReader { proxy in
                    let gutter: CGFloat = 3
                    let cell = min(11.5, (proxy.size.width - 28 - gutter * 52) / 53)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: gutter) {
                            Color.clear.frame(width: 22)
                            ForEach(Array(weeks.indices), id: \.self) { column in
                                ZStack(alignment: .leading) {
                                    Color.clear
                                    if let label = monthLabels.first(where: { $0.1 == column }) {
                                        Text(label.0.uppercased()).font(.system(size: 8, weight: .medium)).tracking(0.3).foregroundStyle(Color.emberMuted).fixedSize()
                                    }
                                }
                                .frame(width: cell, height: 12)
                            }
                        }
                        HStack(alignment: .top, spacing: 6) {
                            VStack(spacing: gutter) {
                                ForEach(0..<7, id: \.self) { index in
                                    Text(index % 2 == 0 ? weekdays[index] : " ").font(.system(size: 8, weight: .medium)).foregroundStyle(Color.emberMuted).frame(width: 16, height: cell)
                                }
                            }
                            HStack(alignment: .top, spacing: gutter) {
                                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                                    VStack(spacing: gutter) {
                                        ForEach(0..<7, id: \.self) { row in
                                            if row < week.count, let day = week[row] {
                                                Button { selectedDay = day } label: {
                                                    RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                                                        .fill(dayColor(day))
                                                        .frame(width: cell, height: cell)
                                                        .overlay(RoundedRectangle(cornerRadius: 2.2).stroke(Calendar.current.isDateInToday(day.date) ? Color.emberText.opacity(0.9) : Color.clear, lineWidth: 1))
                                                }
                                                .buttonStyle(.plain)
                                                .help("\(day.date.formatted(date: .long, time: .omitted)) · \(compactDuration(day.minutes)) studied · \(day.reached ? "Goal reached" : "Goal not reached")")
                                                .accessibilityLabel("\(day.date.formatted(date: .long, time: .omitted)), \(day.minutes) minutes studied")
                                                .popover(isPresented: selection(for: day)) { DayDetailPopover(day: day).presentationCompactAdaptation(.popover) }
                                            } else {
                                                Color.clear.frame(width: cell, height: cell)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 112)
                HStack(spacing: 14) {
                    Text("\(allDays.reduce(0) { $0 + $1.minutes } / 60) hours this year").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.emberSecondary)
                    Spacer()
                    Text("LESS").font(.system(size: 8, weight: .semibold)).tracking(0.5).foregroundStyle(Color.emberMuted)
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2).fill(levelColor(level)).frame(width: 9, height: 9)
                    }
                    Text("MORE").font(.system(size: 8, weight: .semibold)).tracking(0.5).foregroundStyle(Color.emberMuted)
                    Circle().stroke(Color.emberText.opacity(0.9), lineWidth: 1).frame(width: 8, height: 8)
                    Text("TODAY").font(.system(size: 8, weight: .semibold)).tracking(0.5).foregroundStyle(Color.emberMuted)
                }
            }
        }
    }

    private func selection(for day: StudyDay) -> Binding<Bool> {
        Binding(get: { selectedDay?.date == day.date }, set: { if !$0 && selectedDay?.date == day.date { selectedDay = nil } })
    }
    private func dayColor(_ day: StudyDay) -> Color {
        if day.minutes == 0 { return Color.emberMutedFill }
        if day.reached { return Color.accentColor }
        let fraction = min(0.88, max(0.18, day.ratio * 0.8))
        return Color.accentColor.opacity(fraction)
    }
    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0: Color.emberMutedFill
        case 1: Color.accentColor.opacity(0.2)
        case 2: Color.accentColor.opacity(0.42)
        case 3: Color.accentColor.opacity(0.68)
        default: Color.accentColor
        }
    }
}

struct DayDetailPopover: View {
    let day: StudyDay
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.emberText)
            HStack(spacing: 18) {
                MetricLabel(title: "Studied", value: compactDuration(day.minutes), tint: .accentColor)
                MetricLabel(title: "Goal", value: compactDuration(day.goal))
            }
            Label(day.reached ? "Daily goal reached" : "\(compactDuration(max(0, day.goal - day.minutes))) to goal", systemImage: day.reached ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(day.reached ? Color.accentColor : Color.emberSecondary)
            ProgressTrack(value: day.ratio, height: 5)
        }
        .padding(15).frame(width: 235).background(Color.emberSurface)
    }
}
