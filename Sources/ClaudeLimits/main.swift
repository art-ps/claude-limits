import AppKit

if CommandLine.arguments.contains("--selftest") {
    runSelfTest()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
