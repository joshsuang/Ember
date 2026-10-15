import SwiftUI
import AppKit

extension Color {
    private static func adaptive(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
    static var emberBackground: Color { adaptive(dark: NSColor(srgbRed: 0.075, green: 0.080, blue: 0.087, alpha: 1), light: NSColor(srgbRed: 0.96, green: 0.96, blue: 0.95, alpha: 1)) }
    static var emberSurface: Color { adaptive(dark: NSColor(srgbRed: 0.105, green: 0.112, blue: 0.122, alpha: 1), light: NSColor(srgbRed: 1, green: 1, blue: 0.995, alpha: 1)) }
    static var emberRaised: Color { adaptive(dark: NSColor(srgbRed: 0.135, green: 0.143, blue: 0.153, alpha: 1), light: NSColor(srgbRed: 0.91, green: 0.92, blue: 0.93, alpha: 1)) }
    static var emberStroke: Color { adaptive(dark: NSColor.white.withAlphaComponent(0.075), light: NSColor.black.withAlphaComponent(0.09)) }
    static var emberMutedFill: Color { adaptive(dark: NSColor.white.withAlphaComponent(0.065), light: NSColor.black.withAlphaComponent(0.07)) }
    static var emberSoftFill: Color { adaptive(dark: NSColor.white.withAlphaComponent(0.05), light: NSColor.black.withAlphaComponent(0.045)) }
    static var emberRail: Color { adaptive(dark: NSColor(srgbRed: 0.09, green: 0.095, blue: 0.105, alpha: 1), light: NSColor(srgbRed: 0.985, green: 0.985, blue: 0.98, alpha: 1)) }
    static var emberTooltip: Color { adaptive(dark: NSColor(srgbRed: 0.16, green: 0.165, blue: 0.18, alpha: 1), light: NSColor(srgbRed: 0.18, green: 0.19, blue: 0.21, alpha: 1)) }
    static var emberMuted: Color { adaptive(dark: NSColor(srgbRed: 0.52, green: 0.55, blue: 0.59, alpha: 1), light: NSColor(srgbRed: 0.40, green: 0.43, blue: 0.47, alpha: 1)) }
    static var emberText: Color { adaptive(dark: NSColor(srgbRed: 0.93, green: 0.93, blue: 0.92, alpha: 1), light: NSColor(srgbRed: 0.14, green: 0.15, blue: 0.17, alpha: 1)) }
    static var emberSecondary: Color { adaptive(dark: NSColor(srgbRed: 0.69, green: 0.71, blue: 0.73, alpha: 1), light: NSColor(srgbRed: 0.34, green: 0.37, blue: 0.40, alpha: 1)) }
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
