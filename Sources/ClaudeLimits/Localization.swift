import Foundation

enum Language: String, CaseIterable {
    case auto, en, ru
}

/// UI strings for both languages.
///
/// A struct rather than a `.strings` file: there are a dozen phrases, and this way the compiler
/// refuses to build when a translation is missing — and the strings work under `swift run`, where
/// no app bundle exists to look resources up in.
struct Strings {
    let session: String
    let weeklyAll: String
    let scopedFallback: String
    let loading: String
    let errorPrefix: String
    let noToken: String
    let barsToggle: String
    let launchAtLogin: String
    let launchFailed: String
    let language: String
    let languageAuto: String
    let refresh: String
    let quit: String
    let hours: String
    let minutes: String
}

extension Strings {
    static let en = Strings(
        session: "Session",
        weeklyAll: "All models",
        scopedFallback: "Model",
        loading: "Loading…",
        errorPrefix: "Error",
        noToken: "Claude Code token not found",
        barsToggle: "Bars instead of numbers",
        launchAtLogin: "Launch at login",
        launchFailed: "Launch at login",
        language: "Language",
        languageAuto: "Automatic",
        refresh: "Refresh",
        quit: "Quit",
        hours: "h",
        minutes: "min"
    )

    static let ru = Strings(
        session: "Сессия",
        weeklyAll: "Все модели",
        scopedFallback: "Модель",
        loading: "Загрузка…",
        errorPrefix: "Ошибка",
        noToken: "Токен Claude Code не найден",
        barsToggle: "Полоски вместо цифр",
        launchAtLogin: "Запускать при входе",
        launchFailed: "Автозапуск",
        language: "Язык",
        languageAuto: "Автоматически",
        refresh: "Обновить",
        quit: "Выход",
        hours: "ч",
        minutes: "мин"
    )
}

enum L {
    static var preference: Language {
        get { Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .auto }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "language") }
    }

    /// The language actually in use. Under `.auto` this follows the system — including the per-app
    /// language macOS offers in Settings, which `preferredLocalizations` already accounts for.
    static var current: Language {
        if preference != .auto { return preference }
        let system = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        return system.hasPrefix("ru") ? .ru : .en
    }

    static var s: Strings {
        current == .ru ? .ru : .en
    }
}
