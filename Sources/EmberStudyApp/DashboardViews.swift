import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: StudyStore
    @ObservedObject var engine: TimerEngine
    @State private var selectedDay: StudyDay?
    private var todaySessions: [StudySession] { store.sessions(on: Date()) }
    private var todayLabel: String { Date().formatted(.dateTime.weekday(.wide).month(.wide).day()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Good to see you").font(.system(size: 22, weight: .semibold, design: .rounded)).tracking(-0.4).foregroundStyle(Color.emberText)
                        Text(todayLabel).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberMuted)
                    }
                    Spacer()
                    HStack(spacing: 6) { Image(systemName: "sun.max.fill").foregroundStyle(Color.accentColor); Text("A fresh page").foregroundStyle(Color.emberSecondary) }
                        .font(.system(size: 10, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.emberSurface, in: Capsule()).overlay(Capsule().stroke(Color.emberStroke, lineWidth: 1))
                }
                HStack(alignment: .top, spacing: 14) {
                    TodayProgressCard(store: store).frame(maxWidth: .infinity)
                    TimerCard(engine: engine, store: store, compact: true).frame(maxWidth: 365)
                }
                YearCalendarCard(store: store, selectedDay: $selectedDay)
                HStack(alignment: .top, spacing: 14) {
                    WeeklySummaryCard(store: store).frame(maxWidth: .infinity)
                    TodayTimelineCard(store: store, sessions: todaySessions).frame(maxWidth: 365)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.emberBackground)
    }
}

struct TodayProgressCard: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        EmberCard(padding: 17) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeading(title: "Today’s progress", subtitle: "A goal for every kind of day")
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(compactDuration(store.todayMinutes)).font(.system(size: 29, weight: .semibold, design: .rounded).monospacedDigit()).tracking(-1).foregroundStyle(Color.emberText)
                    Text("/ \(compactDuration(store.todayGoal))").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.emberMuted)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: store.todayMinutes >= store.todayGoal ? "checkmark.circle.fill" : "sparkle")
                        Text(store.todayMinutes >= store.todayGoal ? "Goal reached" : "\(compactDuration(store.todayRemaining)) left")
                    }.font(.system(size: 10, weight: .semibold)).foregroundStyle(store.todayMinutes >= store.todayGoal ? Color.accentColor : Color.emberSecondary)
                }
                ProgressTrack(value: Double(store.todayMinutes) / Double(max(store.todayGoal, 1)), height: 7)
                HStack {
                    Text("\(Int(Double(store.todayMinutes) / Double(max(store.todayGoal, 1)) * 100))% of your daily goal")
                    Spacer()
                    Text("\(store.todayGoal) min goal")
                }.font(.system(size: 9, weight: .medium)).foregroundStyle(Color.emberMuted)
            }
        }
    }
}

struct TodayTimelineCard: View {
    @ObservedObject var store: StudyStore
    let sessions: [StudySession]
    var body: some View {
        EmberCard(padding: 17) {
            VStack(alignment: .leading, spacing: 11) {
                CardHeading(title: "Today’s sessions", subtitle: "Your day, in little chapters")
                if sessions.isEmpty {
                    HStack(spacing: 8) { Image(systemName: "moon.zzz").foregroundStyle(Color.emberMuted); Text("No sessions yet. Start when you’re ready.").foregroundStyle(Color.emberMuted) }
                        .font(.system(size: 10)).padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            SessionTimelineRow(session: session, isLast: index == sessions.count - 1)
                        }
                    }
                    HStack {
                        Text("\(sessions.filter { $0.kind.isStudy }.count) focus blocks")
                        Spacer()
                        Text("\(compactDuration(store.todayMinutes)) studied")
                    }.font(.system(size: 9, weight: .medium)).foregroundStyle(Color.emberMuted).padding(.top, 2)
                }
            }
        }
    }
}

