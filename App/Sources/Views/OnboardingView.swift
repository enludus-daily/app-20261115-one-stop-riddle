import SwiftUI

/// 最初の案内（3 ページ）。動く見本：電車が駅から駅へ 1 つずつ進む（1 回だけの動き）
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var trainAt = 0

    private var pages: [(eyebrow: String, title: String, body: String)] {
        [
            (tr("一駅で、ひとつの謎", "One stop, one riddle"),
             tr("だらだらスマホの代わりに、一駅 2 分の謎。", "Swap the endless scroll for a two-minute riddle."),
             tr("暗号・図形・論理・ひらめき・路線図。選んで押すだけ、片手で解けます。", "Ciphers, figures, logic, insight and maps. Just tap an answer—one hand is enough.")),
            (tr("1 週間で 1 つの事件", "One case a week"),
             tr("解くたびに、物語がひと駅進む。", "Every answer moves the story one stop."),
             tr("朝の便と夕の便に 1 駅ずつ。10 駅で手がかりがそろい、終点で真相を選びます。", "One stop each morning and evening. Ten stops gather the clues; at the terminus, you name the truth.")),
            (tr("音なし・通信なし", "Silent and offline"),
             tr("電車の中でも、そっと。", "Quiet enough for any train."),
             tr("効果音は最初からオフ。通信せず、記録はこの iPhone の中だけに残ります。", "Sound is off by default. No network—your records stay on this iPhone.")),
        ]
    }

    var body: some View {
        ZStack {
            NightBackground()
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 20)
                boardSign
                sampleLine
                    .frame(height: 70)
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: pages[page].eyebrow, color: Theme.led)
                    Text(pages[page].title)
                        .font(Theme.gothic(32, .heavy))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pages[page].body)
                        .font(Theme.body(15))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .id(page)
                .transition(.opacity)
                Spacer()
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 560)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1).fill(i == page ? Theme.led : Theme.rule)
                                .frame(width: i == page ? 22 : 8, height: 4)
                        }
                    }
                    // 1 つのボタンを使い回す（差し替えると、UI テストで切り替えの途中を押せない判定になる）
                    let last = page >= pages.count - 1
                    Button {
                        if last { model.press(); model.onboarded = true } else { advance() }
                    } label: {
                        PrimaryButtonLabel(title: last ? tr("乗車する", "Board") : tr("次へ", "Next"))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier(last ? "main.start" : "main.next")
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
            }
        }
        .onAppear { moveTrain(to: 1) }
    }

    private func advance() {
        model.press()
        withAnimation(.easeOut(duration: 0.25)) { page += 1 }
        moveTrain(to: page + 1)
    }

    private func moveTrain(to stop: Int) {
        if reduceMotion || Launch.isStill { trainAt = stop; return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.3)) { trainAt = stop }
    }

    /// 見本の路線：4 駅。電車がページに合わせて進み、通った駅が満ちる
    private var sampleLine: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let step = w / 3
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.line("M").opacity(0.22)).frame(height: Theme.rail)
                Rectangle().fill(Theme.line("M")).frame(width: step * CGFloat(trainAt), height: Theme.rail)
                ForEach(0..<4, id: \.self) { i in
                    StationDot(state: i < trainAt ? .onTime : (i == trainAt ? .next : .open), mark: "M", size: 20)
                        .offset(x: step * CGFloat(i) - 10)
                }
                TrainIcon(size: 28, mark: "M")
                    .offset(x: step * CGFloat(trainAt) - 11, y: -30)
            }
            .frame(height: geo.size.height)
        }
        .padding(.horizontal, 10)
        .accessibilityHidden(true)
    }

    /// 発車標の 1 行：「次は 2分 なぞ」。ページごとに行き先が変わる
    private var boardSign: some View {
        let rows: [(String, String)] = [
            (tr("各停", "LOCAL"), tr("次は ひと駅 2分", "NEXT  1 STOP  2 MIN")),
            (tr("平日", "WEEKDAY"), tr("10駅で 終点・真相", "10 STOPS → THE TRUTH")),
            (tr("消音", "SILENT"), tr("通信なし 記録は端末に", "OFFLINE  ON-DEVICE")),
        ]
        let row = rows[min(page, rows.count - 1)]
        return HStack(spacing: 10) {
            Text(row.0)
                .font(Theme.label(10))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.line("M"))
            Text(row.1)
                .font(Theme.board(15, .heavy))
                .foregroundStyle(Theme.led)
                .shadow(color: Theme.glow, radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .id(page)
                .transition(.opacity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(Theme.board))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).strokeBorder(Theme.rule, lineWidth: 1.5))
        .accessibilityHidden(true)
    }
}
