import StoreKit
import SwiftUI

// MARK: - 設定

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(tr("乗り方", "Riding")) {
                        toggle(tr("一駅ごとに区切る", "One stop per ride"),
                               tr("朝の便（4:00〜）と夕の便（15:00〜）に 1 駅ずつ。オフにすると続けて乗れます。", "One new stop in the morning (from 4:00) and one in the evening (from 15:00). Turn off to ride on."),
                               $model.pacing)
                    }
                    section(tr("音と振動", "Sound & haptics")) {
                        toggle(tr("効果音", "Sound effects"), tr("電車の中で鳴らないよう、最初はオフ。消音スイッチに従います。", "Off by default for quiet rides. Follows the silent switch."), $model.soundOn)
                        Divider().overlay(Theme.rule)
                        toggle(tr("振動", "Haptics"), nil, $model.hapticsOn)
                    }
                    section(tr("記録", "Records")) {
                        row(tr("解いた駅", "Stops solved"), "\(model.journey.totalSolved) / 30")
                        Divider().overlay(Theme.rule)
                        row(tr("定刻率", "On-time rate"), model.journey.onTimeRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        Divider().overlay(Theme.rule)
                        row(tr("つづけて乗った日", "Day streak"), "\(model.journey.streak(at: model.currentDate, calendar: model.calendar))")
                    }
                    section("Pro") {
                        if model.isPro {
                            Text(tr("Pro を使っています。ありがとうございます。", "You have Pro. Thank you!"))
                                .font(Theme.body(14))
                                .foregroundStyle(Theme.text)
                        } else {
                            Button { model.activeSheet = nil; Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)); model.activeSheet = .paywall(.settings) } } label: {
                                rowLabel(tr("Pro を見る", "See Pro"), systemImage: "chevron.right")
                            }
                        }
                        Divider().overlay(Theme.rule)
                        Button { Task { await model.purchases.restore() } } label: {
                            rowLabel(tr("購入を復元", "Restore purchase"), systemImage: "arrow.clockwise")
                        }
                    }
                    section(tr("そのほか", "More")) {
                        Button { model.replayOnboarding() } label: {
                            rowLabel(tr("使い方をもう一度見る", "Show the intro again"), systemImage: "play.circle")
                        }
                        Divider().overlay(Theme.rule)
                        Text(tr("通信しません。記録はこの iPhone の中だけに保存し、外に送りません。", "No network. Your records stay on this iPhone and are never sent anywhere."))
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .background(NightBackground())
            .toolbarBackground(Theme.night, for: .navigationBar)
            .navigationTitle(tr("設定", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("完了", "Done")) { model.activeSheet = nil }
                        .accessibilityIdentifier("main.closeSettings")
                }
            }
        }
        .tint(Theme.led)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title, color: Theme.led)
            Panel(padding: 14) {
                VStack(alignment: .leading, spacing: 12) { content() }
            }
        }
    }

    private func toggle(_ title: String, _ note: String?, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.gothic(15, .semibold)).foregroundStyle(Theme.text)
                if let note {
                    Text(note).font(Theme.body(12)).foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.line("M"))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(Theme.gothic(15, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            Text(verbatim: value).font(Theme.board(17, .heavy)).monospacedDigit().foregroundStyle(Theme.led)
                .shadow(color: Theme.glow, radius: 3)
        }
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Text(title).font(Theme.gothic(15, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
        }
        .frame(minHeight: 32)
        .contentShape(Rectangle())
    }
}