struct SessionTimelineRow: View {
    let session: StudySession
    let isLast: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            VStack(spacing: 0) {
                Circle().fill(session.kind.isStudy ? Color.accentColor : Color.emberMuted.opacity(0.6)).frame(width: 7, height: 7).padding(.top, 3)
                if !isLast { Rectangle().fill(Color.emberStroke).frame(width: 1, height: 27) }
            }.frame(width: 8)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.kind.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.emberText)
                    if session.isRunning { Text("LIVE").font(.system(size: 7, weight: .bold)).tracking(0.5).foregroundStyle(Color.accentColor) }
                    Spacer()
                    Text(compactDuration(Int(session.duration / 60))).font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(Color.emberSecondary)
                }
                Text("\(session.start.timeShort)  –  \(session.end?.timeShort ?? "In progress")").font(.system(size: 9)).foregroundStyle(Color.emberMuted)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WeeklySummaryCard: View {
    @ObservedObject var store: StudyStore
    private var maxMinutes: Int { max(60, store.weekStudyMinutes.max() ?? 0) }
    var body: some View {
        EmberCard(padding: 17) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeading(title: "This week", subtitle: "A steady rhythm adds up")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(compactDuration(store.weekTotal)).font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit()).tracking(-0.8).foregroundStyle(Color.emberText)
                    Text("studied").font(.system(size: 10)).foregroundStyle(Color.emberMuted)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: store.weeklyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(Int(abs(store.weeklyChange) * 100))%")
                    }.font(.system(size: 9, weight: .semibold)).foregroundStyle(store.weeklyChange >= 0 ? Color.accentColor : Color.emberMuted)
                    Text("vs last week").font(.system(size: 8)).foregroundStyle(Color.emberMuted)
                }
                HStack(alignment: .bottom, spacing: 9) {
                    ForEach(Array(zip(store.weekDates, store.weekStudyMinutes).enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 5) {
                            Text(item.1 == 0 ? "–" : compactDuration(item.1)).font(.system(size: 8, weight: .medium)).foregroundStyle(Color.emberMuted).lineLimit(1).minimumScaleFactor(0.7)
                            GeometryReader { proxy in
                                VStack {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 3).fill(Calendar.current.isDateInToday(item.0) ? Color.accentColor : Color.accentColor.opacity(0.45))
                                        .frame(height: max(4, proxy.size.height * CGFloat(item.1) / CGFloat(maxMinutes)))
                                }
                            }.frame(height: 36)
                            Text(item.0.formatted(.dateTime.weekday(.narrow))).font(.system(size: 8, weight: Calendar.current.isDateInToday(item.0) ? .bold : .medium)).foregroundStyle(Calendar.current.isDateInToday(item.0) ? Color.accentColor : Color.emberMuted)
                        }.frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 14) {
                    HStack(spacing: 5) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor); Text("\(store.goalsReachedThisWeek) goals reached") }
                    HStack(spacing: 5) { Image(systemName: "chart.bar.fill").foregroundStyle(Color.emberMuted); Text("\(compactDuration(store.weekAverage)) daily avg") }
                }.font(.system(size: 9, weight: .medium)).foregroundStyle(Color.emberSecondary)
            }
        }
    }
}

struct StatisticsView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(title: "Your statistics", subtitle: "A thoughtful look at the time you’ve made.")
                HStack(spacing: 12) {
                    StatTile(title: "This week", value: compactDuration(store.weekTotal), note: "study time", icon: "clock.fill")
                    StatTile(title: "Daily average", value: compactDuration(store.weekAverage), note: "this week", icon: "chart.bar.fill")
                    StatTile(title: "Goals reached", value: "\(store.goalsReachedThisWeek) / \(store.elapsedDaysThisWeek)", note: "this week", icon: "checkmark.circle.fill")
                    StatTile(title: "Change", value: "\(store.weeklyChange >= 0 ? "+" : "−")\(Int(abs(store.weeklyChange) * 100))%", note: "vs last week", icon: "arrow.up.right")
                }
                WeeklySummaryCard(store: store)
                YearCalendarCard(store: store, selectedDay: .constant(nil))
                EmberCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CardHeading(title: "A week at a glance", subtitle: "Study time compared with each day’s goal")
                        ForEach(Array(zip(store.weekDates, store.weekStudyMinutes).enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 10) {
                                Text(item.0.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 9, weight: .medium)).foregroundStyle(Color.emberSecondary).frame(width: 29, alignment: .leading)
                                ProgressTrack(value: Double(item.1) / Double(max(store.goal(for: item.0), 1)), height: 6)
                                Text("\(compactDuration(item.1)) / \(compactDuration(store.goal(for: item.0)))").font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit()).foregroundStyle(Color.emberMuted).frame(width: 82, alignment: .trailing)
                            }
                        }
                    }
                }
            }.padding(.horizontal, 25).padding(.vertical, 23).frame(maxWidth: 850, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let note: String
    let icon: String
    var body: some View {
        EmberCard(padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor)
                Text(value).font(.system(size: 21, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(Color.emberText).lineLimit(1).minimumScaleFactor(0.7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.emberSecondary)
                    Text(note).font(.system(size: 9)).foregroundStyle(Color.emberMuted)
                }
            }
        }
    }
}
