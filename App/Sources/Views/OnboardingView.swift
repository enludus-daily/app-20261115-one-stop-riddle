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
            TrackBackground()
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 20)
                sampleLine
                    .frame(height: 70)
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: pages[page].eyebrow, color: Theme.deep)
                    Text(pages[page].title)
                        .font(Theme.serif(30, .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pages[page].body)
                        .font(.system(size: 15))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.sub)
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
                            Capsule().fill(i == page ? Theme.deep : Theme.line)
                                .frame(width: i == page ? 18 : 6, height: 6)
                        }
                    }
                    if page < pages.count - 1 {
                        Button { advance() } label: { PrimaryButtonLabel(title: tr("次へ", "Next")) }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("main.next")
                    } else {
                        Button { model.press(); model.onboarded = true } label: { PrimaryButtonLabel(title: tr("乗車する", "Board")) }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("main.start")
                    }
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
                Rectangle().fill(Theme.line).frame(height: Theme.rail)
                Rectangle().fill(Theme.deep).frame(width: step * CGFloat(trainAt), height: Theme.rail)
                ForEach(0..<4, id: \.self) { i in
                    StationDot(state: i < trainAt ? .onTime : (i == trainAt ? .next : .open), size: 18)
                        .offset(x: step * CGFloat(i) - 9)
                }
                TrainIcon(size: 26)
                    .offset(x: step * CGFloat(trainAt) - 10, y: -28)
            }
            .frame(height: geo.size.height)
        }
        .padding(.horizontal, 10)
        .accessibilityHidden(true)
    }
}
