import SwiftUI

@main
struct OneStopRiddleApp: App {
    @State private var model = Launch.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    @State var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.onboarded {
                HomeView()
                    // 全画面の場面やシートを出している間は、下のホームを読み上げ・UI テストの対象から外す
                    .accessibilityHidden(model.cover != nil || model.activeSheet != nil)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: model.onboarded)
        .environment(model)
        // 淡いミントと細い線の路線図が主役。StudyReel と同じく画面はライトに固定する
        .preferredColorScheme(.light)
        .fullScreenCover(item: $model.cover) { cover in
            Group {
                switch cover {
                case .ride: RideView()
                case .finale(let id): FinaleView(caseID: id)
                }
            }
            .environment(model)
            .environment(\.locale, Lang.locale)
            .preferredColorScheme(.light)
            .accessibilityHidden(model.activeSheet != nil)
        }
        .sheet(item: $model.activeSheet) { sheet in
            Group {
                switch sheet {
                case .settings: SettingsView()
                case .paywall(let reason): PaywallView(reason: reason)
                case .share(let id): ShareView(caseID: id)
                }
            }
            .environment(model)
            .environment(\.locale, Lang.locale)
            .preferredColorScheme(.light)
        }
        // 手応えの表（README）：押す・正解・定刻・まちがい・事件解決
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.correctTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: model.onTimeTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.wrongTick) { _, _ in model.hapticsOn ? .error : nil }
        .sensoryFeedback(trigger: model.solvedTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !model.frozen { model.now = Date() }
        }
        .environment(\.locale, Lang.locale)
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    /// 撮影中は動きを最後の形で止めて撮る
    static var isStill: Bool { scene != nil }

    /// 撮影の時刻：今日の朝 7:50（朝の便）
    static func stageDate() -> Date {
        Calendar.current.date(bySettingHour: 7, minute: 50, second: 0, of: Date()) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["journey", "onboarded", "pacing", "sound", "haptics", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            return AppModel()
        }
        guard isDemo || scene != nil else { return AppModel() }
        let now = stageDate()
        let model = AppModel(persists: false, now: now)
        model.frozen = true
        // 撮影・デモでは Pro の案内を自動で出さない（案内の画面は paywall の場面で撮る）
        model.paywallOffered = true
        model.onboarded = scene != "onboarding"
        if scene != "fresh" && scene != "onboarding" {
            model.journey = samples(now: now, calendar: model.calendar)
        }
        switch scene {
        case "locked":
            model.journey.selectedCase = "c2"
            for i in 0..<3 { model.journey.arrivals[Journey.key("c2", i)] = arrival(now, -3 + i, seconds: 70 + i * 25, hints: i == 1 ? 1 : 0) }
        case "case3":
            model.proOverride = true
            model.journey.selectedCase = "c3"
            for i in 0..<5 { model.journey.arrivals[Journey.key("c3", i)] = arrival(now, -5 + i, seconds: 60 + i * 20, hints: i == 3 ? 2 : 0) }
        case "finale", "truth", "share":
            for i in 4..<10 { model.journey.arrivals[Journey.key("c1", i)] = arrival(now, -10 + i, seconds: 65 + i * 9, hints: i == 7 ? 1 : 0) }
            if scene != "finale" { model.journey.finales["c1"] = FinaleRecord(tries: scene == "truth" ? 2 : 1, solved: true) }
        default:
            break
        }
        return model
    }

    /// 見本の記録：事件 1 の 4 駅（おととい・きのうの朝と夕）
    static func samples(now: Date, calendar: Calendar) -> Journey {
        var j = Journey()
        let plan: [(day: Int, hour: Int, seconds: Int, hints: Int, misses: Int)] = [
            (-2, 8, 84, 0, 0), (-2, 18, 151, 1, 0), (-1, 8, 96, 0, 0), (-1, 19, 70, 0, 0),
        ]
        for (i, p) in plan.enumerated() {
            let day = calendar.date(byAdding: .day, value: p.day, to: now) ?? now
            let date = calendar.date(bySettingHour: p.hour, minute: 5, second: 0, of: day) ?? day
            j.record(Arrival(seconds: p.seconds, hints: p.hints, misses: p.misses, date: date), caseID: "c1", index: i, calendar: calendar)
        }
        return j
    }

    private static func arrival(_ now: Date, _ dayOffset: Int, seconds: Int, hints: Int) -> Arrival {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) ?? now
        return Arrival(seconds: seconds, hints: hints, misses: 0, date: date)
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(300))
        switch scene {
        case "ride", "hint", "wrong", "arrival", "late":
            model.startRide()
            guard var r = model.ride else { return }
            switch scene {
            case "ride": r.frozenElapsed = 47
            case "hint": r.frozenElapsed = 95; r.hintsShown = 2
            case "wrong": r.frozenElapsed = 63; r.wrong = [0]
            default: break
            }
            model.ride = r
            if scene == "arrival" || scene == "late" {
                if scene == "late" { model.ride?.hintsShown = 1; model.ride?.wrong = [0] }
                model.ride?.frozenElapsed = scene == "late" ? 164 : 78
                model.choose(model.rideRiddle?.answer ?? 0)
            }
        case "practice":
            model.practice(1)
            model.ride?.frozenElapsed = 31
        case "rest":
            model.startRide()
            model.ride?.frozenElapsed = 88
            model.choose(model.rideRiddle?.answer ?? 0)
            model.closeRide()
        case "finale":
            model.openFinale()
        case "truth":
            model.openFinale()
        case "share":
            model.activeSheet = .share("c1")
        case "settings":
            model.activeSheet = .settings
        case "paywall":
            model.activeSheet = .paywall(.caseSolved)
        default:
            break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 見本の路線図 → 次の駅へ → ヒント → まちがい → 正解（改札のパンチ・定刻/遅れ・物語の場面）→ 路線図にもどる → 共有
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        await wait(2.2)
        model.startRide()
        await wait(3.2)
        model.showHint()
        await wait(2.2)
        model.choose(0)
        await wait(1.6)
        model.choose(model.rideRiddle?.answer ?? 1)
        await wait(5.0)
        model.closeRide()
        await wait(2.2)
        model.activeSheet = .share(model.current.id)
    }
}
