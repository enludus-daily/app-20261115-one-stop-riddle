import SwiftUI

/// 終点：集めた手がかりから、4 つのうち真相を 1 つ選ぶ
struct FinaleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let caseID: String
    @State private var shake: [Int: Int] = [:]

    var body: some View {
        let c = Library.mysteryCase(caseID) ?? model.current
        let solved = model.journey.isCaseSolved(c)
        ZStack {
            TrackBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            LineMark(mark: c.mark, size: 22)
                            Eyebrow(text: c.text.line, color: Theme.deep)
                        }
                        Text(c.text.terminal)
                            .font(Theme.serif(30, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(c.text.title)
                            .font(Theme.serif(16))
                            .foregroundStyle(Theme.sub)
                    }
                    if solved {
                        truth(c)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        Text(c.finale.text.q)
                            .font(Theme.serif(22, .semibold))
                            .foregroundStyle(Theme.ink)
                        if !model.finaleWrong.isEmpty {
                            Text(tr("ちがうようです。手がかりをもう一度読んでみましょう。", "Not quite. Read the clues again."))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.late)
                        }
                    }
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            clues(c)
                            if !solved { suspects(c) }
                        }
                    } else {
                        if !solved { suspects(c) }
                        clues(c)
                    }
                }
                .padding(20)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Button { model.closeFinale() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(tr("路線図にもどる", "Back to the map"))
                    .accessibilityIdentifier("main.closeFinale")
                    Spacer()
                }
                .foregroundStyle(Theme.deep)
                .padding(.horizontal, 12)
                .background(Theme.paper.opacity(0.96))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if solved {
                    HStack(spacing: 10) {
                        Button { model.closeFinale(); shareLater(c) } label: {
                            OutlineButtonLabel(title: tr("共有", "Share"), systemImage: "square.and.arrow.up")
                        }
                        .frame(width: 120)
                        Button { model.closeFinale() } label: {
                            PrimaryButtonLabel(title: tr("路線図にもどる", "Back to the map"))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("main.doneFinale")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Theme.paper.opacity(0.96).ignoresSafeArea())
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: solved)
    }

    private func shareLater(_ c: MysteryCase) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if model.activeSheet == nil { model.activeSheet = .share(c.id) }
        }
    }

    private func suspects(_ c: MysteryCase) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(c.finale.text.suspects.enumerated()), id: \.offset) { i, s in
                let wrong = model.finaleWrong.contains(i)
                Button {
                    if !model.chooseSuspect(i) && !reduceMotion {
                        withAnimation(.linear(duration: 0.42)) { shake[i, default: 0] += 1 }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(verbatim: ["A", "B", "C", "D"][i])
                            .font(Theme.serif(16, .semibold))
                            .foregroundStyle(wrong ? Theme.sub : Theme.deep)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(wrong ? Theme.mist : Theme.soft))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                                .font(.system(size: 16, weight: .medium))
                                .strikethrough(wrong, color: Theme.late)
                            Text(s.note)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.sub)
                        }
                        .foregroundStyle(wrong ? Theme.sub : Theme.ink)
                        Spacer()
                    }
                    .padding(12)
                    .frame(minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(wrong ? Theme.mist : Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(wrong ? Theme.line : Theme.accent, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                .modifier(Shake(animatableData: CGFloat(shake[i, default: 0])))
                .disabled(wrong)
                .accessibilityIdentifier(wrong ? "suspect.\(i)" : "main.suspect.\(i)")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func clues(_ c: MysteryCase) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: tr("集めた手がかり", "Your clues"))
                ForEach(model.journey.clues(c)) { clue in
                    HStack(alignment: .top, spacing: 10) {
                        StationDot(state: model.journey.arrival(c.id, clue.index)?.isOnTime == true ? .onTime : .late, size: 12)
                            .padding(.top, 3)
                        Text(clue.text)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func truth(_ c: MysteryCase) -> some View {
        let tries = model.journey.finales[c.id]?.tries ?? 1
        let suspect = c.finale.text.suspects[c.finale.answer]
        return Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: tr("真相", "The truth"), color: Theme.deep)
                Text(suspect.name)
                    .font(Theme.serif(24, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(c.finale.text.truth)
                    .font(.system(size: 15))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Theme.line).frame(height: Theme.hairline)
                HStack(spacing: 18) {
                    figure("\(model.journey.onTimeCount(c))/\(c.stationCount)", tr("定刻", "On time"))
                    figure("\(tries)", tr("推理の回数", "Guesses"))
                    if model.isPro, let fastest = model.journey.fastestSeconds(c) {
                        figure(Clock.mmss(fastest), tr("最速の駅", "Fastest stop"))
                    }
                }
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(Theme.serif(22))
                .monospacedDigit()
                .kerning(-0.5)
                .foregroundStyle(Theme.ink)
            Eyebrow(text: label)
        }
    }
}
