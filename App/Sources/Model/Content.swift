import Foundation

// 事件と謎（手で用意したデータ。App/Resources/Cases.json。元は scripts/build-cases.py）。
// 日本語と英語は別々に作ってある（言葉遊びは言語ごとに別の問題）。

struct CaseFile: Decodable, Sendable {
    let cases: [MysteryCase]
}

/// 1 つの事件＝1 本の路線（10 駅＋終点）
struct MysteryCase: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    /// 路線の記号（M・Y・K）
    let mark: String
    /// 無料で乗れる駅の数（事件 1 は 10、事件 2・3 は 3）
    let free: Int
    let ja: CaseText
    let en: CaseText
    let riddles: [Riddle]
    let finale: Finale

    var text: CaseText { Lang.isJapanese ? ja : en }
    var stationCount: Int { riddles.count }

    static func == (lhs: MysteryCase, rhs: MysteryCase) -> Bool { lhs.id == rhs.id }
}

struct CaseText: Decodable, Sendable {
    let line: String
    let title: String
    let intro: String
    let stations: [String]
    let terminal: String
}

enum RiddleKind: String, Decodable, Sendable, CaseIterable {
    case pattern, cipher, logic, insight, map, figure

    var label: String {
        switch self {
        case .pattern: tr("きまり", "Pattern")
        case .cipher: tr("暗号", "Cipher")
        case .logic: tr("論理", "Logic")
        case .insight: tr("ひらめき", "Insight")
        case .map: tr("路線図", "Map")
        case .figure: tr("図形", "Figure")
        }
    }
}

struct Riddle: Decodable, Sendable {
    let kind: RiddleKind
    /// 正解の選択肢の番号（日本語と英語で同じ並び）
    let answer: Int
    let ja: RiddleText
    let en: RiddleText

    var text: RiddleText { Lang.isJapanese ? ja : en }
}

struct RiddleText: Decodable, Sendable {
    let q: String
    let choices: [String]
    let hints: [String]
    let why: String
    /// 解いたあとに開く物語の場面
    let scene: String
    /// 手がかり（終点で真相を選ぶときに並ぶ短い文）
    let clue: String
    /// 発車標の札（図・暗号）。空なら札を出さない
    let figure: [String]
}

struct Finale: Decodable, Sendable {
    let answer: Int
    let ja: FinaleText
    let en: FinaleText

    var text: FinaleText { Lang.isJapanese ? ja : en }
}

struct FinaleText: Decodable, Sendable {
    let q: String
    let suspects: [Suspect]
    let truth: String
}

struct Suspect: Decodable, Sendable {
    let name: String
    let note: String
}

enum Library {
    static let cases: [MysteryCase] = load()

    static func load(bundle: Bundle = .main) -> [MysteryCase] {
        guard let url = bundle.url(forResource: "Cases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CaseFile.self, from: data) else { return [] }
        return file.cases
    }

    static func mysteryCase(_ id: String) -> MysteryCase? { cases.first { $0.id == id } }
}
