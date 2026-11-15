import SwiftUI

/// ホーム：今の事件の路線図。下に「次の駅へ」を固定する
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            NightBackground()
            if sizeClass == .regular {
                // Duo の内側など広い画面：左に路線図、右に物語
                VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                HStack(alignment: .top, spacing: 24) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
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
                }
            } else {
                // 見出しと「次の駅へ」はスクロールの外に固定する（UI テストで押せることを確かめる）
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    Rectangle().fill(Theme.rule).frame(height: Theme.hairline)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            caseTabs
                            caseTitle
                            RouteMap(mysteryCase: model.current)
                                .padding(.top, 4)
                            StoryPanel(mysteryCase: model.current)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    }
                    Rectangle().fill(Theme.rule).frame(height: Theme.hairline)
                    bottomBar
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.journey)
    }

    // MARK: -

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("ひと駅なぞとき", "One Stop Riddles"))
                    .font(Theme.gothic(19, .heavy))
                    .foregroundStyle(Theme.text)
                // 発車標の 1 行：便・日付・連続
                HStack(spacing: 8) {
                    Text(model.slot.label)
                        .foregroundStyle(Theme.led)
                        .shadow(color: Theme.glow, radius: 3)
                    Text(Clock.day(model.currentDate))
                        .foregroundStyle(Theme.dim)
                    let streak = model.journey.streak(at: model.currentDate, calendar: model.calendar)
                    if streak > 0 {
                        Text(trf("%d日連続", "%d-DAY STREAK", streak))
                            .monospacedDigit()
                            .foregroundStyle(Theme.led)
                    }
                }
                .font(Theme.label(11))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer()
            Button { model.press(); model.activeSheet = .share(model.current.id) } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr("路線図を共有", "Share route map"))
            .accessibilityIdentifier("main.share")
            Button { model.press(); model.activeSheet = .settings } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr("設定", "Settings"))
            .accessibilityIdentifier("main.settings")
        }
        .foregroundStyle(Theme.text)
    }

    /// 路線（事件）の切り替え：駅ナンバリングの記号と、選んだ路線の下に色の帯
    private var caseTabs: some View {
        HStack(spacing: 8) {
            ForEach(model.cases) { c in
                let selected = c.id == model.current.id
                Button { model.select(c) } label: {
                    VStack(spacing: 0) {
                        HStack(spacing: 7) {
                            LineMark(mark: c.mark, size: 22, dimmed: !selected)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.text.line)
                                    .font(Theme.gothic(12, selected ? .bold : .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(verbatim: "\(model.journey.solvedCount(c))/\(c.stationCount)")
                                    .font(Theme.label(9))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.dim)
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(selected ? Theme.text : Theme.dim)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        Rectangle().fill(selected ? Theme.line(c.mark) : Theme.rule).frame(height: selected ? 4 : 1)
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(selected ? Theme.tunnel : .clear))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var caseTitle: some View {
        let c = model.current
        let solved = model.journey.solvedCount(c)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(trf("事件 %02d", "CASE %02d", (model.cases.firstIndex(of: c) ?? 0) + 1))
                    .font(Theme.label(10))
                    .kerning(1.4)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.line(c.mark))
                Eyebrow(text: c.text.line, color: Theme.line(c.mark))
            }
            Text(c.text.title)
                .font(Theme.gothic(30, .heavy))
                .kerning(Lang.isJapanese ? 1 : -0.3)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            // 発車標の数字：解いた駅・定刻・定刻率
            HStack(spacing: 0) {
                stat(value: "\(solved)/10", unit: tr("駅", "Stops"))
                divider
                stat(value: "\(model.journey.onTimeCount(c))", unit: tr("定刻", "On time"))
                divider
                stat(value: model.journey.onTimeRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "--", unit: tr("定刻率", "On-time rate"))
            }
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.board))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1))
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1, height: 30)
    }

    private func stat(value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(Theme.board(22, .heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.led)
                .shadow(color: Theme.glow, radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit.uppercased())
                .font(Theme.label(9))
                .kerning(1.2)
                .foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity)
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
                    .accessibilityIdentifier("home.rest")
                Text(tr("解いた駅を押すと、練習で解き直せます。", "Tap a solved stop to replay it for practice."))
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.dim)
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

/// 物語：事件のはじまりと、開いた場面（事件の資料の紙片）
struct StoryPanel: View {
    @Environment(AppModel.self) private var model
    let mysteryCase: MysteryCase

    var body: some View {
        let c = mysteryCase
        CaseFileSlip {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    FileHeading(text: tr("事件資料 · 物語", "Case file · Story"))
                    Spacer()
                    Text(verbatim: "No.\(c.mark)-\(String(format: "%02d", (model.cases.firstIndex(of: c) ?? 0) + 1))")
                        .font(Theme.label(10))
                        .foregroundStyle(Theme.fileSub)
                }
                Text(c.text.intro)
                    .font(Theme.body(14, .medium))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.fileInk)
                    .fixedSize(horizontal: false, vertical: true)
                let opened = (0..<c.stationCount).filter { model.journey.arrival(c.id, $0) != nil }
                if opened.isEmpty {
                    Text(tr("1 駅解くごとに、物語の場面がひとつ開きます。", "Each stop you solve opens a new scene."))
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.fileSub)
                } else {
                    ForEach(opened, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(format: "%@%02d", c.mark, i + 1))
                                .font(Theme.label(10))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Theme.line(c.mark))
                                .padding(.top, 2)
                            Text(c.riddles[i].text.scene)
                                .font(Theme.body(13))
                                .lineSpacing(4)
                                .foregroundStyle(Theme.fileInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}
