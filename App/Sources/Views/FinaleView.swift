import SwiftUI

/// 終点：集めた手がかりから、4 つのうち真相を 1 つ選ぶ
struct FinaleView: View {
    @Environment(\.lineMark) private var lineMark
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let caseID: String
    @State private var shake: [Int: Int] = [:]

    var body: some View {
        let c = Library.mysteryCase(caseID) ?? model.current
        let solved = model.journey.isCaseSolved(c)
        ZStack {
            NightBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            LineMark(mark: c.mark, size: 24)
                            Eyebrow(text: c.text.line, color: Theme.line(c.mark))
                        }
                        // 終点の駅名標の帯
                        Text(c.text.terminal)
                            .font(Theme.gothic(32, .heavy))
                            .foregroundStyle(Theme.text)
                        LineBand(mark: c.mark, height: 6)
                        Text(c.text.title)
                            .font(Theme.gothic(16, .semibold))
                            .foregroundStyle(Theme.dim)
                    }
                    if solved {
                        truth(c)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        Text(c.finale.text.q)
                            .font(Theme.gothic(22, .bold))
                            .foregroundStyle(Theme.line(lineMark))
                            .shadow(color: Theme.glow(lineMark), radius: 5)
                            .fixedSize(horizontal: false, vertical: true)
                        if !model.finaleWrong.isEmpty {
                            Text(tr("ちがうようです。手がかりをもう一度読んでみましょう。", "Not quite. Read the clues again."))
                                .font(Theme.body(13, .medium))
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
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .background(Theme.night.opacity(0.96))
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
                    .background(Theme.night.opacity(0.97).ignoresSafeArea())
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
                        // 容疑者の札：発車標の記号 A〜D
                        Text(verbatim: ["A", "B", "C", "D"][i])
                            .font(Theme.board(17, .heavy))
                            .foregroundStyle(wrong ? Theme.dim : Theme.line(lineMark))
                            .shadow(color: wrong ? .clear : Theme.glow(lineMark), radius: 4)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusS).fill(Theme.board))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                                .font(Theme.gothic(16, .bold))
                                .strikethrough(wrong, color: Theme.late)
                            Text(s.note)
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.dim)
                        }
                        .foregroundStyle(wrong ? Theme.dim : Theme.text)
                        Spacer()
                        if wrong {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.late)
                        }
                    }
                    .padding(12)
                    .frame(minHeight: 62)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.board).offset(y: wrong ? 0 : 3)
                            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(wrong ? Theme.night : Theme.platform)
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).strokeBorder(wrong ? Theme.late.opacity(0.4) : Theme.rule, lineWidth: 1))
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
        CaseFileSlip(tilt: -0.6) {
            VStack(alignment: .leading, spacing: 10) {
                FileHeading(text: tr("事件資料 · 集めた手がかり", "Case file · Your clues"))
                ForEach(model.journey.clues(c)) { clue in
                    HStack(alignment: .top, spacing: 10) {
                        StationDot(state: model.journey.arrival(c.id, clue.index)?.isOnTime == true ? .onTime : .late, mark: c.mark, size: 12)
                            .padding(.top, 3)
                        Text(clue.text)
                            .font(Theme.body(13, .medium))
                            .foregroundStyle(Theme.fileInk)
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
        return CaseFileSlip(tilt: 0.5, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    FileHeading(text: tr("事件資料 · 真相", "Case file · The truth"))
                    Spacer()
                    Stamp(text: tr("解決", "CLOSED"))
                }
                Text(suspect.name)
                    .font(Theme.gothic(26, .heavy))
                    .foregroundStyle(Theme.fileInk)
                Text(c.finale.text.truth)
                    .font(Theme.body(15, .medium))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.fileInk)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Theme.fileRule).frame(height: 1)
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
                .font(Theme.board(22, .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.fileInk)
            FileHeading(text: label)
        }
    }
}
