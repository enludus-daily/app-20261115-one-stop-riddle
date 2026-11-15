import AudioToolbox
import Foundation
import Observation
import SwiftUI

/// いま乗っている 1 駅
struct RideState: Equatable {
    var caseID: String
    var index: Int
    /// 解いた駅の解き直し（記録は変えない）
    var practice: Bool
    var startedAt: Date
    var hintsShown: Int = 0
    var wrong: Set<Int> = []
    var arrival: Arrival?
    /// 撮影用：経過秒を止めて見せる
    var frozenElapsed: Int?
}

enum Cover: Identifiable, Equatable {
    case ride
    case finale(String)
    var id: String {
        switch self {
        case .ride: "ride"
        case .finale(let c): "finale-" + c
        }
    }
}

enum PaywallReason: String, Equatable {
    case caseSolved, lockedStation, hint, settings
}

enum ActiveSheet: Identifiable, Equatable {
    case settings
    case paywall(PaywallReason)
    case share(String)
    var id: String {
        switch self {
        case .settings: "settings"
        case .paywall(let r): "paywall-" + r.rawValue
        case .share(let c): "share-" + c
        }
    }
}

@MainActor
@Observable
final class AppModel {
    // 保存する値
    var journey: Journey { didSet { save() } }
    var onboarded: Bool { didSet { defaults(set: onboarded, "onboarded") } }
    /// 一駅ごとに区切る（便ごとに新しい駅は 1 つ）。既定はオン
    var pacing: Bool { didSet { defaults(set: pacing, "pacing") } }
    /// 効果音（電車の中で鳴らないよう、既定はオフ）
    var soundOn: Bool { didSet { defaults(set: soundOn, "sound") } }
    var hapticsOn: Bool { didSet { defaults(set: hapticsOn, "haptics") } }
    /// 事件 1 を解いたあとの Pro の案内は 1 回だけ
    var paywallOffered: Bool { didSet { defaults(set: paywallOffered, "paywallOffered") } }

    // 画面の状態
    var ride: RideState?
    var cover: Cover?
    var activeSheet: ActiveSheet?
    var pendingPaywall = false
    var finaleWrong: Set<Int> = []
    var now: Date
    var frozen = false

    // 手応え（値が変わると振動）
    var pressTick = 0
    var correctTick = 0
    var onTimeTick = 0
    var wrongTick = 0
    var solvedTick = 0

    let purchases: PurchaseStore
    var proOverride = false
    var isPro: Bool { proOverride || purchases.entitlements.isPro }

    let persists: Bool
    let calendar = Calendar.current
    static let proID = ProductID.pro(bundleID: Bundle.main.bundleIdentifier ?? "com.enludus.daily.010")

    init(persists: Bool = true, now: Date = Date()) {
        self.persists = persists
        self.now = now
        let d = UserDefaults.standard
        if persists, let data = d.data(forKey: "journey"), let saved = try? JSONDecoder().decode(Journey.self, from: data) {
            journey = saved
        } else {
            journey = Journey()
        }
        onboarded = persists && d.bool(forKey: "onboarded")
        pacing = d.object(forKey: "pacing") as? Bool ?? true
        soundOn = d.bool(forKey: "sound")
        hapticsOn = d.object(forKey: "haptics") as? Bool ?? true
        paywallOffered = persists && d.bool(forKey: "paywallOffered")
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
    }

    private func save() {
        guard persists, let data = try? JSONEncoder().encode(journey) else { return }
        UserDefaults.standard.set(data, forKey: "journey")
    }

