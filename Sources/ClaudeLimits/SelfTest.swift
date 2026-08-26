import AppKit
import Foundation

/// Trimmed real response from GET /api/oauth/usage.
private let fixture = """
{
  "five_hour": {"utilization": 20.0, "resets_at": "2026-08-26T09:59:59.570639+00:00"},
  "seven_day_opus": null,
  "limits": [
    {"kind": "session", "percent": 20, "severity": "normal", "resets_at": "2026-08-26T09:59:59.570639+00:00", "scope": null},
    {"kind": "weekly_all", "percent": 72, "severity": "warning", "resets_at": "2026-08-27T03:59:59.570669+00:00", "scope": null},
    {"kind": "weekly_scoped", "percent": 58, "severity": "critical", "resets_at": "2026-08-27T03:59:59.570998+00:00",
     "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null}},
    {"kind": "some_future_kind", "percent": 99, "resets_at": null, "scope": null}
  ]
}
"""

func runSelfTest() {
    let rows = try! UsageAPI.decode(Data(fixture.utf8))

    assert(rows.count == 3, "expected 3 rows, got \(rows.count)")
    assert(rows.map(\.percent) == [20, 72, 58], "percents: \(rows.map(\.percent))")
    assert(rows.map(\.kind) == ["session", "weekly_all", "weekly_scoped"], "kinds: \(rows.map(\.kind))")
    assert(rows[2].scopeName == "Fable", "scope name: \(String(describing: rows[2].scopeName))")

    assert(rows.map(\.severity) == ["normal", "warning", "critical"], "severities: \(rows.map(\.severity))")
    assert(AppDelegate.color(for: "normal") == .labelColor)
    assert(AppDelegate.color(for: "warning") == .systemOrange)
    assert(AppDelegate.color(for: "critical") == .systemRed)
    assert(AppDelegate.color(for: "brand_new_severity") == .labelColor)
    assert(AppDelegate.progressColor(for: "normal") == .controlAccentColor)
    assert(AppDelegate.progressColor(for: "critical") == .systemRed)
    assert(AppDelegate.progressBarImage(percent: 58, severity: "normal").size.width == 210)

    let reset = rows[0].resetsAt!
    let saved = L.preference

    L.preference = .en
    assert(AppDelegate.title(for: rows[0]) == "Session")
    assert(AppDelegate.title(for: rows[2]) == "Fable", "scoped title comes from the API, not a translation")
    assert(AppDelegate.remaining(until: reset, now: reset.addingTimeInterval(-4260)) == "1 h 11 min")
    assert(AppDelegate.remaining(until: reset, now: reset.addingTimeInterval(-1800)) == "30 min")
    assert(AppDelegate.remaining(until: reset, now: reset.addingTimeInterval(60)) == "0 min")

    L.preference = .ru
    assert(AppDelegate.title(for: rows[1]) == "Все модели")
    assert(AppDelegate.remaining(until: reset, now: reset.addingTimeInterval(-4260)) == "1 ч 11 мин")

    L.preference = saved

    print("selftest ok: \(rows.map { "\($0.kind)=\($0.percent)%" }.joined(separator: ", "))")
}
