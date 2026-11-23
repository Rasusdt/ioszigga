import Foundation
import SwiftUI

/// Фон на весь экран: тёмно-синий полутоновый паттерн с голубым свечением
/// из правого нижнего угла — как в переработанном Android-дизайне.
struct ZiggaBackground: View {
    var body: some View {
        ZStack {
            Zig.background.ignoresSafeArea()
            HalftoneGlowBackground().ignoresSafeArea()

            // Мягкое затемнение сверху и снизу, чтобы текст и карточки читались.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.04),
                    Zig.background.opacity(0.60)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

/// Полутоновая сетка точек, яркость которой растёт к правому нижнему углу.
/// Рисуется кодом, поэтому остаётся резкой на любом экране и не весит мегабайты.
private struct HalftoneGlowBackground: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 1.02, y: size.height * 1.02)
            let radius = max(size.width, size.height) * 1.10

            let glow = Gradient(stops: [
                .init(color: Color(hex: 0x9CB6E4).opacity(0.40), location: 0),
                .init(color: Color(hex: 0x7690BE).opacity(0.16), location: 0.34),
                .init(color: Color.clear, location: 1)
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(glow, center: center, startRadius: 0, endRadius: radius)
            )

            let step: CGFloat = 7
            let rx = size.width * 1.25
            let ry = size.height * 0.92
            var y = step / 2
            while y < size.height {
                var x = step / 2
                while x < size.width {
                    let dx = Double((x - center.x) / rx)
                    let dy = Double((y - center.y) / ry)
                    let d = min(1.0, (dx * dx + dy * dy).squareRoot())
                    let f = pow(1.0 - d, 1.75)
                    let vertical = min(1.0, 0.45 + 0.55 * (1.0 - Double(y / size.height) * 0.35))
                    let alpha = (0.075 + 0.925 * f) * vertical
                    if alpha > 0.06 {
                        let r = CGFloat(0.9 + 0.95 * f)
                        let color = Color(
                            red: 0.25 + 0.62 * f,
                            green: 0.36 + 0.55 * f,
                            blue: 0.54 + 0.46 * f
                        ).opacity(alpha)
                        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                    x += step
                }
                y += step
            }
        }
        .drawingGroup()
    }
}

/// Аватар-ключ в круглой рамке с золото-неоновым ободком.
struct AvatarView: View {
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            Circle().fill(Zig.disc)
            if let image = UIImage(named: "AvatarZigga") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Zig.gold, Zig.neon],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .frame(width: size, height: size)
    }
}

struct StatusDot: View {
    var color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
    }
}

/// Большая круглая кнопка подключения.
struct PowerButtonView: View {
    enum Mode: Equatable {
        case off
        case connecting
        case on
    }

    var mode: Mode
    var action: () -> Void

    @State private var spinning = false

    private var accent: Color {
        switch mode {
        case .on: return Zig.neon
        case .connecting: return Zig.gold
        case .off: return Zig.offAccent
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Zig.disc)
                Circle().stroke(Zig.dimRing, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: mode == .on ? 0.999 : 0.25)
                    .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(mode == .off ? -90 : (spinning ? 270 : -90)))
                    .animation(
                        mode == .connecting
                            ? Animation.linear(duration: 1.2).repeatForever(autoreverses: false)
                            : Animation.easeInOut(duration: 0.25),
                        value: spinning
                    )
                Image(systemName: "power")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(accent)
            }
            .frame(width: 206, height: 206)
            .shadow(color: accent.opacity(mode == .off ? 0 : 0.35), radius: 26)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear { spinning = (mode == .connecting) }
        .onChange(of: mode) { newMode in
            spinning = (newMode == .connecting)
        }
    }
}

/// Зелёная «залитая» / прозрачная пилюля, как в Android.
struct ZigPillStyle: ButtonStyle {
    var filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(filled ? Color(hex: 0x131A07) : Zig.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(filled ? Zig.neon : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(filled ? Color.clear : Color.white.opacity(0.22), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Золотая нижняя кнопка «Нет кода? Получи 👇».
struct ZigGoldButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: 0x181405))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Zig.gold, Color(hex: 0xF6DC85), Zig.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Маленькая «пилюля» бота в шапке.
struct BotChip: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Наш бот")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Zig.neon)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Zig.neon.opacity(0.12))
                )
                .overlay(
                    Capsule().stroke(Zig.neon.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
