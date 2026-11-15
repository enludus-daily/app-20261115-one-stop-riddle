import Foundation

/// 画面の言葉。日本語が元の言葉で、英語は String Catalog（App/Resources/Localizable.xcstrings）から読む。
/// カタログは scripts/gen-strings.py が tr("日本語", "English") から作る（英語の抜けがあると止まる）。
/// 撮影で日本語の画面を撮るとき（-screenshotScene <名前>_ja）は、端末の言語に関係なく日本語にする。
enum Lang {
    nonisolated(unsafe) static var forcedJapanese = false

    static var isJapanese: Bool {
        forcedJapanese || (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")
    }

    static var locale: Locale { Locale(identifier: isJapanese ? "ja_JP" : "en_US") }

    /// 英語の表（en.lproj）。見つからなければ、コードに並べた英語を使う
    nonisolated(unsafe) static let english: Bundle? = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
}

/// 日本語と英語。英語はカタログを先に見る（カタログを直せば、コードを触らずに言い回しを変えられる）
func tr(_ ja: String, _ en: String) -> String {
    if Lang.isJapanese { return ja }
    guard let bundle = Lang.english else { return en }
    let found = bundle.localizedString(forKey: ja, value: nil, table: "Localizable")
    return found == ja ? en : found
}

/// 数などを差し込む言葉（%d・%@）
func trf(_ ja: String, _ en: String, _ args: CVarArg...) -> String {
    String(format: tr(ja, en), locale: Lang.locale, arguments: args)
}
