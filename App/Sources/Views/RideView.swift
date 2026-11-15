import SwiftUI

/// 1 駅の謎。下に 4 つの大きな選択肢とヒントを固定（片手・揺れる電車で押しやすく）
struct RideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake: [Int: Int] = [:]

    var body: some View {
        ZStack {
            TrackBackground()
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
                        RailTimer(elapsed: model.elapsed(at: context.date))
                    }
                    HStack(spacing: 8) {
                        Eyebrow(text: riddle.kind.label, color: Theme.deep)
                        if ride.practice {
                            Eyebrow(text: tr("練習 · 記録は変わりません", "Practice · records unchanged"))
                        }
                    }
                    Text(text.q)
                        .font(.system(size: 17))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    FigureBoard(tokens: text.figure)
                    if ride.hintsShown > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<ride.hintsShown, id: \.self) { i in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(verbatim: "\(i + 1)")
                                        .font(Theme.serif(13, .semibold))
                                        .foregroundStyle(Theme.deep)
                                        .frame(width: 20, height: 20)
                                        .background(Circle().fill(Theme.soft))
                                    Text(text.hints[i])
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.soft.opacity(0.6)))
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
                Text(c.text.line)
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.sub)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .foregroundStyle(Theme.deep)
            .padding(.horizontal, 12)
            .background(Theme.paper.opacity(0.96))
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
            .background(Theme.paper.opacity(0.96).ignoresSafeArea())
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
                        Text(text.choices[i])
                            .font(.system(size: text.choices[i].count > 10 ? 13 : 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .strikethrough(wrong, color: Theme.late)
                            .foregroundStyle(wrong ? Theme.sub : Theme.ink)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(wrong ? Theme.mist : Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                .strokeBorder(wrong ? Theme.line : Theme.accent, lineWidth: 1))
                            .shadow(color: Theme.line, radius: 0, y: wrong ? 0 : 2)
                    }
                    .buttonStyle(PressStyle())
                    .modifier(Shake(animatableData: CGFloat(shake[i, default: 0])))
                    .disabled(wrong)
                    .accessibilityIdentifier(wrong ? "choice.\(i)" : "main.choice.\(i)")
                }
            }
            Button { model.showHint() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb").font(.system(size: 12))
                    Text(ride.hintsShown < 3 ? trf("ヒント %d / 3", "Hint %d / 3", ride.hintsShown + 1) : tr("ヒントはここまで", "No more hints"))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                    if ride.hintsShown == 2 && !model.isPro {
                        Text(verbatim: "Pro")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.soft))
                    }
                    Spacer()
                    Text(tr("1つにつき1分遅れ", "+1 min each"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                }
                .foregroundStyle(Theme.deep)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().strokeBorder(Theme.line, lineWidth: Theme.hairline))
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

/// 着いた：定刻か遅れか、答えのわけ、開いた物語の場面
struct ArrivalPanel: View {
    @Environment(AppModel.self) private var model
    let mysteryCase: MysteryCase
    let ride: RideState
    let riddle: Riddle
    let arrival: Arrival
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = riddle.text
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(arrival.isOnTime ? tr("定刻着", "On time") : trf("%d分遅れで到着", "Arrived %d min late", arrival.delayMinutes))
                    .font(Theme.serif(26, .semibold))
                    .foregroundStyle(arrival.isOnTime ? Theme.deep : Theme.late)
                Spacer()
                Text(Clock.mmss(arrival.seconds))
                    .font(Theme.serif(20))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .scaleEffect(shown || reduceMotion ? 1 : 0.94, anchor: .leading)
            .opacity(shown || reduceMotion ? 1 : 0)
            HStack(spacing: 12) {
                detail(tr("ヒント", "Hints"), "\(arrival.hints)")
                detail(tr("まちがい", "Misses"), "\(arrival.misses)")
                detail(tr("答え", "Answer"), text.choices[riddle.answer])
            }
            Text(text.why)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)

            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        LineMark(mark: mysteryCase.mark, size: 18)
                        Eyebrow(text: ride.practice ? tr("この駅の場面", "This stop's scene") : tr("物語がひとつ進んだ", "A new scene opens"), color: Theme.deep)
                    }
                    Text(text.scene)
                        .font(.system(size: 15))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 11))
                        Text(text.clue)
                            .font(.system(size: 12, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.deep)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.soft))
                }
            }
            .offset(y: shown || reduceMotion ? 0 : 16)
            .opacity(shown || reduceMotion ? 1 : 0)
        }
        .onAppear {
            if Launch.isStill { shown = true; return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.15)) { shown = true }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(text: label)
            Text(value)
                .font(Theme.serif(15, .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).strokeBorder(Theme.line, lineWidth: Theme.hairline))
    }
}
