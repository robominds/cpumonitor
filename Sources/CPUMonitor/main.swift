// CPUMonitor — menu bar CPU / GPU / memory monitor for macOS.
// Author: Mark Castelluccio. Written with assistance from Claude (Anthropic).

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
app.run()
