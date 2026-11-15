import SwiftUI

// 題材の部品：路線図・駅名標・発車標の札・電車・2 分の線路・事件の資料の紙片。どれも自作の Shape / Canvas。

/// 電車（前から見た車両。銀の車体に路線の帯、アンバーの前照灯）
struct TrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width * 0.28, height: rect.width * 0.28), style: .continuous)
        return p
    }
}

struct TrainIcon: View {
    var size: CGFloat = 22
    var mark: String = "M"
    var body: some View {
        ZStack {
            TrainShape().fill(Theme.sign)
            VStack(spacing: size * 0.08) {
                // 窓
                RoundedRectangle(cornerRadius: 1.5).fill(Theme.signInk)
                    .frame(height: size * 0.3)
                // 路線の帯
                Rectangle().fill(Theme.line(mark)).frame(height: max(2, size * 0.12))
                HStack {
                    Circle().fill(Theme.led).frame(width: size * 0.16)
                    Spacer()
                    Circle().fill(Theme.led).frame(width: size * 0.16)
                }
            }
            .padding(size * 0.12)
        }
        .frame(width: size * 0.8, height: size)
        .shadow(color: Theme.glow, radius: size * 0.3)
        .accessibilityHidden(true)
    }
}

/// 駅の丸の状態
enum StopState: Equatable {
    case onTime, late, next, open, locked, terminal(solved: Bool)
}

/// 駅の丸（路線図の 1 駅）。路線の色で塗る：定刻＝塗りつぶし、遅れ＝白に赤い点、次＝光る輪、まだ＝輪だけ、鍵＝点線
struct StationDot: View {
    let state: StopState
    var mark: String = "M"
    var size: CGFloat = 18
    var body: some View {
        let color = Theme.line(mark)
        ZStack {
            switch state {
            case .onTime:
                Circle().fill(color)
                Circle().fill(Theme.sign).frame(width: size * 0.38)
            case .late:
                Circle().fill(Theme.sign)
                Circle().strokeBorder(color, lineWidth: max(2, size * 0.16))
                Circle().fill(Theme.late).frame(width: size * 0.3)
            case .next:
                Circle().fill(Theme.board)
                Circle().strokeBorder(Theme.led, lineWidth: max(2.5, size * 0.18))
                    .shadow(color: Theme.glow, radius: 6)
            case .open:
                Circle().fill(Theme.night)
                Circle().strokeBorder(color.opacity(0.75), lineWidth: max(2, size * 0.14))
            case .locked:
                Circle().fill(Theme.night)
                Circle().strokeBorder(Theme.dim.opacity(0.6), style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
            case .terminal(let solved):
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(solved ? color : Theme.night)
                RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(solved ? Theme.sign : color, lineWidth: 2.5)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 縦の路線図。路線の色の太い線路・駅の丸・駅ナンバー・（解いた駅は）手がかり
struct RouteMap: View {
    @Environment(AppModel.self) private var model
    let mysteryCase: MysteryCase
    /// 解いた駅を押すと解き直し（練習）
    var allowsPractice = true
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let journey = model.journey
        let c = mysteryCase
        let next = journey.nextIndex(c)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<c.stationCount, id: \.self) { i in
                let state = stopState(i, next: next)
                row(index: i, state: state, isLast: false)
            }
            row(index: c.stationCount, state: .terminal(solved: journey.isCaseSolved(c)), isLast: true)
        }
    }

    private func stopState(_ i: Int, next: Int?) -> StopState {
        if let a = model.journey.arrival(mysteryCase.id, i) { return a.isOnTime ? .onTime : .late }
        if model.journey.isLocked(mysteryCase, index: i, isPro: model.isPro) { return .locked }
        return i == next ? .next : .open
    }

    @ViewBuilder
    private func row(index i: Int, state: StopState, isLast: Bool) -> some View {
        let c = mysteryCase
        let text = c.text
        let color = Theme.line(c.mark)
        let rowHeight: CGFloat = compact ? 42 : 58
        let passed = i < (model.journey.nextIndex(c) ?? c.stationCount)
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .top) {
                // 線路（次の駅まで）。通った区間は路線の色、この先は暗く
                if !isLast {
                    Rectangle()
                        .fill(passed ? color : color.opacity(0.22))
                        .frame(width: Theme.rail)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 10)
                }
                StationDot(state: state, mark: c.mark, size: 20)
                if state == .next {
                    TrainIcon(size: 22, mark: c.mark)
                        .offset(x: -26, y: -2)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: 20)
            .frame(minHeight: rowHeight, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(isLast ? text.terminal : text.stations[i])
                        .font(Theme.gothic(compact ? 14 : 17, isLast ? .heavy : .bold))
                        .foregroundStyle(state == .locked ? Theme.dim : Theme.text)
                    if !isLast {
                        Text(String(format: "%@%02d", c.mark, i + 1))
                            .font(Theme.label(10))
                            .foregroundStyle(Theme.dim)
                    }
                    if !isLast, let a = model.journey.arrival(c.id, i) {
                        ArrivalPill(arrival: a, small: true)
                    }
                    if state == .locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.dim)
                    }
                    if state == .next {
                        Text(tr("次の駅", "NEXT"))
                            .font(Theme.label(10))
                            .foregroundStyle(Theme.ledInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.led))
                    }
                }
                if !compact, !isLast, model.journey.arrival(c.id, i) != nil {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "magnifyingglass").font(.system(size: 9, weight: .bold)).padding(.top, 2)
                        Text(c.riddles[i].text.clue)
                            .font(Theme.body(12))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 28)
        .contentShape(Rectangle())
        .onTapGesture {
            guard allowsPractice, !isLast, model.journey.arrival(c.id, i) != nil else { return }
            model.practice(i)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility(i: i, state: state, isLast: isLast))
    }

    private func accessibility(i: Int, state: StopState, isLast: Bool) -> String {
        let name = isLast ? mysteryCase.text.terminal : mysteryCase.text.stations[i]
        switch state {
        case .onTime: return trf("%@ 定刻着", "%@, on time", name)
        case .late: return trf("%@ 到着", "%@, arrived", name)
        case .next: return trf("%@ 次の駅", "%@, next stop", name)
        case .locked: return trf("%@ Pro で開く", "%@, unlocks with Pro", name)
        case .open: return name
        case .terminal(let solved): return solved ? trf("%@ 解決", "%@, solved", name) : name
        }
    }
}

