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
    assert(rows.map(\.title) == ["Сессия", "Все модели", "Fable"], "titles: \(rows.map(\.title))")

    assert(rows.map(\.severity) == ["normal", "warning", "critical"], "severities: \(rows.map(\.severity))")
    assert(AppDelegate.color(for: "normal") == .labelColor)
    assert(AppDelegate.color(for: "warning") == .systemOrange)
    assert(AppDelegate.color(for: "critical") == .systemRed)
    assert(AppDelegate.color(for: "brand_new_severity") == .labelColor)

    let reset = rows[0].resetsAt!
    assert(AppDelegate.remaining(until: reset, now: reset.addingTimeInterval(-4260)) == "1 ч 11 мин")
    assert(AppDelegate.remaining(until: reset, now: reset.addingTimeInterval(-1800)) == "30 мин")
    assert(AppDelegate.remaining(until: reset, now: reset.addingTimeInterval(60)) == "0 мин")

    print("selftest ok: \(rows.map { "\($0.title)=\($0.percent)%" }.joined(separator: ", "))")
}