// MARK: - Pro

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    let reason: PaywallReason
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(text: "One Stop Riddles Pro", color: Theme.led)
                    Text(headline)
                        .font(Theme.gothic(28, .heavy))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("買い切り。一度買えば、家族も使えます。", "One-time purchase. Family Sharing included."))
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.dim)

                    // 全線の定期券：開く路線の見本（事件 2・3 の駅が鍵から開く）
                    PassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(model.cases.filter { $0.free < $0.stationCount }) { c in
                                linePreview(c)
                            }
                        }
                    }
                    feature("lightbulb", tr("ヒントの 3 段目", "The third hint"), tr("答えの手前まで導くヒント。どの駅でも使えます。", "A last nudge that takes you right to the edge of the answer, on every stop."))
                    feature("point.topleft.down.to.point.bottomright.curvepath", tr("事件 2・3 の残り 14 駅と終点", "14 more stops + 2 finales"), tr("「七番線の落とし物」「時刻表にない電車」を最後まで。", "Finish “Lost on Platform 7” and “The Train Not on the Timetable.”"))
                    feature("stopwatch", tr("最速の駅の記録", "Fastest-stop records"), tr("事件ごとの最速タイムを、終点の結果に残します。", "Your fastest time per case, shown at each terminus."))
                    Text(tr("値段は App Store の表示のとおり。通信なしで遊べ、広告もありません。", "Price as shown by the App Store. Plays offline, no ads."))
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.dim)
                    if let message {
                        Text(message).font(Theme.body(13, .medium)).foregroundStyle(Theme.late)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    Button { model.activeSheet = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(tr("閉じる", "Close"))
                    .accessibilityIdentifier("main.closePaywall")
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let product = model.purchases.products.first {
                        Button {
                            Task {
                                busy = true
                                let outcome = await model.purchases.purchase(product)
                                busy = false
                                switch outcome {
                                case .purchased: model.activeSheet = nil
                                case .pending: message = tr("承認を待っています。", "Waiting for approval.")
                                case .failed: message = tr("購入できませんでした。時間をおいてもう一度どうぞ。", "The purchase didn't go through. Please try again later.")
                                case .cancelled: break
                                }
                            }
                        } label: {
                            PrimaryButtonLabel(title: trf("Pro にする ― %@", "Get Pro ― %@", product.displayPrice),
                                               subtitle: tr("買い切り · 家族共有", "One-time · Family Sharing"))
                        }
                        .buttonStyle(PressStyle())
                        .disabled(busy)
                        .accessibilityIdentifier("main.buy")
                    } else {
                        PrimaryButtonLabel(title: model.purchases.loadState == .loading ? tr("読み込み中…", "Loading…") : tr("いまは購入できません", "Not available right now"),
                                           subtitle: tr("通信できる所で開き直してください", "Try again with a connection"),
                                           enabled: false)
                    }
                    Button(tr("購入を復元", "Restore purchase")) {
                        Task { await model.purchases.restore(); if model.isPro { model.activeSheet = nil } }
                    }
                    .font(Theme.gothic(13, .semibold))
                    .foregroundStyle(Theme.dim)
                    .frame(minHeight: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Theme.night.opacity(0.97).ignoresSafeArea())
            }
        }
        .task { if model.purchases.loadState == .idle { await model.purchases.load() } }
    }

    private var headline: String {
        switch reason {
        case .caseSolved: tr("事件 1、解決。次の路線へ。", "Case one, closed. On to the next line.")
        case .lockedStation: tr("この先の駅は、Pro で開きます。", "The next stops open with Pro.")
        case .hint: tr("最後のヒントは Pro で。", "The last hint comes with Pro.")
        case .settings: tr("ぜんぶの駅に乗る。", "Ride every stop.")
        }
    }

    private func linePreview(_ c: MysteryCase) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LineMark(mark: c.mark, size: 22)
                Text(c.text.line + " · " + c.text.title)
                    .font(Theme.gothic(14, .bold))
                    .foregroundStyle(Theme.signInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 0) {
                ForEach(0...c.stationCount, id: \.self) { i in
                    StationDot(state: i == c.stationCount ? .terminal(solved: false) : (i < c.free ? .onTime : .open), mark: c.mark, size: 12)
                    if i < c.stationCount {
                        Rectangle().fill(Theme.line(c.mark).opacity(i < c.free - 1 ? 1 : 0.45)).frame(height: 3)
                    }
                }
            }
            Text(trf("無料 %d 駅 → Pro で 10 駅＋終点", "%d free stops → all 10 + terminus with Pro", c.free))
                .font(Theme.label(10))
                .foregroundStyle(Theme.signSub)
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.led)
                .shadow(color: Theme.glow, radius: 4)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(Theme.board))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.gothic(15, .bold)).foregroundStyle(Theme.text)
                Text(detail).font(Theme.body(13)).foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 共有（ネタばれなし）

struct ShareView: View {
    @Environment(AppModel.self) private var model
    let caseID: String

