import Foundation

// 乗車の記録と決まり（画面から切り離してテストする）。
// 1 回の乗車（朝の便・夕の便）で新しい駅は 1 つまで。平日 5 日 × 2 ＝ 10 駅で 1 つの事件になる。

/// 朝の便（4:00〜14:59）と夕の便（15:00〜翌 3:59）
enum RideSlot: String, Codable, Sendable {
    case morning, evening

    static let eveningStartHour = 15
    static let dayStartHour = 4

    /// その時刻が属する便と、便の日（深夜 0〜3 時は前の日の夕の便）
    static func of(_ date: Date, calendar: Calendar) -> (day: Date, slot: RideSlot) {
        let hour = calendar.component(.hour, from: date)
        let today = calendar.startOfDay(for: date)
        if hour < dayStartHour {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return (yesterday, .evening)
        }
        return (today, hour < eveningStartHour ? .morning : .evening)
    }

    static func key(_ date: Date, calendar: Calendar) -> String {
        let (day, slot) = of(date, calendar: calendar)
        return dayKey(day, calendar: calendar) + "-" + slot.rawValue
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 次の便が始まる時刻
    static func nextOpening(after date: Date, calendar: Calendar) -> Date {
        let (day, slot) = of(date, calendar: calendar)
        switch slot {
        case .morning:
            return calendar.date(bySettingHour: eveningStartHour, minute: 0, second: 0, of: day) ?? date
        case .evening:
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: next) ?? date
        }
    }

    var label: String {
        switch self {
        case .morning: tr("朝の便", "Morning ride")
        case .evening: tr("夕の便", "Evening ride")
        }
    }
}

/// 1 駅を解いた記録
struct Arrival: Codable, Equatable, Sendable {
    /// 2 分で着けば定刻
    static let targetSeconds = 120

    var seconds: Int
    var hints: Int
    var misses: Int
    var date: Date

    /// 2 分以内・ヒントなし・まちがいなし
    var isOnTime: Bool { seconds <= Self.targetSeconds && hints == 0 && misses == 0 }

    /// 遅れ（分）。2 分を過ぎた分（切り上げ）＋ヒント 1 つにつき 1 分＋まちがい 1 つにつき 1 分。定刻でなければ最低 1 分
    var delayMinutes: Int {
        if isOnTime { return 0 }
        let over = max(0, seconds - Self.targetSeconds)
        let overMinutes = (over + 59) / 60
        return max(1, overMinutes + hints + misses)
    }
}

struct FinaleRecord: Codable, Equatable, Sendable {
    var tries: Int = 0
    var solved: Bool = false
}

/// 乗車の記録（端末の中の UserDefaults に保存）
struct Journey: Codable, Equatable, Sendable {
    var arrivals: [String: Arrival] = [:]
    var finales: [String: FinaleRecord] = [:]
    /// 便のキー（2026-11-15-morning）→ その便で解いた駅
    var rides: [String: String] = [:]
    var selectedCase: String = "c1"

    static func key(_ caseID: String, _ index: Int) -> String { "\(caseID)-\(index)" }

    func arrival(_ caseID: String, _ index: Int) -> Arrival? { arrivals[Self.key(caseID, index)] }

    func solvedCount(_ c: MysteryCase) -> Int {
        (0..<c.stationCount).filter { arrival(c.id, $0) != nil }.count
    }

    func onTimeCount(_ c: MysteryCase) -> Int {
        (0..<c.stationCount).filter { arrival(c.id, $0)?.isOnTime == true }.count
    }

    /// まだ解いていない最初の駅。全部解いていれば nil（終点へ）
    func nextIndex(_ c: MysteryCase) -> Int? {
        (0..<c.stationCount).first { arrival(c.id, $0) == nil }
    }

    func isLocked(_ c: MysteryCase, index: Int, isPro: Bool) -> Bool {
        !isPro && index >= c.free
    }

    func isFinaleLocked(_ c: MysteryCase, isPro: Bool) -> Bool {
        !isPro && c.free < c.stationCount
    }

    func isCaseSolved(_ c: MysteryCase) -> Bool { finales[c.id]?.solved == true }

    /// 一駅ごとに区切る（既定）ときは、便ごとに新しい駅は 1 つまで
    func canRide(at date: Date, calendar: Calendar, pacing: Bool) -> Bool {
        !pacing || rides[RideSlot.key(date, calendar: calendar)] == nil
    }

    /// 解いた駅を記録する。最初に解いたときだけ記録し、その便を使ったことにする
    mutating func record(_ arrival: Arrival, caseID: String, index: Int, calendar: Calendar) {
        let key = Self.key(caseID, index)
        guard arrivals[key] == nil else { return }
        arrivals[key] = arrival
        let slot = RideSlot.key(arrival.date, calendar: calendar)
        if rides[slot] == nil { rides[slot] = key }
    }

    /// 終点で真相を選ぶ。当たれば true
    mutating func chooseSuspect(_ choice: Int, in c: MysteryCase) -> Bool {
        var record = finales[c.id] ?? FinaleRecord()
        guard !record.solved else { return true }
        record.tries += 1
        record.solved = choice == c.finale.answer
        finales[c.id] = record
        return record.solved
    }

    /// 開いた手がかり（駅の順）
    func clues(_ c: MysteryCase) -> [(index: Int, text: String)] {
        (0..<c.stationCount).compactMap { i in
            arrival(c.id, i) == nil ? nil : (i, c.riddles[i].text.clue)
        }
    }

    /// 乗った日が続いている日数（今日か昨日まで続いていれば数える）
    func streak(at date: Date, calendar: Calendar) -> Int {
        let days = Set(arrivals.values.map { RideSlot.dayKey(RideSlot.of($0.date, calendar: calendar).day, calendar: calendar) })
        var day = RideSlot.of(date, calendar: calendar).day
        if !days.contains(RideSlot.dayKey(day, calendar: calendar)) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while days.contains(RideSlot.dayKey(day, calendar: calendar)) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    /// 定刻率（0〜1）。まだ解いていなければ nil
    var onTimeRate: Double? {
        guard !arrivals.isEmpty else { return nil }
        return Double(arrivals.values.filter(\.isOnTime).count) / Double(arrivals.count)
    }

    var totalSolved: Int { arrivals.count }

    /// 駅ごとの最短（Pro の記録）
    func fastestSeconds(_ c: MysteryCase) -> Int? {
        (0..<c.stationCount).compactMap { arrival(c.id, $0)?.seconds }.min()
    }
}