    private func defaults(set value: Bool, _ key: String) {
        guard persists else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - 今の事件

    var cases: [MysteryCase] { Library.cases }

    var current: MysteryCase {
        Library.mysteryCase(journey.selectedCase) ?? cases[0]
    }

    func select(_ c: MysteryCase) {
        guard c.id != journey.selectedCase else { return }
        press()
        journey.selectedCase = c.id
    }

    var currentDate: Date { frozen ? now : Date() }

    var canRide: Bool { journey.canRide(at: currentDate, calendar: calendar, pacing: pacing) }

    var slot: RideSlot { RideSlot.of(currentDate, calendar: calendar).slot }

    var nextOpening: Date { RideSlot.nextOpening(after: currentDate, calendar: calendar) }

    /// ホームの大きなボタンの中身
    enum NextAction: Equatable {
        case ride(Int), rest, locked(Int), finale, solved
    }

    var nextAction: NextAction {
        let c = current
        guard let next = journey.nextIndex(c) else {
            if journey.isCaseSolved(c) { return .solved }
            return journey.isFinaleLocked(c, isPro: isPro) ? .locked(c.stationCount) : .finale
        }
        if journey.isLocked(c, index: next, isPro: isPro) { return .locked(next) }
        return canRide ? .ride(next) : .rest
    }

    // MARK: - 乗る

    func startRide() {
        switch nextAction {
        case .ride(let i):
            press()
            ride = RideState(caseID: current.id, index: i, practice: false, startedAt: Date())
            cover = .ride
        case .locked:
            showPaywall(.lockedStation)
        case .finale:
            openFinale()
        case .rest, .solved:
            break
        }
    }

    /// 解いた駅をもう一度（練習。記録は変わらない）
    func practice(_ index: Int) {
        guard journey.arrival(current.id, index) != nil else { return }
        press()
        ride = RideState(caseID: current.id, index: index, practice: true, startedAt: Date())
        cover = .ride
    }

    var rideCase: MysteryCase? { ride.flatMap { Library.mysteryCase($0.caseID) } }
    var rideRiddle: Riddle? {
        guard let ride, let c = rideCase, c.riddles.indices.contains(ride.index) else { return nil }
        return c.riddles[ride.index]
    }

    func elapsed(at date: Date) -> Int {
        guard let ride else { return 0 }
        if let frozen = ride.frozenElapsed { return frozen }
        if let a = ride.arrival { return a.seconds }
        return max(0, Int(date.timeIntervalSince(ride.startedAt)))
    }

    /// 選択肢を選ぶ。当たれば true
    @discardableResult
    func choose(_ choice: Int) -> Bool {
        guard var r = ride, r.arrival == nil, let riddle = rideRiddle, !r.wrong.contains(choice) else { return false }
        if choice == riddle.answer {
            let arrival = Arrival(seconds: elapsed(at: Date()), hints: r.hintsShown, misses: r.wrong.count, date: currentDate)
            r.arrival = arrival
            ride = r
            if !r.practice {
                journey.record(arrival, caseID: r.caseID, index: r.index, calendar: calendar)
            }
            correctTick += 1
            if arrival.isOnTime { onTimeTick += 1 }
            play(1057)
            return true
        }
        r.wrong.insert(choice)
        ride = r
        wrongTick += 1
        play(1053)
        return false
    }

    /// ヒントは 3 段階。3 段目（答えの手前まで）は Pro
    func showHint() {
        guard var r = ride, r.arrival == nil, r.hintsShown < 3 else { return }
        if r.hintsShown == 2 && !isPro {
            showPaywall(.hint)
            return
        }
        press()
        r.hintsShown += 1
        ride = r
    }

    func closeRide() {
        press()
        cover = nil
        ride = nil
    }

    // MARK: - 終点

    func openFinale() {
        press()
        finaleWrong = []
        cover = .finale(current.id)
    }

    @discardableResult
    func chooseSuspect(_ choice: Int) -> Bool {
        let c = current
        guard !journey.isCaseSolved(c), !finaleWrong.contains(choice) else { return journey.isCaseSolved(c) }
        let solved = journey.chooseSuspect(choice, in: c)
        if solved {
            solvedTick += 1
            play(1057)
            if c.id == "c1" && !isPro && !paywallOffered { pendingPaywall = true }
        } else {
            finaleWrong.insert(choice)
            wrongTick += 1
            play(1053)
        }
        return solved
    }

    func closeFinale() {
        press()
        cover = nil
        if pendingPaywall {
            pendingPaywall = false
            paywallOffered = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                self.activeSheet = .paywall(.caseSolved)
            }
        }
    }

    // MARK: - そのほか

    func showPaywall(_ reason: PaywallReason) {
        press()
        if cover != nil {
            cover = nil
            ride = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self.activeSheet = .paywall(reason)
            }
        } else {
            activeSheet = .paywall(reason)
        }
    }

    func press() {
        pressTick += 1
        play(1104)
    }

    private func play(_ id: SystemSoundID) {
        guard soundOn else { return }
        AudioServicesPlaySystemSound(id)
    }

    func replayOnboarding() {
        activeSheet = nil
        onboarded = false
    }
}
