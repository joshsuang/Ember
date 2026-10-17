import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StudyStore
    @ObservedObject var engine: TimerEngine
    @State private var confirmReset = false
    @State private var showNotificationExplanation = false
    private let weekdays = [(2, "Monday"), (3, "Tuesday"), (4, "Wednesday"), (5, "Thursday"), (6, "Friday"), (7, "Saturday"), (1, "Sunday")]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionTitle(title: "Settings", subtitle: "A study routine that fits your life.")
                settingsSection("STUDY GOALS", description: "Choose a different daily target for every day.") {
                    VStack(spacing: 0) {
                        ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(day.1).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberText)
                                    Text("\(store.data.settings.goal(for: dateForWeekday(day.0))) minutes")
                                        .font(.system(size: 9)).foregroundStyle(Color.emberMuted)
                                }
                                Spacer()
                                GoalEditor(minutes: goalBinding(weekday: day.0))
                            }.padding(.vertical, 9)
                            if index < weekdays.count - 1 { Divider().overlay(Color.emberStroke) }
                        }
                    }
                }
                settingsSection("POMODORO", description: "Shape your focus-and-rest cycles.") {
                    VStack(spacing: 0) {
                        SettingsStepperRow(title: "Focus duration", subtitle: "Length of each focus session", value: intBinding(\.focusMinutes), range: 1...180, unit: "min")
                        Divider().overlay(Color.emberStroke)
                        SettingsStepperRow(title: "Short break", subtitle: "A quick breather between sessions", value: intBinding(\.shortBreakMinutes), range: 1...60, unit: "min")
                        Divider().overlay(Color.emberStroke)
                        SettingsStepperRow(title: "Long break", subtitle: "A longer rest after a few cycles", value: intBinding(\.longBreakMinutes), range: 1...90, unit: "min")
                        Divider().overlay(Color.emberStroke)
                        SettingsStepperRow(title: "Focus sessions before a long break", subtitle: "Number of focus blocks", value: intBinding(\.sessionsBeforeLongBreak), range: 2...8, unit: "sessions")
                    }
                }
                settingsSection("APPEARANCE", description: "Comfortable, whatever the light.") {
                    VStack(spacing: 13) {
                        HStack(spacing: 8) {
                            ForEach(AppearanceChoice.allCases) { choice in
                                Button { store.data.settings.appearance = choice } label: {
                                    HStack(spacing: 6) { Image(systemName: choice == .dark ? "moon.fill" : choice == .light ? "sun.max.fill" : "circle.lefthalf.filled"); Text(choice.rawValue) }
                                        .font(.system(size: 10, weight: store.data.settings.appearance == choice ? .semibold : .medium))
                                        .foregroundStyle(store.data.settings.appearance == choice ? Color.accentColor : Color.emberSecondary)
                                        .padding(.horizontal, 11).padding(.vertical, 8)
                                        .background(store.data.settings.appearance == choice ? Color.accentColor.opacity(0.12) : Color.emberSoftFill, in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.data.settings.appearance == choice ? Color.accentColor.opacity(0.3) : Color.emberStroke, lineWidth: 1))
                                }.buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        HStack {
                            Text("Accent color").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.emberSecondary)
                            Spacer()
                            ForEach(AccentChoice.allCases) { accent in
                                Button { store.data.settings.accent = accent } label: {
                                    Circle().fill(accent.color).frame(width: 17, height: 17).padding(3)
                                        .overlay(Circle().stroke(store.data.settings.accent == accent ? accent.color : Color.clear, lineWidth: 1)).padding(.horizontal, 2)
                                }.buttonStyle(.plain).help(accent.rawValue)
                            }
                        }
                    }
                }
                settingsSection("SOUND & NOTIFICATIONS", description: "Gentle nudges, only when you want them.") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Timer completion sound", subtitle: "A soft cue when a timer finishes", isOn: boolBinding(\.completionSound))
                        Divider().overlay(Color.emberStroke)
                        SettingsToggleRow(title: "Break reminders", subtitle: "A nudge to rest between focus blocks", isOn: notificationBinding(\.breakReminders))
                        Divider().overlay(Color.emberStroke)
                        SettingsToggleRow(title: "Study goal notifications", subtitle: "A little celebration when you reach your goal", isOn: notificationBinding(\.goalNotifications))
                    }
                }
                settingsSection("GENERAL", description: "Small details for your daily flow.") {
                    VStack(spacing: 0) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Quick-start durations").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberText)
                                Text("Up to three timer shortcuts").font(.system(size: 9)).foregroundStyle(Color.emberMuted)
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                ForEach(0..<3, id: \.self) { index in
                                    let value = index < store.data.settings.quickDurations.count ? store.data.settings.quickDurations[index] : 0
                                    Menu {
                                        ForEach([10, 15, 20, 25, 30, 45, 50, 60, 90, 120], id: \.self) { minutes in
                                            Button("\(minutes) minutes") { setQuick(index: index, minutes: minutes) }
                                        }
                                    } label: {
                                        Text(value == 0 ? "+ Add" : "\(value)m").font(.system(size: 9, weight: .semibold)).foregroundStyle(value == 0 ? Color.accentColor : Color.emberSecondary)
                                            .padding(.horizontal, 8).padding(.vertical, 6).background(Color.emberSoftFill, in: RoundedRectangle(cornerRadius: 6))
                                    }
                                    #if os(macOS)
                                    .menuStyle(.borderlessButton)
                                    #endif
                                }
                            }
                        }.padding(.vertical, 10)
                        Divider().overlay(Color.emberStroke)
                        SettingsToggleRow(title: "Keep timer in a compact floating window", subtitle: "Floating timer windows are not available yet", isOn: boolBinding(\.compactTimer), disabled: true)
                        Divider().overlay(Color.emberStroke)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("iCloud sync")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberText)
                                Text(store.cloudSyncStatus.title)
                                    .font(.system(size: 9)).foregroundStyle(Color.emberMuted)
                            }
                            Spacer()
                            Button("Sync now") { store.syncNow() }
                                .buttonStyle(EmberButtonStyle(compact: true))
                        }.padding(.vertical, 10)
                        Divider().overlay(Color.emberStroke)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Clear study data").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberText)
                                Text("Remove saved sessions and restore default preferences.").font(.system(size: 9)).foregroundStyle(Color.emberMuted)
                            }
                            Spacer()
                            Button("Clear data") { confirmReset = true }
                                .buttonStyle(EmberButtonStyle(compact: true))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .confirmationDialog("Clear your Ember data?", isPresented: $confirmReset, titleVisibility: .visible) {
                                    Button("Clear all study data", role: .destructive) { engine.resetUserData() }
                                    Button("Cancel", role: .cancel) {}
                                } message: { Text("This permanently removes your locally saved sessions and preferences. This cannot be undone.") }
                        }.padding(.vertical, 10)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.cloudSyncMessage ?? cloudSyncDescription)
                        .font(.system(size: 9)).foregroundStyle(Color.emberMuted).fixedSize(horizontal: false, vertical: true)
                    if let error = store.persistenceError {
                        Label("Local save problem: \(error)", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9)).foregroundStyle(Color.orange).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(.horizontal, 2).padding(.top, 2)
            }
            .padding(.horizontal, 25).padding(.vertical, 23).frame(maxWidth: 710, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("Allow Ember notifications?", isPresented: $showNotificationExplanation) {
            Button("Enable notifications") { TimerNotifications.requestPermission() }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Ember can show a local reminder when a timer or daily study goal finishes. Notifications are optional; timers work without them.")
        }
    }

    private var cloudSyncDescription: String {
        switch store.cloudSyncStatus {
        case .waiting: "Study data is saved on this device. Turn on iCloud to sync with your other devices."
        case .syncing: "Study data is saved locally and syncing through your private iCloud account."
        case .synced: "Study data is saved locally and synced through your private iCloud account."
        case .unavailable: "Study data is saved locally. iCloud sync is currently unavailable."
        }
    }

    @ViewBuilder private func settingsSection<Content: View>(_ title: String, description: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Color.accentColor)
                Text(description).font(.system(size: 10)).foregroundStyle(Color.emberMuted)
            }.padding(.horizontal, 2)
            EmberCard(padding: 13) { content() }
        }
    }
    private func goalBinding(weekday: Int) -> Binding<Int> {
        Binding(get: { store.data.settings.weekdayGoals[weekday] ?? 60 }, set: { store.data.settings.weekdayGoals[weekday] = min(1440, max(0, $0)) })
    }
    private func intBinding(_ keyPath: WritableKeyPath<StudySettings, Int>) -> Binding<Int> {
        Binding(get: { store.data.settings[keyPath: keyPath] }, set: { store.data.settings[keyPath: keyPath] = $0 })
    }
    private func boolBinding(_ keyPath: WritableKeyPath<StudySettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.data.settings[keyPath: keyPath] }, set: { store.data.settings[keyPath: keyPath] = $0 })
    }
    private func notificationBinding(_ keyPath: WritableKeyPath<StudySettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.data.settings[keyPath: keyPath] }, set: { enabled in
            store.data.settings[keyPath: keyPath] = enabled
            if enabled { showNotificationExplanation = true }
        })
    }
    private func setQuick(index: Int, minutes: Int) {
        var values = store.data.settings.quickDurations
        if index < values.count { values[index] = minutes } else { values.append(minutes) }
        store.data.settings.quickDurations = Array(values.prefix(3))
    }
    private func dateForWeekday(_ weekday: Int) -> Date {
        Calendar.current.nextDate(after: Date(), matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime) ?? Date()
    }
}

