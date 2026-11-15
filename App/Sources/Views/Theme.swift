import SwiftUI

// 見た目の決まり（app-quality-bar の look.md）。色・書体・角丸・余白・影はここだけで決める。
// トーンは StudyReel：淡いミントの 1 系統、細い線、セリフの見出しと数字。
// ピーチは「いまの電車」「遅れ」だけ（路線図の現在地に理由がある所）。
enum Theme {
    // 地と文字
    static let paper = Color(hex: 0xF4F8F7)
    static let ink = Color(hex: 0x24343A)
    static let sub = Color(hex: 0x86989B)
    static let line = Color(hex: 0xDCE6E4)

    // 主な色（ミント）の 5 段階：accent / soft / deep / card / 飾り
    static let accent = Color(hex: 0xA6D5CA)
    static let soft = Color(hex: 0xE2F1ED)
    static let deep = Color(hex: 0x4C8A7E)
    static let card = Color(hex: 0xFBFDFC)
    static let mist = Color(hex: 0xEEF4F3)

    // 電車（いまの位置）と遅れ
    static let train = Color(hex: 0xF2C7B4)
    static let trainSoft = Color(hex: 0xFBEAE2)
    static let late = Color(hex: 0xB9785F)

    // 書体：見出しと数字はセリフ、本文はサンセリフ
    /// 日本語はヒラギノ明朝、英語は New York（システムのセリフは日本語に明朝を当てないため、言語で分ける）
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if Lang.isJapanese {
            return .custom(weight == .regular ? "HiraMinProN-W3" : "HiraMinProN-W6", size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size) }

    // 角丸の段階
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 14
    static let radiusL: CGFloat = 20

    // 線
    static let hairline: CGFloat = 0.8
    static let rail: CGFloat = 3
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// 小さなラベル（字間を開ける）
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.sub
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10))
            .kerning(1.2)
            .foregroundStyle(color)
    }
}

/// 路線の記号（丸に M・Y・K）
struct LineMark: View {
    let mark: String
    var size: CGFloat = 26
    var filled = true
    var body: some View {
        ZStack {
            Circle().fill(filled ? Theme.deep : Theme.card)
            Circle().strokeBorder(Theme.deep, lineWidth: filled ? 0 : 1.2)
            Text(mark)
                .font(.system(size: size * 0.48, weight: .semibold, design: .rounded))
                .foregroundStyle(filled ? Theme.card : Theme.deep)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 押すと少し縮む（手応えの表：押す）
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 主なボタン（濃いミントに白い文字。高さ 54）
struct PrimaryButtonLabel: View {
    let title: String
    var subtitle: String? = nil
    var enabled = true
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            if let subtitle {
                Text(subtitle)
                    .font(Theme.label(11))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(enabled ? Theme.card : Theme.sub)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(enabled ? Theme.deep : Theme.mist))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(enabled ? .clear : Theme.line, lineWidth: Theme.hairline))
    }
}

/// 細い線のボタン
struct OutlineButtonLabel: View {
    let title: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 13)) }
            Text(title).font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(Theme.deep)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.accent, lineWidth: 1))
    }
}

/// 白い面（細い縁と弱い影）
struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).strokeBorder(Theme.line, lineWidth: Theme.hairline))
            .shadow(color: Theme.ink.opacity(0.05), radius: 10, y: 4)
    }
}

/// 画面の背景：ほぼ白の地に、線路の枕木のような細い横線を薄く
struct TrackBackground: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(Theme.line.opacity(0.45)))
                y += 28
            }
        }
        .background(Theme.paper)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// 時刻の書き方（15:00 / 3:00 PM）
enum Clock {
    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Lang.locale
        f.dateFormat = Lang.isJapanese ? "H:mm" : "h:mm a"
        return f.string(from: date)
    }

    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Lang.locale
        f.dateFormat = Lang.isJapanese ? "M月d日（E）" : "EEE, MMM d"
        return f.string(from: date)
    }

    static func mmss(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
