import Foundation
import UserNotifications
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import AudioToolbox
#endif

@MainActor
enum TimerNotifications {
    private static let timerRequestID = "ember.timer.completion"
    private static var permissionRequested = false
    static var onPermissionRequired: (() -> Void)?
    static var isEnabled = true

    private static func center() -> UNUserNotificationCenter? {
        guard isEnabled, Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }

    static func scheduleCompletion(at date: Date, kind: SessionKind, mode: TimerMode, sound: Bool) {
        guard date > Date() else { return }
        deliver(
            identifier: timerRequestID,
            title: kind.isStudy ? "Focus session complete" : "Break is over",
            body: kind.isStudy ? "Lovely work. Your focus block is finished." : "Your break is over. Ready when you are.",
            sound: sound,
            deliveryDate: date
        )
    }

    static func postCompletion(kind: SessionKind, mode: TimerMode) {
        deliver(
            identifier: "ember.timer.finished.\(UUID().uuidString)",
            title: kind.isStudy ? "Focus session complete" : "Break is over",
            body: kind.isStudy ? "Lovely work. Your focus block is finished." : "Your break is over. Ready when you are.",
            sound: false,
            deliveryDate: nil
        )
    }

    static func postGoalReached() {
        let dayKey = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        deliver(
            identifier: "ember.goal.\(dayKey)",
            title: "Daily study goal reached",
            body: "You made time for your learning today. Nicely done.",
            sound: false,
            deliveryDate: nil
        )
    }

    static func cancelTimer() {
        center()?.removePendingNotificationRequests(withIdentifiers: [timerRequestID])
    }

    static func playCompletionSound() {
        #if os(macOS)
        NSSound(named: NSSound.Name("Glass"))?.play()
        #elseif os(iOS)
        AudioServicesPlaySystemSound(1007)
        #endif
    }

    static func requestPermission() {
        guard !permissionRequested else { return }
        permissionRequested = true
        center()?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func deliver(identifier: String, title: String, body: String, sound: Bool, deliveryDate: Date?) {
        guard let center = center() else { return }
        center.getNotificationSettings { settings in
            let authorization = settings.authorizationStatus
            Task { @MainActor in
                guard authorization == .authorized || authorization == .provisional else {
                    onPermissionRequired?()
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = sound ? .default : nil
                let trigger: UNNotificationTrigger? = deliveryDate.map {
                    UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0.timeIntervalSinceNow), repeats: false)
                }
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                do { try await UNUserNotificationCenter.current().add(request) }
                catch { /* Timer completion remains independent of notification delivery. */ }
            }
        }
    }
}
