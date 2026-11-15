import SwiftUI

/// 1 駅の謎。下に 4 つの大きな選択肢とヒントを固定（片手・揺れる電車で押しやすく）
struct RideView: View {
    @Environment(\.lineMark) private var lineMark
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake: [Int: Int] = [:]

    var body: some View {
        ZStack {
            NightBackground()
            if let c = model.rideCase, let ride = model.ride, let riddle = model.rideRiddle {
                if sizeClass == .regular {
                    // Duo の内側：左に路線図と物語、右に謎
                    HStack(alignment: .top, spacing: 24) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Eyebrow(text: c.text.line + " · " + c.text.title)
                                RouteMap(mysteryCase: c, allowsPractice: false, compact: true)
                                StoryPanel(mysteryCase: c)
                            }
                            .padding(20)
                        }
                        .frame(maxWidth: 380)
                        main(c: c, ride: ride, riddle: riddle)
                            .frame(maxWidth: 520)
                    }
                } else {
                    main(c: c, ride: ride, riddle: riddle)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: model.ride?.arrival)
        .animation(.easeOut(duration: 0.25), value: model.ride?.hintsShown)
    }

    @ViewBuilder
    private func main(c: MysteryCase, ride: RideState, riddle: Riddle) -> some View {
        let text = riddle.text
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StationSign(mysteryCase: c, index: ride.index, punched: ride.arrival != nil)
                if let arrival = ride.arrival {
                    ArrivalPanel(mysteryCase: c, ride: ride, riddle: riddle, arrival: arrival)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        RailTimer(elapsed: model.elapsed(at: context.date), mark: c.mark)
                    }
                    HStack(spacing: 8) {
                        Text(riddle.kind.label.uppercased())
                            .font(Theme.label(10))
                            .kerning(1.4)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.line(lineMark)))
                        if ride.practice {
                            Eyebrow(text: tr("練習 · 記録は変わりません", "Practice · records unchanged"), color: Theme.dim)
                        }
                    }
                    Text(text.q)
                        .font(Theme.body(17, .medium))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    FigureBoard(tokens: text.figure)
                    if ride.hintsShown > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<ride.hintsShown, id: \.self) { i in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(verbatim: "\(i + 1)")
                                        .font(Theme.board(12, .heavy))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 20, height: 20)
                                        .background(RoundedRectangle(cornerRadius: 3).fill(Theme.line(lineMark)))
                                    Text(text.hints[i])
                                        .font(Theme.body(14, .medium))
                                        .foregroundStyle(Theme.fileInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // ヒントは事件の資料のメモ（黄ばんだ紙片）
                        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Theme.file))
                        .rotationEffect(.degrees(0.6))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { model.closeRide() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(tr("路線図にもどる", "Back to the map"))
                .accessibilityIdentifier("main.closeRide")
                Spacer()
                HStack(spacing: 6) {
                    LineMark(mark: c.mark, size: 18)
                    Text(c.text.line)
                        .font(Theme.gothic(13, .bold))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .background(Theme.night.opacity(0.96))
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line(c.mark)).frame(height: 3) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if ride.arrival == nil {
                    answerPad(ride: ride, riddle: riddle)
                } else {
                    Button { model.closeRide() } label: {
                        PrimaryButtonLabel(title: tr("路線図にもどる", "Back to the map"),
                                           subtitle: ride.practice ? nil : nextNote)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("main.done")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Theme.night.opacity(0.97).ignoresSafeArea())
        }
    }

    private var nextNote: String {
        if model.pacing {
            return trf("今日はここまで。次の駅は %@ から", "That's all for now. Next stop opens at %@", Clock.time(model.nextOpening))
        }
        return tr("物語がひとつ進みました", "The story moved one stop")
    }

    private func answerPad(ride: RideState, riddle: Riddle) -> some View {
        let text = riddle.text
        return VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(0..<text.choices.count, id: \.self) { i in
                    let wrong = ride.wrong.contains(i)
                    Button {
                        if !model.choose(i) && !reduceMotion {
                            withAnimation(.linear(duration: 0.42)) { shake[i, default: 0] += 1 }
                        }
                    } label: {
                        // 選択肢：駅の押しボタンのような暗い板。左上に A〜D、下辺だけ厚い
                        HStack(spacing: 8) {
                            Text(verbatim: ["A", "B", "C", "D"][i % 4])
                                .font(Theme.board(11, .heavy))
                                .foregroundStyle(wrong ? Theme.dim : Theme.line(lineMark))
                            Text(text.choices[i])
                                .font(Theme.gothic(text.choices[i].count > 10 ? 13 : 16, .bold))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .strikethrough(wrong, color: Theme.late)
                                .foregroundStyle(wrong ? Theme.dim : Theme.text)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.board).offset(y: wrong ? 0 : 3)
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(wrong ? Theme.night : Theme.platform)
                            }
                        )
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                            .strokeBorder(wrong ? Theme.late.opacity(0.4) : Theme.rule, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                    .modifier(Shake(animatableData: CGFloat(shake[i, default: 0])))
                    .disabled(wrong)
                    .accessibilityIdentifier(wrong ? "choice.\(i)" : "main.choice.\(i)")
                }
            }
            Button { model.showHint() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .bold))
                    Text(ride.hintsShown < 3 ? trf("ヒント %d / 3", "Hint %d / 3", ride.hintsShown + 1) : tr("ヒントはここまで", "No more hints"))
                        .font(Theme.gothic(13, .bold))
                        .monospacedDigit()
                    if ride.hintsShown == 2 && !model.isPro {
                        Text(verbatim: "PRO")
                            .font(Theme.label(9))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.line(lineMark)))
                    }
                    Spacer()
                    Text(tr("1つにつき1分遅れ", "+1 min each"))
                        .font(Theme.label(10))
                        .foregroundStyle(Theme.dim)
                }
                .foregroundStyle(Theme.line(lineMark))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .disabled(ride.hintsShown >= 3)
            .accessibilityIdentifier(ride.hintsShown >= 3 ? "hint" : "main.hint")
        }
    }
}

