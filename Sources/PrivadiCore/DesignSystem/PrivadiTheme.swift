import SwiftUI

public enum PrivadiTheme {
    public static let ink = Color(red: 0.12, green: 0.16, blue: 0.24)
    public static let mutedInk = Color(red: 0.48, green: 0.54, blue: 0.64)
    public static let faintInk = Color(red: 0.68, green: 0.72, blue: 0.80)

    public static let accent = Color(red: 0.35, green: 0.55, blue: 0.92)
    public static let accentLavender = Color(red: 0.73, green: 0.76, blue: 0.98)
    public static let accentBlush = Color(red: 0.96, green: 0.86, blue: 0.88)
    public static let accentMint = Color(red: 0.74, green: 0.91, blue: 0.84)
    public static let warning = Color(red: 0.94, green: 0.54, blue: 0.40)

    public static var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.99),
                    Color(red: 0.98, green: 0.98, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -160, y: -240)

            Circle()
                .fill(accentLavender.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 96)
                .offset(x: 150, y: 40)

            Circle()
                .fill(accentBlush.opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: 40, y: 320)

            Circle()
                .fill(accentMint.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -170, y: 460)
        }
    }

    public static func titleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    public static func valueFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }
}

public struct PrivadiGlassCardModifier: ViewModifier {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let alignment: Alignment

    public init(
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 22,
        alignment: Alignment = .leading
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.alignment = alignment
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background {
                ZStack {
                    shape.fill(Color.white.opacity(0.58))
                    shape.fill(.ultraThinMaterial)
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.36), Color.white.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.88), Color.white.opacity(0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: PrivadiTheme.accent.opacity(0.10), radius: 32, x: 0, y: 20)
            .shadow(color: Color.white.opacity(0.65), radius: 10, x: -6, y: -6)
    }
}

public struct PrivadiPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PrivadiTheme.ink, PrivadiTheme.ink.opacity(0.94)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: PrivadiTheme.ink.opacity(0.16), radius: 24, x: 0, y: 18)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

public struct PrivadiSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(PrivadiTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.76 : 0.64))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.78), lineWidth: 1)
            }
            .shadow(color: PrivadiTheme.accent.opacity(0.08), radius: 20, x: 0, y: 12)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

public struct PrivadiPillModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.58))
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.74), lineWidth: 1)
            }
            .shadow(color: PrivadiTheme.accent.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

public extension View {
    func privadiGlassCard(
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 22,
        alignment: Alignment = .leading
    ) -> some View {
        modifier(
            PrivadiGlassCardModifier(
                cornerRadius: cornerRadius,
                padding: padding,
                alignment: alignment
            )
        )
    }

    func privadiPill() -> some View {
        modifier(PrivadiPillModifier())
    }
}
