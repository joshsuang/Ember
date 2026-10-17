import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

extension Color {
    #if os(macOS)
    private static func adaptive(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
    #elseif os(iOS)
    private static func adaptive(dark: UIColor, light: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif

    static var emberBackground: Color { adaptive(dark: rgb(0.075, 0.080, 0.087), light: rgb(0.96, 0.96, 0.95)) }
    static var emberSurface: Color { adaptive(dark: rgb(0.105, 0.112, 0.122), light: rgb(1, 1, 0.995)) }
    static var emberRaised: Color { adaptive(dark: rgb(0.135, 0.143, 0.153), light: rgb(0.91, 0.92, 0.93)) }
    static var emberStroke: Color { adaptive(dark: rgb(1, 1, 1, 0.075), light: rgb(0, 0, 0, 0.09)) }
    static var emberMutedFill: Color { adaptive(dark: rgb(1, 1, 1, 0.065), light: rgb(0, 0, 0, 0.07)) }
    static var emberSoftFill: Color { adaptive(dark: rgb(1, 1, 1, 0.05), light: rgb(0, 0, 0, 0.045)) }
    static var emberRail: Color { adaptive(dark: rgb(0.09, 0.095, 0.105), light: rgb(0.985, 0.985, 0.98)) }
    static var emberTooltip: Color { adaptive(dark: rgb(0.16, 0.165, 0.18), light: rgb(0.18, 0.19, 0.21)) }
    static var emberMuted: Color { adaptive(dark: rgb(0.52, 0.55, 0.59), light: rgb(0.40, 0.43, 0.47)) }
    static var emberText: Color { adaptive(dark: rgb(0.93, 0.93, 0.92), light: rgb(0.14, 0.15, 0.17)) }
    static var emberSecondary: Color { adaptive(dark: rgb(0.69, 0.71, 0.73), light: rgb(0.34, 0.37, 0.40)) }
}

struct EmberCard<Content: View>: View {
    var padding: CGFloat = 18
    var content: Content
    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.emberSurface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.emberStroke, lineWidth: 1))
    }
}

struct CardHeading: View {
    let title: String
    var subtitle: String? = nil
    var accessory: AnyView? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.emberText)
                if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.emberMuted) }
            }
            Spacer(minLength: 8)
            if let accessory { accessory }
        }
    }
}

struct EmberButtonStyle: ButtonStyle {
    var prominent = false
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 11 : 12, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Color.emberSecondary)
            .padding(.horizontal, compact ? 11 : 14)
            .padding(.vertical, compact ? 7 : 9)
            .background(prominent ? Color.accentColor.opacity(configuration.isPressed ? 0.78 : 1) : (configuration.isPressed ? Color.primary.opacity(0.12) : Color.emberSoftFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(prominent ? Color.clear : Color.emberStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct MetricLabel: View {
    let title: String
    let value: String
    var tint: Color = .emberText
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(Color.emberMuted)
            Text(value).font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(tint)
        }
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 22, weight: .semibold, design: .rounded)).tracking(-0.45).foregroundStyle(Color.emberText)
            if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.emberMuted) }
        }
    }
}

struct ProgressTrack: View {
    var value: Double
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.emberStroke)
                Capsule().fill(Color.accentColor).frame(width: max(height, proxy.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: value)
    }
}

extension Date {
    var timeShort: String { formatted(.dateTime.hour().minute()) }
    var dateLong: String { formatted(.dateTime.weekday(.wide).month(.wide).day()) }
}