/// まちがえたときの横揺れ（420ms、減衰）
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = animatableData - floor(animatableData)
        let amplitude: CGFloat = 8 * (1 - t)
        return ProjectionTransform(CGAffineTransform(translationX: amplitude * sin(t * .pi * 6), y: 0))
    }
}

/// 着いた：定刻か遅れか（発車標の表示）、答えのわけ、開いた物語の場面（事件の資料）
struct ArrivalPanel: View {
    @Environment(\.lineMark) private var lineMark
    @Environment(AppModel.self) private var model
    let mysteryCase: MysteryCase
    let ride: RideState
    let riddle: Riddle
    let arrival: Arrival
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = riddle.text
        let color = arrival.isOnTime ? Theme.line(lineMark) : Theme.late
        VStack(alignment: .leading, spacing: 16) {
            // 発車標：「定刻着」/「◯分遅れ」と所要時間が光る
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(arrival.isOnTime ? tr("定刻着", "ON TIME") : trf("%d分遅れで到着", "%d MIN LATE", arrival.delayMinutes))
                        .font(Theme.gothic(26, .heavy))
                        .foregroundStyle(color)
                        .shadow(color: color.opacity(0.6), radius: 6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Text(Clock.mmss(arrival.seconds))
                        .font(Theme.board(22, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .shadow(color: color.opacity(0.6), radius: 4)
                }
                Rectangle().fill(Theme.rule).frame(height: 1)
                HStack(spacing: 0) {
                    detail(tr("ヒント", "Hints"), "\(arrival.hints)")
                    detail(tr("まちがい", "Misses"), "\(arrival.misses)")
                    detail(tr("答え", "Answer"), text.choices[riddle.answer])
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.board))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1))
            .scaleEffect(shown || reduceMotion ? 1 : 0.94, anchor: .top)
            .opacity(shown || reduceMotion ? 1 : 0)
            Text(text.why)
                .font(Theme.body(14))
                .lineSpacing(5)
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)

            CaseFileSlip(tilt: 0.9) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        LineMark(mark: mysteryCase.mark, number: ride.index + 1, size: 24)
                        FileHeading(text: ride.practice ? tr("この駅の場面", "This stop's scene") : tr("物語がひとつ進んだ", "A new scene opens"))
                    }
                    Text(text.scene)
                        .font(Theme.body(15, .medium))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.fileInk)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .bold))
                        Text(text.clue)
                            .font(Theme.gothic(12, .bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.fileInk)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    // 手がかりは、資料に引いたマーカー
                    .background(Rectangle().fill(Theme.line(lineMark).opacity(0.45)))
                }
            }
            .padding(.top, 6)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .opacity(shown || reduceMotion ? 1 : 0)
        }
        .onAppear {
            if Launch.isStill { shown = true; return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.15)) { shown = true }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: label)
            Text(value)
                .font(Theme.gothic(15, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
