import SwiftUI

// 題材の部品：路線図・駅名標・発車標の札・電車・2 分の線路。どれも自作の Shape / Canvas。

/// 電車（前から見た小さな車両。窓 2 つと前照灯）
struct TrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width * 0.32, height: rect.width * 0.32), style: .continuous)
        return p
    }
}

struct TrainIcon: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            TrainShape().fill(Theme.train)
            TrainShape().stroke(Theme.ink.opacity(0.55), lineWidth: 1)
            VStack(spacing: size * 0.12) {
                HStack(spacing: size * 0.1) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Theme.card)
                    RoundedRectangle(cornerRadius: 1.5).fill(Theme.card)
                }
                .frame(height: size * 0.32)
                HStack {
                    Circle().fill(Theme.card).frame(width: size * 0.14)
                    Spacer()
                    Circle().fill(Theme.card).frame(width: size * 0.14)
                }
            }
            .padding(size * 0.16)
        }
        .frame(width: size * 0.8, height: size)
        .accessibilityHidden(true)
    }
}

/// 駅の丸の状態
enum StopState: Equatable {
    case onTime, late, next, open, locked, terminal(solved: Bool)
}

/// 駅の丸（路線図の 1 駅）
struct StationDot: View {
    let state: StopState
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            switch state {
            case .onTime:
                Circle().fill(Theme.deep)
                Circle().fill(Theme.card).frame(width: size * 0.36)
            case .late:
                Circle().fill(Theme.accent)
                Circle().fill(Theme.card).frame(width: size * 0.36)
            case .next:
                Circle().fill(Theme.card)
                Circle().strokeBorder(Theme.train, lineWidth: 3)
            case .open:
                Circle().fill(Theme.card)
                Circle().strokeBorder(Theme.accent, lineWidth: 1.5)
            case .locked:
                Circle().fill(Theme.paper)
                Circle().strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
            case .terminal(let solved):
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(solved ? Theme.deep : Theme.card)
                RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Theme.deep, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 縦の路線図。駅ごとに丸・駅名・（解いた駅は）手がかり
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
        let rowHeight: CGFloat = compact ? 40 : 54
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .top) {
                // 線路（次の駅まで）
                if !isLast {
                    Rectangle()
                        .fill(i < (model.journey.nextIndex(c) ?? c.stationCount) ? Theme.deep : Theme.line)
                        .frame(width: Theme.rail)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 9)
                }
                StationDot(state: state)
                if state == .next {
                    TrainIcon(size: 20)
                        .offset(x: -22, y: -1)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: 18)
            .frame(minHeight: rowHeight, alignment: .top)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(isLast ? text.terminal : text.stations[i])
                        .font(Theme.serif(compact ? 14 : 16, isLast ? .semibold : .regular))
                        .foregroundStyle(state == .locked ? Theme.sub : Theme.ink)
                    if !isLast, let a = model.journey.arrival(c.id, i) {
                        ArrivalPill(arrival: a, small: true)
                    }
                    if state == .locked {
                        Image(systemName: "lock")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.sub)
                    }
                    if state == .next {
                        Text(tr("次の駅", "Next stop"))
                            .font(Theme.label(10))
                            .foregroundStyle(Theme.late)
                    }
                }
                if !compact, !isLast, model.journey.arrival(c.id, i) != nil {
                    Text(c.riddles[i].text.clue)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 0)
            Spacer(minLength: 0)
        }
        .padding(.leading, 24)
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

/// 定刻 / ◯分遅れ のピル
struct ArrivalPill: View {
    let arrival: Arrival
    var small = false
    var body: some View {
        Text(arrival.isOnTime ? tr("定刻", "On time") : trf("%d分遅れ", "%d min late", arrival.delayMinutes))
            .font(.system(size: small ? 10 : 12, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(arrival.isOnTime ? Theme.deep : Theme.late)
            .padding(.horizontal, small ? 6 : 9)
            .padding(.vertical, small ? 2 : 4)
            .background(Capsule().fill(arrival.isOnTime ? Theme.soft : Theme.trainSoft))
    }
}

/// 駅名標：大きな駅名、下の帯に前の駅と次の駅。解くと右上に改札のパンチの穴
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
            HStack(spacing: 10) {
                LineMark(mark: mysteryCase.mark, size: 24)
                Text(String(format: "%@%02d", mysteryCase.mark, index + 1))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.deep)
                Spacer()
                ZStack {
                    Circle().strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    if punched {
                        Circle().fill(Theme.paper)
                            .overlay(Circle().strokeBorder(Theme.deep, lineWidth: 1.2))
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.2).combined(with: .opacity))
                    }
                }
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Text(text.stations[index])
                .font(Theme.serif(30, .semibold))
                .kerning(Lang.isJapanese ? 4 : 0.5)
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)

            // 帯
            HStack(spacing: 0) {
                Text(prev.map { "← " + $0 } ?? " ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(next + " →")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.card)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.deep)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.line, lineWidth: Theme.hairline))
        .shadow(color: Theme.ink.opacity(0.06), radius: 10, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.stations[index])
    }
}

/// 発車標の札（図・暗号）。1 つの札に 1 語
struct FigureBoard: View {
    let tokens: [String]
    var body: some View {
        if !tokens.isEmpty {
            let long = tokens.contains { $0.count > 3 }
            FlowLayout(spacing: 6) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    Tile(text: token, wide: long)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.mist))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.line, lineWidth: Theme.hairline))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tokens.joined(separator: " "))
        }
    }

    struct Tile: View {
        let text: String
        let wide: Bool
        var body: some View {
            let isQuestion = text == "?"
            Text(text)
                .font(Theme.serif(wide ? 15 : 20, .semibold))
                .monospacedDigit()
                .foregroundStyle(isQuestion ? Theme.late : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, wide ? 8 : 0)
                .frame(minWidth: wide ? 0 : 36, minHeight: 44)
                .background(
                    // 札：白い面に、下だけ少し太い線（めくり式の札の厚み）
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isQuestion ? Theme.trainSoft : Theme.card)
                        .shadow(color: Theme.line, radius: 0, y: 2)
                )
                .overlay(
                    Rectangle().fill(Theme.line).frame(height: 0.6)
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

/// 2 分の線路：目盛りの上を小さな電車が進む。2 分を過ぎると遅れの色
struct RailTimer: View {
    let elapsed: Int
    var body: some View {
        let target = Arrival.targetSeconds
        let progress = min(1, Double(elapsed) / Double(target))
        let late = elapsed > target
        HStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.line).frame(height: 2)
                    Rectangle().fill(late ? Theme.train : Theme.accent).frame(width: w * progress, height: 2)
                    // 30 秒ごとの目盛り
                    ForEach(0..<5, id: \.self) { i in
                        Rectangle().fill(Theme.sub.opacity(0.5))
                            .frame(width: 1, height: i == 4 ? 10 : 6)
                            .offset(x: w * CGFloat(i) / 4 - 0.5)
                    }
                    TrainIcon(size: 14)
                        .offset(x: max(0, w * progress - 6), y: -9)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 24)
            Text(late ? "+" + Clock.mmss(elapsed - target) : Clock.mmss(target - elapsed))
                .font(Theme.serif(17, .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(late ? Theme.late : Theme.ink)
                .frame(width: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(late ? trf("定刻を %d 秒過ぎた", "%d seconds past on-time", elapsed - target)
                                 : trf("定刻まであと %d 秒", "%d seconds to arrive on time", target - elapsed))
    }
}
