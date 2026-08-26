import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var timer: Timer?

    private var rows: [LimitRow] = []
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu

        render()
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    @objc func refresh() {
        UsageAPI.fetch { result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let rows):
                    self.rows = rows
                    self.lastError = nil
                case .failure(let message):
                    self.lastError = message
                }
                self.render()
            }
        }
    }

    nonisolated static func title(for row: LimitRow) -> String {
        switch row.kind {
        case "session": return L.s.session
        case "weekly_all": return L.s.weeklyAll
        default: return modelName(row.scopeName)
        }
    }

    /// The API reports the model without its version; the product is Fable 5.
    /// Any other name is passed through untouched.
    nonisolated static func modelName(_ scopeName: String?) -> String {
        guard let scopeName else { return L.s.scopedFallback }
        return scopeName == "Fable" ? "Fable 5" : scopeName
    }

    /// Language names stay in their own language; only "Automatic" is translated.
    nonisolated static func displayName(for language: Language) -> String {
        switch language {
        case .auto: return L.s.languageAuto
        case .en: return "English"
        case .ru: return "Русский"
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = Language(rawValue: raw)
        else { return }
        L.preference = language
        render()
    }

    private var showsBars: Bool {
        get { UserDefaults.standard.bool(forKey: "showsBars") }
        set { UserDefaults.standard.set(newValue, forKey: "showsBars") }
    }

    @objc private func toggleBars() {
        showsBars.toggle()
        render()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            lastError = "\(L.s.launchFailed): \(error.localizedDescription)"
        }
        render()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Rendering

    private func render() {
        // Bars and numbers are two ways of showing the same three limits — never both at once.
        statusItem.button?.attributedTitle = showsBars ? NSAttributedString() : statusTitle()
        statusItem.button?.image = barsImage()
        statusItem.button?.imagePosition = showsBars ? .imageOnly : .noImage

        menu.removeAllItems()

        if let lastError {
            menu.addItem(disabledItem("\(L.s.errorPrefix): \(lastError)"))
        }

        for row in rows {
            let reset = Self.remaining(until: row.resetsAt)
            let suffix = reset.isEmpty ? "" : " · \(reset)"
            menu.addItem(disabledItem("\(Self.title(for: row)) — \(row.percent)%\(suffix)"))

            let bar = disabledItem("")
            bar.image = Self.progressBarImage(percent: row.percent, severity: row.severity)
            menu.addItem(bar)
        }

        if rows.isEmpty && lastError == nil {
            menu.addItem(disabledItem(L.s.loading))
        }

        menu.addItem(.separator())

        let barsItem = menu.addItem(
            withTitle: L.s.barsToggle,
            action: #selector(toggleBars),
            keyEquivalent: ""
        )
        barsItem.target = self
        barsItem.state = showsBars ? .on : .off

        let launchItem = menu.addItem(
            withTitle: L.s.launchAtLogin,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let languageItem = menu.addItem(withTitle: L.s.language, action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in Language.allCases {
            let item = languageMenu.addItem(
                withTitle: Self.displayName(for: language),
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            item.state = L.preference == language ? .on : .off
        }
        languageItem.submenu = languageMenu

        menu.addItem(.separator())
        menu.addItem(withTitle: L.s.refresh, action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(withTitle: L.s.quit, action: #selector(quit), keyEquivalent: "q").target = self
    }

    /// Three progress bars shown in place of the numbers. `nil` when the numbers are shown.
    ///
    /// Drawing runs inside the button's own appearance — dynamic colors resolved in a bare
    /// `NSImage` handler ignore the menu bar's vibrancy and come out inverted.
    private func barsImage() -> NSImage? {
        guard showsBars, !rows.isEmpty else { return nil }

        let barWidth: CGFloat = 3.5
        let gap: CGFloat = 3
        let height: CGFloat = 14
        let width = barWidth * CGFloat(rows.count) + gap * CGFloat(rows.count - 1)
        let bars = rows.map { (percent: CGFloat($0.percent), severity: $0.severity) }
        let appearance = statusItem.button?.effectiveAppearance ?? NSAppearance.currentDrawing()

        return NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            appearance.performAsCurrentDrawingAppearance {
                var x: CGFloat = 0
                let radius = barWidth / 2

                for bar in bars {
                    // Track and fill share one paint so they can never resolve to inverted colors.
                    let paint = Self.color(for: bar.severity)

                    paint.withAlphaComponent(0.28).setFill()
                    NSBezierPath(
                        roundedRect: NSRect(x: x, y: 0, width: barWidth, height: height),
                        xRadius: radius, yRadius: radius
                    ).fill()

                    paint.setFill()
                    NSBezierPath(
                        roundedRect: NSRect(x: x, y: 0, width: barWidth, height: max(barWidth, height * bar.percent / 100)),
                        xRadius: radius, yRadius: radius
                    ).fill()

                    x += barWidth + gap
                }
            }
            return true
        }
    }

    private func statusTitle() -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        guard !rows.isEmpty else {
            return NSAttributedString(string: "—", attributes: [.font: font])
        }

        let title = NSMutableAttributedString()
        for (index, row) in rows.enumerated() {
            if index > 0 {
                title.append(NSAttributedString(
                    string: " · ",
                    attributes: [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
                ))
            }
            title.append(NSAttributedString(
                string: "\(row.percent)",
                attributes: [.font: font, .foregroundColor: Self.color(for: row.severity)]
            ))
        }
        return title
    }

    /// Wide progress bar shown under a limit's row in the menu.
    nonisolated static func progressBarImage(percent: Int, severity: String) -> NSImage {
        let width: CGFloat = 210
        let height: CGFloat = 5
        let radius = height / 2
        let paint = progressColor(for: severity)

        return NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            // Fixed gray track: it stays readable on both light and dark menus without
            // depending on how a dynamic color resolves inside an image handler.
            NSColor(white: 0.5, alpha: 0.3).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
                xRadius: radius, yRadius: radius
            ).fill()

            paint.setFill()
            NSBezierPath(
                roundedRect: NSRect(x: 0, y: 0, width: max(height, width * CGFloat(percent) / 100), height: height),
                xRadius: radius, yRadius: radius
            ).fill()
            return true
        }
    }

    nonisolated static func progressColor(for severity: String) -> NSColor {
        switch severity {
        case "warning": return .systemOrange
        case "critical": return .systemRed
        default: return .controlAccentColor
        }
    }

    /// `.labelColor` keeps the default numbers legible on both light and dark menu bars.
    nonisolated static func color(for severity: String) -> NSColor {
        switch severity {
        case "warning": return .systemOrange
        case "critical": return .systemRed
        default: return .labelColor
        }
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    nonisolated static func remaining(until date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }

        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let strings = L.s
        return hours > 0
            ? "\(hours) \(strings.hours) \(minutes) \(strings.minutes)"
            : "\(minutes) \(strings.minutes)"
    }
}
