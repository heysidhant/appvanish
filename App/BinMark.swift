import SwiftUI

extension Color {
    // Taken from the app icon. Slightly deeper than the icon so white text stays readable.
    static let vanishTop = Color(red: 0.055, green: 0.451, blue: 0.918)
    static let vanishMiddle = Color(red: 0.169, green: 0.333, blue: 0.933)
    static let vanishBottom = Color(red: 0.353, green: 0.184, blue: 0.878)
    static let vanishInk = Color(red: 0.071, green: 0.133, blue: 0.310)
    static let vanishYellow = Color(red: 1.000, green: 0.776, blue: 0.180)
    static let vanishOrange = Color(red: 1.000, green: 0.604, blue: 0.122)
    static let vanishRib = Color(red: 0.369, green: 0.553, blue: 0.969)
    static let vanishBinShade = Color(red: 0.851, green: 0.894, blue: 1.000)
    static let vanishOnBlue = Color.white
    static let vanishOnBlueSoft = Color.white.opacity(0.9)
}

extension ShapeStyle where Self == LinearGradient {
    static var vanishBackground: LinearGradient {
        LinearGradient(
            colors: [.vanishTop, .vanishMiddle, .vanishBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var vanishApp: LinearGradient {
        LinearGradient(colors: [.vanishYellow, .vanishOrange], startPoint: .top, endPoint: .bottom)
    }
}

struct BinBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset = rect.width * 0.06
        let bottomInset = rect.width * 0.16
        let radius = min(10, rect.width * 0.06)
        path.move(to: CGPoint(x: rect.minX + topInset + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topInset, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX - topInset, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomInset - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomInset + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX + bottomInset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topInset, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topInset + radius, y: rect.minY),
            control: CGPoint(x: rect.minX + topInset, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: c.y), control: c)
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.maxY), control: c)
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: c.y), control: c)
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.minY), control: c)
        path.closeSubpath()
        return path
    }
}

/// The yellow app from the icon: a rounded tile with four white squares.
struct AppTileMark: View {
    var size: CGFloat

    var body: some View {
        let dot = size * 0.2
        let gap = size * 0.1
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(.vanishApp)
            VStack(spacing: gap) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: gap) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: dot * 0.3, style: .continuous)
                                .fill(Color.white.opacity(0.95))
                                .frame(width: dot, height: dot)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// The icon's bin. With `showsApp`, the lid rests slightly open with the app and sparkle above it.
struct BinMark: View {
    var lidOpen: Bool
    var size: CGFloat = 148
    var showsApp = false

    var body: some View {
        let bodyWidth = size * 0.60
        let bodyHeight = size * 0.62
        let lidWidth = size * 0.74
        let lidHeight = max(4, size * 0.07)
        let handleWidth = lidWidth * 0.3
        let handleHeight = lidHeight * 0.85
        let restAngle: Double = showsApp ? -11 : 0

        VStack(spacing: size * 0.02) {
            VStack(spacing: -handleHeight * 0.1) {
                Capsule()
                    .fill(Color.white)
                    .frame(width: handleWidth, height: handleHeight)
                RoundedRectangle(cornerRadius: lidHeight / 2, style: .continuous)
                    .fill(Color.white)
                    .frame(width: lidWidth, height: lidHeight)
            }
            .rotationEffect(.degrees(lidOpen ? -30 : restAngle), anchor: .bottomLeading)
            .animation(.spring(response: 0.42, dampingFraction: 0.68), value: lidOpen)

            ZStack {
                BinBody()
                    .fill(LinearGradient(colors: [.vanishBinShade, .white], startPoint: .top, endPoint: .bottom))
                HStack(spacing: bodyWidth * 0.16) {
                    rib(height: bodyHeight, tilt: 3)
                    rib(height: bodyHeight, tilt: 0)
                    rib(height: bodyHeight, tilt: -3)
                }
            }
            .frame(width: bodyWidth, height: bodyHeight)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if showsApp {
                AppTileMark(size: size * 0.27)
                    .rotationEffect(.degrees(14))
                    .offset(x: -size * 0.06, y: -size * 0.24)
            }
        }
        .overlay(alignment: .topLeading) {
            if showsApp {
                Sparkle()
                    .fill(Color.white)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .offset(x: size * 0.14, y: -size * 0.17)
            }
        }
        .accessibilityHidden(true)
    }

    private func rib(height: CGFloat, tilt: Double) -> some View {
        Capsule()
            .fill(Color.vanishRib)
            .frame(width: max(2, size * 0.04), height: height * 0.66)
            .rotationEffect(.degrees(tilt))
    }
}

struct VanishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    private struct Styled: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vanishInk)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(.vanishApp))
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
        }
    }
}

struct BinToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.vanishInk.opacity(configuration.isOn ? 0 : 0.35), lineWidth: 1.5)
                    if configuration.isOn {
                        Circle().fill(.vanishApp)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.vanishInk)
                    }
                }
                .frame(width: 18, height: 18)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isOn)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