struct GoalEditor: View {
    @Binding var minutes: Int
    @State private var hours = 0
    @State private var remainder = 0
    var body: some View {
        HStack(spacing: 4) {
            TextField("0", value: $hours, format: .number).frame(width: 31).textFieldStyle(.plain).multilineTextAlignment(.trailing).onChange(of: hours) { _, _ in update() }
            Text("h").font(.system(size: 9)).foregroundStyle(Color.emberMuted)
            TextField("0", value: $remainder, format: .number).frame(width: 31).textFieldStyle(.plain).multilineTextAlignment(.trailing).onChange(of: remainder) { _, _ in update() }
            Text("m").font(.system(size: 9)).foregroundStyle(Color.emberMuted)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit()).foregroundStyle(Color.emberText)
        .padding(.horizontal, 8).padding(.vertical, 6).background(Color.emberSoftFill, in: RoundedRectangle(cornerRadius: 7))
        .onAppear { sync() }.onChange(of: minutes) { _, _ in sync() }
    }
    private func update() { minutes = min(1440, max(0, hours) * 60 + min(59, max(0, remainder))) }
    private func sync() { hours = minutes / 60; remainder = minutes % 60 }
}

struct SettingsStepperRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberText)
                Text(subtitle).font(.system(size: 9)).foregroundStyle(Color.emberMuted)
            }
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value) \(unit)").font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(Color.emberSecondary).frame(minWidth: 64, alignment: .trailing)
            }.controlSize(.small).fixedSize()
        }.padding(.vertical, 8)
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var disabled = false
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(disabled ? Color.emberMuted : Color.emberText)
                Text(subtitle).font(.system(size: 9)).foregroundStyle(Color.emberMuted)
            }
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini).disabled(disabled)
        }.padding(.vertical, 8)
    }
}

struct SettingValueRow: View {
    let title: String
    let subtitle: String
    let value: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.emberText)
                Text(subtitle).font(.system(size: 9)).foregroundStyle(Color.emberMuted)
            }
            Spacer()
            Text(value).font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(Color.emberSecondary)
        }.padding(.vertical, 10)
    }
}
