import Foundation
import Testing
@testable import OneStopRiddle

/// 手で用意した事件と謎のデータ
struct ContentTests {
    // テストはアプリの中で動くので、Bundle.main がアプリ
    let cases = Library.cases

    @Test func threeCasesOfTenStops() {
        #expect(cases.count == 3)
        for c in cases {
            #expect(c.riddles.count == 10)
            #expect(c.ja.stations.count == 10)
            #expect(c.en.stations.count == 10)
        }
    }

    @Test func everyRiddleIsComplete() {
        for c in cases {
            for (i, r) in c.riddles.enumerated() {
                for t in [r.ja, r.en] {
                    #expect(t.choices.count == 4, "\(c.id)-\(i)")
                    #expect(Set(t.choices).count == 4, "\(c.id)-\(i) の選択肢が重なっている")
                    #expect(t.hints.count == 3, "\(c.id)-\(i)")
                    #expect(!t.q.isEmpty && !t.why.isEmpty && !t.scene.isEmpty && !t.clue.isEmpty, "\(c.id)-\(i)")
                }
                #expect((0..<4).contains(r.answer), "\(c.id)-\(i)")
            }
            #expect(c.finale.ja.suspects.count == 4)
            #expect(c.finale.en.suspects.count == 4)
            #expect((0..<4).contains(c.finale.answer))
        }
    }

    @Test func englishHasNoJapaneseLeft() {
        let japanese = try! Regex("[ぁ-ヿ一-鿿]")
        for c in cases {
            let texts = [c.en.line, c.en.title, c.en.intro, c.en.terminal, c.finale.en.q, c.finale.en.truth] + c.en.stations
                + c.riddles.flatMap { [$0.en.q, $0.en.why, $0.en.scene, $0.en.clue] + $0.en.choices + $0.en.hints + $0.en.figure }
                + c.finale.en.suspects.flatMap { [$0.name, $0.note] }
            for t in texts { #expect(t.firstMatch(of: japanese) == nil, "\(c.id): \(t)") }
        }
    }

    @Test func kindsAreMixedInEveryCase() {
        for c in cases { #expect(Set(c.riddles.map(\.kind)).count >= 5, "\(c.id)") }
    }

    @Test func caseOneIsFreeAndOthersOpenThreeStops() {
        #expect(cases.map(\.free) == [10, 3, 3])
    }
}

/// 便（朝・夕）の決まり
struct RideSlotTests {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func morningAndEvening() {
        #expect(RideSlot.of(at(16, 7), calendar: cal).slot == .morning)
        #expect(RideSlot.of(at(16, 14, 59), calendar: cal).slot == .morning)
        #expect(RideSlot.of(at(16, 15), calendar: cal).slot == .evening)
    }

    @Test func lateNightBelongsToTheEveningBefore() {
        #expect(RideSlot.key(at(17, 1), calendar: cal) == "2026-11-16-evening")
        #expect(RideSlot.key(at(17, 4), calendar: cal) == "2026-11-17-morning")
    }

    @Test func nextOpening() {
        #expect(RideSlot.nextOpening(after: at(16, 8), calendar: cal) == at(16, 15))
        #expect(RideSlot.nextOpening(after: at(16, 20), calendar: cal) == at(17, 4))
        #expect(RideSlot.nextOpening(after: at(17, 2), calendar: cal) == at(17, 4))
    }
}

/// 乗車の記録
struct JourneyTests {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    func at(_ day: Int, _ hour: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))! }
    let c1 = ContentTests().cases[0]
    let c2 = ContentTests().cases[1]

    @Test func onTimeNeedsTwoMinutesNoHintsNoMisses() {
        #expect(Arrival(seconds: 120, hints: 0, misses: 0, date: .now).isOnTime)
        #expect(!Arrival(seconds: 121, hints: 0, misses: 0, date: .now).isOnTime)
        #expect(!Arrival(seconds: 30, hints: 1, misses: 0, date: .now).isOnTime)
        #expect(!Arrival(seconds: 30, hints: 0, misses: 1, date: .now).isOnTime)
    }