/// 定刻 / ◯分遅れ（発車標の小さな表示）
struct ArrivalPill: View {
    let arrival: Arrival
    var small = false
    var body: some View {
        Text(arrival.isOnTime ? tr("定刻", "On time").uppercased() : trf("%d分遅れ", "+%d MIN", arrival.delayMinutes))
            .font(Theme.label(small ? 9 : 11))
            .monospacedDigit()
            .foregroundStyle(arrival.isOnTime ? Theme.led : Theme.late)
            .padding(.horizontal, small ? 5 : 8)
            .padding(.vertical, small ? 2 : 4)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.board))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder((arrival.isOnTime ? Theme.led : Theme.late).opacity(0.4), lineWidth: 1))
    }
}

/// 駅名標：裏から照らされた白い板に太いゴシックの駅名、下に路線の色の帯（前の駅・次の駅）。
/// 解くと右上に改札のパンチの穴が開く
struct StationSign: View {
    let mysteryCase: MysteryCase
    let index: Int
    var punched = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = mysteryCase.text
        let prev = index > 0 ? text.stations[index - 1] : nil
        let next = index + 1 < text.stations.count ? text.stations[index + 1] : text.terminal
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                LineMark(mark: mysteryCase.mark, number: index + 1, size: 40)
                Text(text.stations[index])
                    .font(Theme.gothic(32, .heavy))
                    .kerning(Lang.isJapanese ? 3 : 0.2)
                    .foregroundStyle(Theme.signInk)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Spacer(minLength: 0)
                // 改札のパンチ：解く前は点線の丸、解くと穴（下の暗い地が見える）
                ZStack {
                    Circle().strokeBorder(Theme.signSub.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    if punched {
                        Circle().fill(Theme.night)
                            .padding(1)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.2).combined(with: .opacity))
                    }
                }
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            // 帯
            HStack(spacing: 0) {
                Text(prev.map { "◀ " + $0 } ?? " ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(next + " ▶")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(Theme.gothic(12, .bold))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.line(mysteryCase.mark))
        }
        .background(Theme.sign)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).strokeBorder(Theme.signInk.opacity(0.6), lineWidth: 2))
        // 裏からの明かり
        .shadow(color: Theme.sign.opacity(0.14), radius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.stations[index])
    }
}

