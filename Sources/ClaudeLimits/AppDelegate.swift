import AppKit

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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Rendering

    private func render() {
        let title = rows.isEmpty ? "—" : rows.map { "\($0.percent)" }.joined(separator: " · ")
        statusItem.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
        )

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
        menu.addItem(withTitle: "Обновить", action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "Выход", action: #selector(quit), keyEquivalent: "q").target = self
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    nonisolated static func remaining(until date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "сброс сейчас" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "сброс через \(hours) ч \(minutes) мин" : "сброс через \(minutes) мин"
    }
}
