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
                        Divider().overlay(Theme.line)
                        toggle(tr("振動", "Haptics"), nil, $model.hapticsOn)
                    }
                    section(tr("記録", "Records")) {
                        row(tr("解いた駅", "Stops solved"), "\(model.journey.totalSolved) / 30")
                        Divider().overlay(Theme.line)
                        row(tr("定刻率", "On-time rate"), model.journey.onTimeRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        Divider().overlay(Theme.line)
                        row(tr("つづけて乗った日", "Day streak"), "\(model.journey.streak(at: model.currentDate, calendar: model.calendar))")
                    }
                    section("Pro") {
                        if model.isPro {
                            Text(tr("Pro を使っています。ありがとうございます。", "You have Pro. Thank you!"))
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.ink)
                        } else {
                            Button { model.activeSheet = nil; Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)); model.activeSheet = .paywall(.settings) } } label: {
                                rowLabel(tr("Pro を見る", "See Pro"), systemImage: "chevron.right")
                            }
                        }
                        Divider().overlay(Theme.line)
                        Button { Task { await model.purchases.restore() } } label: {
                            rowLabel(tr("購入を復元", "Restore purchase"), systemImage: "arrow.clockwise")
                        }
                    }
                    section(tr("そのほか", "More")) {
                        Button { model.replayOnboarding() } label: {
                            rowLabel(tr("使い方をもう一度見る", "Show the intro again"), systemImage: "play.circle")
                        }
                        Divider().overlay(Theme.line)
                        Text(tr("通信しません。記録はこの iPhone の中だけに保存し、外に送りません。", "No network. Your records stay on this iPhone and are never sent anywhere."))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .background(Theme.paper)
            .navigationTitle(tr("設定", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("完了", "Done")) { model.activeSheet = nil }
                        .accessibilityIdentifier("main.closeSettings")
                }
            }
        }
        .tint(Theme.deep)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title)
            Panel(padding: 14) {
                VStack(alignment: .leading, spacing: 12) { content() }
            }
        }
    }

    private func toggle(_ title: String, _ note: String?, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15)).foregroundStyle(Theme.ink)
                if let note {
                    Text(note).font(.system(size: 12)).foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.deep)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 15)).foregroundStyle(Theme.ink)
            Spacer()
            Text(verbatim: value).font(Theme.serif(17)).monospacedDigit().foregroundStyle(Theme.ink)
        }
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Text(title).font(.system(size: 15)).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: systemImage).font(.system(size: 13)).foregroundStyle(Theme.sub)
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
            TrackBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(text: "One Stop Riddles Pro", color: Theme.deep)
                    Text(headline)
                        .font(Theme.serif(26, .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("買い切り。一度買えば、家族も使えます。", "One-time purchase. Family Sharing included."))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)

                    // 開く路線の見本（事件 2・3 の駅が鍵から開く）
                    Panel {
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
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                    if let message {
                        Text(message).font(.system(size: 13)).foregroundStyle(Theme.late)
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
                .foregroundStyle(Theme.deep)
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
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.deep)
                    .frame(minHeight: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Theme.paper.opacity(0.96).ignoresSafeArea())
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
                LineMark(mark: c.mark, size: 20)
                Text(c.text.line + " · " + c.text.title)
                    .font(Theme.serif(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 0) {
                ForEach(0...c.stationCount, id: \.self) { i in
                    StationDot(state: i == c.stationCount ? .terminal(solved: false) : (i < c.free ? .open : .locked), size: 12)
                    if i < c.stationCount {
                        Rectangle().fill(i < c.free - 1 ? Theme.accent : Theme.line).frame(height: 2)
                    }
                }
            }
            Text(trf("無料 %d 駅 → Pro で 10 駅＋終点", "%d free stops → all 10 + terminus with Pro", c.free))
                .font(.system(size: 11))
                .foregroundStyle(Theme.sub)
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.deep)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.soft))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 13)).foregroundStyle(Theme.sub)
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
            TrackBackground()
            VStack(spacing: 18) {
                Eyebrow(text: tr("答えの見えない路線図", "A spoiler-free route map"), color: Theme.deep)
                    .padding(.top, 24)
                card
                    .frame(width: 300, height: 400)
                    .shadow(color: Theme.ink.opacity(0.10), radius: 16, y: 8)
                Text(tr("解いた駅と定刻の数だけ。謎の答えは載りません。", "Only your stops and on-time count—no answers."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                Spacer()
            }
            .padding(.horizontal, 20)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let image = render(card) {
                        ShareLink(item: image, preview: SharePreview(c.text.title, image: image)) {
                            PrimaryButtonLabel(title: tr("画像を共有", "Share image"))
                        }
                        .accessibilityIdentifier("main.shareImage")
                    }
                    Button(tr("閉じる", "Close")) { model.activeSheet = nil }
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.deep)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("main.closeShare")
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                LineMark(mark: c.mark, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.text.line).font(Theme.label(11)).foregroundStyle(Theme.sub)
                    Text(c.text.title).font(Theme.serif(18, .semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            // 横の路線図：定刻＝濃い丸、遅れ＝淡い丸、まだ＝白
            HStack(spacing: 0) {
                ForEach(0...c.stationCount, id: \.self) { i in
                    let state: StopState = i == c.stationCount ? .terminal(solved: journey.isCaseSolved(c))
                        : (journey.arrival(c.id, i).map { $0.isOnTime ? .onTime : .late } ?? .open)
                    StationDot(state: state, size: 14)
                    if i < c.stationCount {
                        Rectangle().fill(journey.arrival(c.id, i) != nil ? Theme.deep : Theme.line).frame(height: 2)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(journey.solvedCount(c))")
                    .font(Theme.serif(64))
                    .kerning(-3)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text(tr("/ 10 駅", "/ 10 stops"))
                    .font(Theme.serif(16))
                    .foregroundStyle(Theme.sub)
            }
            HStack(spacing: 14) {
                Label(trf("定刻 %d", "%d on time", journey.onTimeCount(c)), systemImage: "circle.inset.filled")
                if journey.isCaseSolved(c) {
                    Label(tr("事件解決", "Case closed"), systemImage: "checkmark")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.deep)
            Rectangle().fill(Theme.line).frame(height: Theme.hairline)
            HStack {
                Text(tr("ひと駅なぞとき", "One Stop Riddles")).font(Theme.serif(13, .semibold))
                Spacer()
                Text(tr("一駅で、ひとつの謎", "One stop, one riddle")).font(.system(size: 10))
            }
            .foregroundStyle(Theme.sub)
        }
        .padding(22)
        .background(
            ZStack {
                Theme.card
                // 右上に淡い線路の弧
                Canvas { ctx, size in
                    var p = Path()
                    p.move(to: CGPoint(x: size.width * 0.55, y: 0))
                    p.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.45), control: CGPoint(x: size.width * 0.75, y: size.height * 0.25))
                    ctx.stroke(p, with: .color(Theme.soft), lineWidth: 16)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).strokeBorder(Theme.line, lineWidth: Theme.hairline))
    }
}
