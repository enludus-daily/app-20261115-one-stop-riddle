import SwiftUI

// 見た目の決まり（app-quality-bar の look.md）。色・書体・角丸・余白・影はここだけで決める。
// 世界：夜の地下鉄の駅とミステリー（2026-11-16 作り直し）。
// - 地は夜のホームの暗い紺（画面はダークに固定。発車標の光と駅名標の明かりが主役のため）
// - 主の色は路線の色（事件ごとに 1 色：M 青・Y 紅・K 緑）。帯・線路・駅ナンバリング・発車標の光る文字・主なボタンの帯
//   画面の中では \.lineMark（いまの事件の路線）から引く。黄色・アンバーは使わない（2026-11-16 監督のレビュー：
//   しゃがんで建てる の黄と黒に見えるため）
// - 主なボタンは駅の案内板：白い板に路線の色の帯
// - 手がかり・物語・真相は「事件の資料」のクラフト紙の紙片（file の段階）
// - 遅れ・まちがいは小さな赤い点だけ（late）
enum Theme {
    // 地（夜のホーム）：暗い順に
    static let night = Color(hex: 0x0A0F14)      // 画面の地
    static let tunnel = Color(hex: 0x131B23)     // 面（設定の面・選択肢）
    static let platform = Color(hex: 0x1C2630)   // 一段上の面・押せない面
    static let rule = Color(hex: 0x2A3743)       // 線
    static let text = Color(hex: 0xECF0F3)       // 文字（真っ白にしない）
    static let dim = Color(hex: 0x8B9AA7)        // 補助の文字

    // 発車標の黒い地（文字は路線の色で光らせる）
    static let board = Color(hex: 0x05080A)

    // 駅名標（裏から照らされた白い板）
    static let sign = Color(hex: 0xF3F5F6)
    static let signInk = Color(hex: 0x111820)
    static let signSub = Color(hex: 0x6B7782)

    // 事件の資料（クラフト紙の紙片）
    static let file = Color(hex: 0xECE2CB)
    static let fileInk = Color(hex: 0x2A251D)
    static let fileSub = Color(hex: 0x786D5A)
    static let fileRule = Color(hex: 0xD3C6A8)
    static let clip = Color(hex: 0xB9C2CA)

    // 遅れ・まちがい（小さな点と文字だけ）
    static let late = Color(hex: 0xFF6A5C)

    /// 路線の色（事件ごと）。主の色。帯・線路・駅ナンバリング・光る文字・ボタンの帯に使う
    static func line(_ mark: String) -> Color {
        switch mark {
        case "Y": Color(hex: 0xE5578A)   // ゆうなぎ線：夕なぎの紅
        case "K": Color(hex: 0x34BF8C)   // きりさめ線：霧の緑
        default: Color(hex: 0x2F9DE2)    // みなと線：港の青
        }
    }

    // 書体：見出しは駅の案内表示のような太いゴシック、数字と札は発車標の等幅、本文はふつうのゴシック
    /// 日本語はヒラギノ角ゴ（W6・W8）、英語は SF の縦長（condensed）
    static func gothic(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        if Lang.isJapanese {
            let name = weight == .heavy || weight == .black ? "HiraginoSans-W8" : (weight == .bold ? "HiraginoSans-W7" : "HiraginoSans-W6")
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight).width(.condensed)
    }
    /// 発車標の文字（等幅・太い）
    static func board(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// 小さなラベル（等幅、字間を開ける）
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func body(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }

    // 角丸の段階（駅の設備は角ばっている）
    /// 路線の色の 5 段階：accent（路線の色）/ soft（暗い地の上の淡い面）/ deep（白い板の上の文字）/ 地 / 飾り（にじみ）
    static func glow(_ mark: String) -> Color { line(mark).opacity(0.45) }
    static func lineSoft(_ mark: String) -> Color { line(mark).opacity(0.18) }

    static let radiusS: CGFloat = 4
    static let radiusM: CGFloat = 10
    static let radiusL: CGFloat = 14

    // 線
    static let hairline: CGFloat = 1
    static let rail: CGFloat = 6
}

extension EnvironmentValues {
    /// いまの画面の事件の路線（M・Y・K）。主の色はここから決まる
    @Entry var lineMark: String = "M"
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// 小さなラベル（等幅・字間を開ける。発車標の欄の見出し）
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.dim
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10))
            .kerning(1.6)
            .foregroundStyle(color)
    }
}