/// 発車標の札（図・暗号）。黒い発車標に、めくり式の札を並べ、アンバーの光る文字で 1 語ずつ
struct FigureBoard: View {
    let tokens: [String]
    var body: some View {
        if !tokens.isEmpty {
            let long = tokens.contains { $0.count > 3 }
            FlowLayout(spacing: 5) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    Tile(text: token, wide: long)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.board))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1.5))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tokens.joined(separator: " "))
        }
    }

    struct Tile: View {
        let text: String
        let wide: Bool
        var body: some View {
            let isQuestion = text == "?"
            let color = isQuestion ? Theme.late : Theme.led
            Text(text)
                .font(wide ? Theme.gothic(15, .bold) : Theme.board(22, .heavy))
                .monospacedDigit()
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.7), radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, wide ? 9 : 0)
                .frame(minWidth: wide ? 0 : 36, minHeight: 46)
                .background(
                    // めくり式の札：上下 2 枚の板と、真ん中の切れ目
                    VStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(hex: 0x1A2127))
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(hex: 0x141A1F))
                    }
                )
        }
    }
}

/// 折り返して並べる
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rows = arrange(width: width, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += row.indices.isEmpty ? size.width : size.width + spacing
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// 2 分の線路：発車標の帯の上を小さな電車が進む。残り時間は光る数字。2 分を過ぎると赤
struct RailTimer: View {
    let elapsed: Int
    var mark: String = "M"
    var body: some View {
        let target = Arrival.targetSeconds
        let progress = min(1, Double(elapsed) / Double(target))
        let late = elapsed > target
        let color = late ? Theme.late : Theme.led
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(late ? tr("遅れ", "LATE") : tr("定刻まで", "ON TIME IN"))
                    .font(Theme.label(9))
                    .kerning(1.2)
                    .foregroundStyle(Theme.dim)
                Text(late ? "+" + Clock.mmss(elapsed - target) : Clock.mmss(target - elapsed))
                    .font(Theme.board(24, .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.6), radius: 5)
            }
            .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.line(mark).opacity(0.22)).frame(height: 4)
                    Rectangle().fill(late ? Theme.late : Theme.line(mark)).frame(width: w * progress, height: 4)
                    // 30 秒ごとの駅
                    ForEach(0..<5, id: \.self) { i in
                        Circle().fill(Theme.board)
                            .overlay(Circle().strokeBorder(Theme.dim, lineWidth: 1.2))
                            .frame(width: i == 4 ? 10 : 6, height: i == 4 ? 10 : 6)
                            .offset(x: w * CGFloat(i) / 4 - (i == 4 ? 5 : 3))
                    }
                    TrainIcon(size: 16, mark: mark)
                        .offset(x: max(0, w * progress - 7), y: -13)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.board))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(late ? trf("定刻を %d 秒過ぎた", "%d seconds past on-time", elapsed - target)
                                 : trf("定刻まであと %d 秒", "%d seconds to arrive on time", target - elapsed))
    }
}

/// 事件の資料：クラフト紙の紙片。うすい罫、上にクリップ、わずかに傾ける
struct CaseFileSlip<Content: View>: View {
    var tilt: Double = -0.8
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Theme.file
                    Canvas { ctx, size in
                        var y: CGFloat = 30
                        while y < size.height {
                            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.6)), with: .color(Theme.fileRule.opacity(0.7)))
                            y += 24
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(alignment: .topLeading) {
                PaperClip()
                    .stroke(Theme.clip, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 14, height: 36)
                    .offset(x: 22, y: -10)
                    .accessibilityHidden(true)
            }
            .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
            .rotationEffect(.degrees(tilt))
    }
}

/// ゼムクリップ（細い線の縦長の輪 2 重）
struct PaperClip: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: r, cornerSize: CGSize(width: r.width / 2, height: r.width / 2), style: .continuous)
        let inner = CGRect(x: r.minX + r.width * 0.25, y: r.minY + r.height * 0.14, width: r.width * 0.5, height: r.height * 0.62)
        p.addRoundedRect(in: inner, cornerSize: CGSize(width: inner.width / 2, height: inner.width / 2), style: .continuous)
        return p
    }
}

/// 資料の見出し（等幅のタイプ文字）
struct FileHeading: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10))
            .kerning(1.6)
            .foregroundStyle(Theme.fileSub)
    }
}

/// 赤いスタンプ（「解決」など。1 画面に 1 つだけ）
struct Stamp: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.gothic(15, .heavy))
            .kerning(2)
            .foregroundStyle(Theme.late)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.late, lineWidth: 2.2))
            .rotationEffect(.degrees(-8))
            .opacity(0.9)
    }
}