    var body: some View {
        let c = Library.mysteryCase(caseID) ?? model.current
        let card = ShareCard(mysteryCase: c, journey: model.journey)
        ZStack {
            NightBackground()
            VStack(spacing: 18) {
                Eyebrow(text: tr("答えの見えない路線図", "A spoiler-free route map"), color: Theme.led)
                    .padding(.top, 4)
                card
                    .frame(width: 300, height: 400)
                    .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
                Text(tr("解いた駅と定刻の数だけ。謎の答えは載りません。", "Only your stops and on-time count—no answers."))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.dim)
                Spacer()
            }
            .padding(.horizontal, 20)
            // 閉じるは右上（小さい画面でも、カードの下に押し出されない）
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    Button { model.activeSheet = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(Theme.text)
                    .accessibilityLabel(tr("閉じる", "Close"))
                    .accessibilityIdentifier("main.closeShare")
                }
                .padding(.horizontal, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let image = render(card) {
                        ShareLink(item: image, preview: SharePreview(c.text.title, image: image)) {
                            PrimaryButtonLabel(title: tr("画像を共有", "Share image"))
                        }
                        .accessibilityIdentifier("main.shareImage")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    @MainActor
    private func render(_ card: ShareCard) -> Image? {
        let renderer = ImageRenderer(content: card.frame(width: 300, height: 400))
        renderer.scale = 3.6
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

struct ShareCard: View {
    let mysteryCase: MysteryCase
    let journey: Journey

    var body: some View {
        let c = mysteryCase
        let color = Theme.line(c.mark)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                LineMark(mark: c.mark, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.text.line).font(Theme.label(10)).kerning(1.2).foregroundStyle(color)
                    Text(c.text.title).font(Theme.gothic(19, .heavy)).foregroundStyle(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            // 横の路線図：定刻＝塗った丸、遅れ＝赤い点、まだ＝輪
            HStack(spacing: 0) {
                ForEach(0...c.stationCount, id: \.self) { i in
                    let state: StopState = i == c.stationCount ? .terminal(solved: journey.isCaseSolved(c))
                        : (journey.arrival(c.id, i).map { $0.isOnTime ? StopState.onTime : StopState.late } ?? StopState.open)
                    StationDot(state: state, mark: c.mark, size: 14)
                    if i < c.stationCount {
                        Rectangle().fill(journey.arrival(c.id, i) != nil ? color : color.opacity(0.25)).frame(height: 4)
                    }
                }
            }
            Spacer(minLength: 0)
            // 発車標の大きな数字
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(journey.solvedCount(c))")
                    .font(Theme.board(68, .heavy))
                    .kerning(-3)
                    .monospacedDigit()
                    .foregroundStyle(Theme.led)
                    .shadow(color: Theme.glow, radius: 8)
                Text(tr("/ 10 駅", "/ 10 STOPS"))
                    .font(Theme.board(15, .bold))
                    .foregroundStyle(Theme.dim)
            }
            HStack(spacing: 14) {
                Text(trf("定刻 %d", "%d ON TIME", journey.onTimeCount(c)))
                if journey.isCaseSolved(c) {
                    Text(tr("事件解決", "CASE CLOSED"))
                        .foregroundStyle(Theme.late)
                }
            }
            .font(Theme.label(11))
            .foregroundStyle(Theme.led)
            LineBand(mark: c.mark, height: 5)
            HStack {
                Text(tr("ひと駅なぞとき", "One Stop Riddles")).font(Theme.gothic(13, .heavy))
                Spacer()
                Text(tr("一駅で、ひとつの謎", "One stop, one riddle")).font(Theme.label(9))
            }
            .foregroundStyle(Theme.dim)
        }
        .padding(22)
        .background(
            ZStack {
                Theme.board
                // 右上に路線の色の線路の弧
                Canvas { ctx, size in
                    var p = Path()
                    p.move(to: CGPoint(x: size.width * 0.55, y: 0))
                    p.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.45), control: CGPoint(x: size.width * 0.75, y: size.height * 0.25))
                    ctx.stroke(p, with: .color(color.opacity(0.22)), lineWidth: 16)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1))
    }
}

/// 全線の定期券（Pro の見本）：駅名標と同じ白い板に、3 路線の色の帯
struct PassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["M", "Y", "K"], id: \.self) { m in
                    Rectangle().fill(Theme.line(m)).frame(height: 8)
                }
            }
            HStack {
                Text(tr("全線定期券", "ALL-LINE PASS"))
                    .font(Theme.gothic(13, .heavy))
                    .kerning(1.5)
                Spacer()
                Text(verbatim: "PRO")
                    .font(Theme.board(12, .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.signInk, lineWidth: 1.5))
            }
            .foregroundStyle(Theme.signInk)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            content
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sign)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .shadow(color: Theme.sign.opacity(0.12), radius: 16)
    }
}