/// 駅ナンバリングの記号：白い丸に路線の色の太い輪、中に路線の記号（と駅の番号）
struct LineMark: View {
    let mark: String
    var number: Int? = nil
    var size: CGFloat = 26
    var dimmed = false
    var body: some View {
        let color = Theme.line(mark)
        ZStack {
            Circle().fill(Theme.sign)
            Circle().strokeBorder(dimmed ? Theme.dim : color, lineWidth: max(2.5, size * 0.13))
            VStack(spacing: -size * 0.06) {
                Text(mark)
                    .font(.system(size: size * (number == nil ? 0.46 : 0.32), weight: .heavy))
                if let number {
                    Text(String(format: "%02d", number))
                        .font(.system(size: size * 0.3, weight: .heavy))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(Theme.signInk)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 押すと少し沈む（手応えの表：押す）
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1.5 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 主なボタン：駅の案内板。白い板に、左に路線の色の帯と右に矢印。下辺だけ厚い（押しボタンの厚み）
struct PrimaryButtonLabel: View {
    @Environment(\.lineMark) private var lineMark
    let title: String
    var subtitle: String? = nil
    var enabled = true
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
        let color = Theme.line(lineMark)
        HStack(spacing: 0) {
            Color.clear.frame(width: 10, height: 1)
            VStack(spacing: 2) {
                Text(title)
                    .font(Theme.gothic(16, .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.body(11, .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(enabled ? Theme.signSub : Theme.dim)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 11))
                .foregroundStyle(enabled ? color : .clear)
                .padding(.trailing, 14)
        }
        .foregroundStyle(enabled ? Theme.signInk : Theme.dim)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            ZStack {
                shape.fill(enabled ? Color(hex: 0x9AA5AE) : Theme.platform).offset(y: 3)
                shape.fill(enabled ? Theme.sign : Theme.platform)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(enabled ? color : Theme.rule).frame(width: 10)
                    }
                    .clipShape(shape)
            }
        )
        .overlay(shape.strokeBorder(enabled ? .clear : Theme.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .shadow(color: enabled ? Theme.sign.opacity(0.12) : .clear, radius: 14, y: 2)
        .padding(.bottom, 3)
    }
}

/// 線のボタン（暗い面に細い線）
struct OutlineButtonLabel: View {
    let title: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
            Text(title).font(Theme.gothic(14, .semibold))
        }
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.tunnel))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1))
    }
}

/// 暗い面（設定・一覧）
struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).fill(Theme.tunnel))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).strokeBorder(Theme.rule, lineWidth: Theme.hairline))
    }
}

/// 画面の背景：夜のホームの壁。暗い紺の地に、地下鉄のタイル目地をごく薄く。上だけ少し明るい（天井の照明）
struct NightBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let w: CGFloat = 44, h: CGFloat = 22
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                let fade = max(0.0, 1 - Double(y / max(1, size.height)) * 1.4)
                let color = Theme.rule.opacity(0.22 * fade + 0.04)
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.6)), with: .color(color))
                var x: CGFloat = row % 2 == 0 ? 0 : -w / 2
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: y, width: 0.6, height: h)), with: .color(color))
                    x += w
                }
                y += h
                row += 1
            }
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x16212B), Theme.night, Theme.night],
                           startPoint: .top, endPoint: .bottom)
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// 路線の色の帯（駅の壁に引かれた帯。上下に細い白い縁）
struct LineBand: View {
    let mark: String
    var height: CGFloat = 8
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.sign.opacity(0.85)).frame(height: 1)
            Rectangle().fill(Theme.line(mark)).frame(height: height)
            Rectangle().fill(Theme.sign.opacity(0.85)).frame(height: 1)
        }
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