    @Test func delayCountsOvertimeHintsAndMisses() {
        #expect(Arrival(seconds: 100, hints: 0, misses: 0, date: .now).delayMinutes == 0)
        #expect(Arrival(seconds: 121, hints: 0, misses: 0, date: .now).delayMinutes == 1)
        #expect(Arrival(seconds: 200, hints: 2, misses: 1, date: .now).delayMinutes == 5)
        #expect(Arrival(seconds: 10, hints: 1, misses: 0, date: .now).delayMinutes == 1)
    }

    @Test func oneNewStopPerRideWhenPacing() {
        var j = Journey()
        #expect(j.canRide(at: at(16, 8), calendar: cal, pacing: true))
        j.record(Arrival(seconds: 60, hints: 0, misses: 0, date: at(16, 8)), caseID: "c1", index: 0, calendar: cal)
        #expect(!j.canRide(at: at(16, 9), calendar: cal, pacing: true))
        #expect(j.canRide(at: at(16, 9), calendar: cal, pacing: false))
        #expect(j.canRide(at: at(16, 15), calendar: cal, pacing: true))
    }

    @Test func nextIndexAdvancesAndRecordsOnlyOnce() {
        var j = Journey()
        #expect(j.nextIndex(c1) == 0)
        let first = Arrival(seconds: 60, hints: 0, misses: 0, date: at(16, 8))
        j.record(first, caseID: "c1", index: 0, calendar: cal)
        j.record(Arrival(seconds: 300, hints: 3, misses: 2, date: at(16, 18)), caseID: "c1", index: 0, calendar: cal)
        #expect(j.arrival("c1", 0) == first)
        #expect(j.nextIndex(c1) == 1)
        #expect(j.solvedCount(c1) == 1)
        #expect(j.rides.count == 1)
    }

    @Test func freeStopsAndProLocks() {
        let j = Journey()
        #expect(!j.isLocked(c1, index: 9, isPro: false))
        #expect(!j.isLocked(c2, index: 2, isPro: false))
        #expect(j.isLocked(c2, index: 3, isPro: false))
        #expect(!j.isLocked(c2, index: 3, isPro: true))
        #expect(!j.isFinaleLocked(c1, isPro: false))
        #expect(j.isFinaleLocked(c2, isPro: false))
    }

    @Test func finaleCountsTriesUntilSolved() {
        var j = Journey()
        let first = j.chooseSuspect(0, in: c1)
        let second = j.chooseSuspect(c1.finale.answer, in: c1)
        #expect(!first)
        #expect(second)
        #expect(j.finales["c1"] == FinaleRecord(tries: 2, solved: true))
        let again = j.chooseSuspect(3, in: c1)
        #expect(again)
        #expect(j.finales["c1"]?.tries == 2)
    }

    @Test func streakCountsConsecutiveDays() {
        var j = Journey()
        for (i, d) in [13, 14, 15].enumerated() {
            j.record(Arrival(seconds: 60, hints: 0, misses: 0, date: at(d, 8)), caseID: "c1", index: i, calendar: cal)
        }
        #expect(j.streak(at: at(15, 20), calendar: cal) == 3)
        #expect(j.streak(at: at(16, 8), calendar: cal) == 3)   // 今日まだ乗っていなくても、昨日まで続いていれば
        #expect(j.streak(at: at(17, 8), calendar: cal) == 0)
    }

    @Test func cluesFollowSolvedStops() {
        var j = Journey()
        j.record(Arrival(seconds: 60, hints: 0, misses: 0, date: at(16, 8)), caseID: "c1", index: 2, calendar: cal)
        #expect(j.clues(c1).map(\.index) == [2])
    }

    @Test func onTimeRate() {
        var j = Journey()
        #expect(j.onTimeRate == nil)
        j.record(Arrival(seconds: 60, hints: 0, misses: 0, date: at(16, 8)), caseID: "c1", index: 0, calendar: cal)
        j.record(Arrival(seconds: 60, hints: 1, misses: 0, date: at(16, 18)), caseID: "c1", index: 1, calendar: cal)
        #expect(j.onTimeRate == 0.5)
        #expect(j.fastestSeconds(c1) == 60)
    }
}
