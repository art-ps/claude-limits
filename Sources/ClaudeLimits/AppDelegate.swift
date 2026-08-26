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
            lastError = "Автозапуск: \(error.localizedDescription)"
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
            menu.addItem(disabledItem("Ошибка: \(lastError)"))
        }

        for row in rows {
            let reset = Self.remaining(until: row.resetsAt)
            let suffix = reset.isEmpty ? "" : " · \(reset)"
            menu.addItem(disabledItem("\(row.title) — \(row.percent)%\(suffix)"))
        }

        if rows.isEmpty && lastError == nil {
            menu.addItem(disabledItem("Загрузка…"))
        }

        menu.addItem(.separator())

        let barsItem = menu.addItem(
            withTitle: "Полоски вместо цифр",
            action: #selector(toggleBars),
            keyEquivalent: ""
        )
        barsItem.target = self
        barsItem.state = showsBars ? .on : .off

        let launchItem = menu.addItem(
            withTitle: "Запускать при входе",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Обновить", action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "Выход", action: #selector(quit), keyEquivalent: "q").target = self
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
        return hours > 0 ? "\(hours) ч \(minutes) мин" : "\(minutes) мин"
    }
}
