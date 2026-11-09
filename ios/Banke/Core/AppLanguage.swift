import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, ja, ko
    case simplifiedChinese = "zh-Hans", traditionalChinese = "zh-Hant"
    case es, brazilianPortuguese = "pt-BR", fr, de
    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .en: "English"
        case .ja: "日本語"
        case .ko: "한국어"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .es: "Español"
        case .brazilianPortuguese: "Português (Brasil)"
        case .fr: "Français"
        case .de: "Deutsch"
        }
    }
    var voiceDirectory: String { self == .traditionalChinese ? "zh-Hans" : rawValue }
    var speechLocale: String {
        switch self {
        case .en: "en-US"
        case .ja: "ja-JP"
        case .ko: "ko-KR"
        case .simplifiedChinese: "zh-CN"
        case .traditionalChinese: "zh-TW"
        case .es: "es-MX"
        case .brazilianPortuguese: "pt-BR"
        case .fr: "fr-FR"
        case .de: "de-DE"
        }
    }
    static func resolve(preference: String, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        if let explicit = AppLanguage(rawValue: preference) { return explicit }
        let match = Bundle.preferredLocalizations(from: allCases.map(\.rawValue), forPreferences: preferredLanguages).first ?? "en"
        return AppLanguage(rawValue: match) ?? .en
    }
}

/// Dynamic strings and notifications use the same selected locale as SwiftUI.
/// App Store prices remain in the Apple Account's storefront currency.
enum L10n {
    static let preferenceKey = "banke.language"
    static var language: AppLanguage {
        AppLanguage.resolve(preference: UserDefaults.standard.string(forKey: preferenceKey) ?? "system")
    }
    static var locale: Locale { Locale(identifier: language.rawValue) }
    static func text(_ key: String, _ args: CVarArg...) -> String {
        translate(key, language: language, args: args)
    }
    static func translate(_ key: String, language: AppLanguage, bundle: Bundle = .main, args: [CVarArg] = []) -> String {
        let localized = bundle.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        let format = localized.localizedString(forKey: key, value: key, table: "Localizable")
        return args.isEmpty ? format : String(format: format, locale: Locale(identifier: language.rawValue), arguments: args)
    }
    static func voice(_ cue: String, companion: Companion) -> String {
        text(cue == "greeting" ? "voice.greeting.\(companion.rawValue)" : "voice.\(cue)")
    }
}
