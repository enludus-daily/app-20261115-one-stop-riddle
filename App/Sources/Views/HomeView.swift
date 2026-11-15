import SwiftUI

/// ホーム：今の事件の路線図。下に「次の駅へ」を固定する
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            TrackBackground()
            if sizeClass == .regular {
                // Duo の内側など広い画面：左に路線図、右に物語
                HStack(alignment: .top, spacing: 24) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            header
                            caseTabs
                            caseTitle
                            RouteMap(mysteryCase: model.current)
                        }
                        .padding(20)
                    }
                    .frame(maxWidth: 420)
                    VStack(spacing: 16) {
                        ScrollView { StoryPanel(mysteryCase: model.current).padding(.top, 20) }
                        bottomBar
                    }
                    .frame(maxWidth: 480)
                    .padding(.trailing, 20)
                    .padding(.bottom, 12)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        caseTabs
                        caseTitle
                        RouteMap(mysteryCase: model.current)
                            .padding(.top, 4)
                        StoryPanel(mysteryCase: model.current)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Theme.paper.opacity(0.96))
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomBar
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .background(Theme.paper.opacity(0.96).ignoresSafeArea())
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.journey)
    }

    // MARK: -

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("ひと駅なぞとき", "One Stop Riddles"))
                    .font(Theme.serif(17, .semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Text(Clock.day(model.currentDate))
                    Text(verbatim: "·")
                    Text(model.slot.label)
                    let streak = model.journey.streak(at: model.currentDate, calendar: model.calendar)
                    if streak > 0 {
                        Text(verbatim: "·")
                        Text(trf("%d日つづけて乗車", "%d-day streak", streak))
                            .monospacedDigit()
                    }
                }
                .font(Theme.label(11))
                .foregroundStyle(Theme.sub)
            }
            Spacer()
            Button { model.press(); model.activeSheet = .share(model.current.id) } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr("路線図を共有", "Share route map"))
            .accessibilityIdentifier("main.share")
            Button { model.press(); model.activeSheet = .settings } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr("設定", "Settings"))
            .accessibilityIdentifier("main.settings")
        }
        .foregroundStyle(Theme.deep)
    }

    private var caseTabs: some View {
        HStack(spacing: 8) {
            ForEach(model.cases) { c in
                let selected = c.id == model.current.id
                Button { model.select(c) } label: {
                    HStack(spacing: 6) {
                        LineMark(mark: c.mark, size: 20, filled: selected)
                        Text(c.text.line)
                            .font(.system(size: 12, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(verbatim: "\(model.journey.solvedCount(c))/\(c.stationCount)")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(Theme.sub)
                    }
                    .foregroundStyle(selected ? Theme.ink : Theme.sub)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Capsule().fill(selected ? Theme.card : .clear))
                    .overlay(Capsule().strokeBorder(selected ? Theme.accent : Theme.line, lineWidth: selected ? 1 : Theme.hairline))
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var caseTitle: some View {
        let c = model.current
        let solved = model.journey.solvedCount(c)
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: trf("事件 %d · %@", "Case %d · %@", (model.cases.firstIndex(of: c) ?? 0) + 1, c.text.line))
            Text(c.text.title)
                .font(Theme.serif(28, .semibold))
                .kerning(Lang.isJapanese ? 1 : -0.5)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                stat(value: "\(solved)", unit: tr("/ 10 駅", "/ 10 stops"))
                stat(value: "\(model.journey.onTimeCount(c))", unit: tr("定刻", "On time"))
                if let rate = model.journey.onTimeRate {
                    stat(value: "\(Int((rate * 100).rounded()))%", unit: tr("定刻率", "On-time rate"))
                }
            }
        }
    }

    private func stat(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(Theme.serif(24))
                .kerning(-1)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.ink)
            Text(unit)
                .font(Theme.label(11))
                .foregroundStyle(Theme.sub)
        }
    }

    // MARK: - 下のボタン

    @ViewBuilder
    private var bottomBar: some View {
        let c = model.current
        switch model.nextAction {
        case .ride(let i):
            Button { model.startRide() } label: {
                PrimaryButtonLabel(title: trf("次の駅へ ― %@", "Ride to %@", c.text.stations[i]),
                                   subtitle: trf("%@ · 2分でひと駅", "%@ · one stop in 2 min", model.slot.label))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("main.ride")
        case .rest:
            VStack(spacing: 8) {
                PrimaryButtonLabel(title: tr("今日のこの便はここまで", "That's it for this ride"),
                                   subtitle: trf("次の駅は %@ から", "Next stop opens at %@", Clock.time(model.nextOpening)),
                                   enabled: false)
                    .accessibilityIdentifier("main.rest")
                Text(tr("解いた駅を押すと、練習で解き直せます。", "Tap a solved stop to replay it for practice."))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.sub)
            }
        case .locked(let i):
            Button { model.showPaywall(.lockedStation) } label: {
                PrimaryButtonLabel(title: tr("この先は Pro で", "Continue with Pro"),
                                   subtitle: i < c.stationCount ? trf("%@ から終点まで", "From %@ to the terminus", c.text.stations[i])
                                                                : tr("終点で真相を選ぶ", "Choose the truth at the terminus"))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("main.unlock")
        case .finale:
            Button { model.openFinale() } label: {
                PrimaryButtonLabel(title: trf("終点へ ― %@", "To the terminus ― %@", c.text.terminal),
                                   subtitle: tr("手がかりから真相を選ぶ", "Pick the truth from your clues"))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("main.finale")
        case .solved:
            Button { model.openFinale() } label: {
                PrimaryButtonLabel(title: tr("解決した事件 ― 真相を読む", "Case closed ― read the truth"),
                                   subtitle: nextCaseHint)
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("main.finale")
        }
    }

    private var nextCaseHint: String {
        if let other = model.cases.first(where: { !model.journey.isCaseSolved($0) }) {
            return trf("次は %@「%@」", "Next: %@ “%@”", other.text.line, other.text.title)
        }
        return tr("3 つの事件をすべて解決", "All three cases closed")
    }
}

/// 物語：事件のはじまりと、開いた場面
struct StoryPanel: View {
    @Environment(AppModel.self) private var model
    let mysteryCase: MysteryCase

    var body: some View {
        let c = mysteryCase
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: tr("物語", "Story"))
                Text(c.text.intro)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                let opened = (0..<c.stationCount).filter { model.journey.arrival(c.id, $0) != nil }
                if opened.isEmpty {
                    Text(tr("1 駅解くごとに、物語の場面がひとつ開きます。", "Each stop you solve opens a new scene."))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                } else {
                    ForEach(opened, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(format: "%@%02d", c.mark, i + 1))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.deep)
                                .frame(width: 30, alignment: .leading)
                                .padding(.top, 2)
                            Text(c.riddles[i].text.scene)
                                .font(.system(size: 13))
                                .lineSpacing(3)
                                .foregroundStyle(Theme.ink.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}
