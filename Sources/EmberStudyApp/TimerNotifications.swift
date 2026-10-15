import Foundation
import AppKit
import UserNotifications

@MainActor
enum TimerNotifications {
    private static let timerRequestID = "ember.timer.completion"
    private static var permissionRequested = false

    static func scheduleCompletion(at date: Date, kind: SessionKind, mode: TimerMode, sound: Bool) {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = kind.isStudy ? "Focus session complete" : "Break is over"
        content.body = kind.isStudy ? "Lovely work. Your focus block is finished." : "Your break is over. Ready when you are."
        content.sound = sound ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: timerRequestID, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                requestPermissionIfNeeded()
                return
            }
            center.add(request) { _ in }
        }
    }

    static func postCompletion(kind: SessionKind, mode: TimerMode) {
        let content = UNMutableNotificationContent()
        content.title = kind.isStudy ? "Focus session complete" : "Break is over"
        content.body = kind.isStudy ? "Lovely work. Your focus block is finished." : "Your break is over. Ready when you are."
        let request = UNNotificationRequest(identifier: "ember.timer.finished.\(UUID().uuidString)", content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { requestPermissionIfNeeded(); return }
            center.add(request) { _ in }
        }
    }

    static func postGoalReached() {
        let content = UNMutableNotificationContent()
        content.title = "Daily study goal reached"
        content.body = "You made time for your learning today. Nicely done."
        let request = UNUserNotificationRequest(identifier: "ember.goal.\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)", content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { requestPermissionIfNeeded(); return }
            center.add(request) { _ in }
        }
    }

    static func cancelTimer() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [timerRequestID])
    }

    static func playCompletionSound() {
        NSSound(named: NSSound.Name("Glass"))?.play()
    }

    private static func requestPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
