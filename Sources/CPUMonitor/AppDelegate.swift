import AppKit
import ServiceManagement
import StatsCore

private enum Metric: String, CaseIterable {
    case cpu = "CPU", gpu = "GPU", mem = "MEM"

    var defaultsKey: String { "show\(rawValue)" }
}

private enum Defaults {
    static let interval = "updateInterval"
    static let colorize = "colorizeHighUsage"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let cpuSampler = CPUSampler()
    private let gpuSampler = GPUSampler()
    private let memSampler = MemorySampler()
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    // Live detail rows in the dropdown.
    private let cpuDetail = NSMenuItem()
    private let gpuDetail = NSMenuItem()
    private let memDetail = NSMenuItem()
    private let memBreakdown = NSMenuItem()
    private var metricToggles: [Metric: NSMenuItem] = [:]
    private var intervalItems: [NSMenuItem] = []
    private let colorizeItem = NSMenuItem()
    private let loginItem = NSMenuItem()

    private static let intervals: [TimeInterval] = [1, 2, 5]

    private var interval: TimeInterval {
        let v = defaults.double(forKey: Defaults.interval)
        return Self.intervals.contains(v) ? v : 2
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: [
            Metric.cpu.defaultsKey: true,
            Metric.gpu.defaultsKey: true,
            Metric.mem.defaultsKey: true,
            Defaults.colorize: true,
        ])
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        statusItem.menu = buildMenu()
        refresh()
        startTimer()
    }

    // MARK: - Sampling

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        t.tolerance = interval * 0.1
        RunLoop.main.add(t, forMode: .common)  // keep updating while the menu is open
        timer = t
    }

    private func refresh() {
        let cpu = cpuSampler.sample()
        let gpu = gpuSampler.sample()
        let mem = memSampler.sample()

        updateStatusTitle(cpu: cpu?.total, gpu: gpu?.utilization, mem: mem?.fraction)

        if let cpu {
            setDetail(cpuDetail, "CPU  \(Format.percent(cpu.total))   user \(Format.percent(cpu.user))  ·  system \(Format.percent(cpu.system))")
        } else {
            setDetail(cpuDetail, "CPU  unavailable")
        }
        if let gpu {
            let vram = gpu.memoryInUse.map { "   ·  \(Format.gigabytes($0)) in use" } ?? ""
            setDetail(gpuDetail, "GPU  \(Format.percent(gpu.utilization))\(vram)")
        } else {
            setDetail(gpuDetail, "GPU  unavailable")
        }
        if let mem {
            setDetail(memDetail, "MEM  \(Format.percent(mem.fraction))   \(Format.gigabytes(mem.used)) of \(Format.gigabytes(mem.total))")
            setDetail(memBreakdown, "       app \(Format.gigabytes(mem.app))  ·  wired \(Format.gigabytes(mem.wired))  ·  compressed \(Format.gigabytes(mem.compressed))")
        } else {
            setDetail(memDetail, "MEM  unavailable")
            setDetail(memBreakdown, "")
        }
    }

    /// Disabled items render dimmed by default; an explicit colour keeps the live rows legible.
    private func setDetail(_ item: NSMenuItem, _ text: String) {
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ])
    }

    private func updateStatusTitle(cpu: Double?, gpu: Double?, mem: Double?) {
        let values: [Metric: Double?] = [.cpu: cpu, .gpu: gpu, .mem: mem]
        let shown = Metric.allCases.filter { defaults.bool(forKey: $0.defaultsKey) }
        let colorize = defaults.bool(forKey: Defaults.colorize)

        let size = NSFont.systemFontSize - 1
        let labelFont = NSFont.systemFont(ofSize: size - 2, weight: .medium)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)

        let title = NSMutableAttributedString()
        for (i, metric) in shown.enumerated() {
            if i > 0 { title.append(NSAttributedString(string: "  ", attributes: [.font: valueFont])) }
            title.append(NSAttributedString(string: metric.rawValue + " ", attributes: [
                .font: labelFont,
                .foregroundColor: NSColor.secondaryLabelColor,
                .baselineOffset: 0.5,
            ]))
            let value = values[metric] ?? nil
            var attrs: [NSAttributedString.Key: Any] = [.font: valueFont]
            if colorize, let color = Self.color(for: value) { attrs[.foregroundColor] = color }
            title.append(NSAttributedString(string: Format.percent(value), attributes: attrs))
        }
        if shown.isEmpty {
            statusItem.button?.attributedTitle = NSAttributedString()
            statusItem.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent",
                                               accessibilityDescription: "System monitor")
        } else {
            statusItem.button?.image = nil
            statusItem.button?.attributedTitle = title
        }
    }

    private static func color(for fraction: Double?) -> NSColor? {
        guard let f = fraction else { return nil }
        if f >= 0.9 { return .systemRed }
        if f >= 0.75 { return .systemOrange }
        return nil
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for item in [cpuDetail, gpuDetail, memDetail, memBreakdown] {
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let show = NSMenuItem(title: "Show in Menu Bar", action: nil, keyEquivalent: "")
        let showMenu = NSMenu()
        for metric in Metric.allCases {
            let item = NSMenuItem(title: metric.rawValue, action: #selector(toggleMetric(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = metric.rawValue
            item.state = defaults.bool(forKey: metric.defaultsKey) ? .on : .off
            metricToggles[metric] = item
            showMenu.addItem(item)
        }
        show.submenu = showMenu
        menu.addItem(show)

        let intervalItem = NSMenuItem(title: "Update Every", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for seconds in Self.intervals {
            let item = NSMenuItem(title: "\(Int(seconds)) s", action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(seconds)
            item.state = seconds == interval ? .on : .off
            intervalItems.append(item)
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        colorizeItem.title = "Highlight High Usage"
        colorizeItem.action = #selector(toggleColorize(_:))
        colorizeItem.target = self
        colorizeItem.state = defaults.bool(forKey: Defaults.colorize) ? .on : .off
        menu.addItem(colorizeItem)

        loginItem.title = "Launch at Login"
        loginItem.action = #selector(toggleLaunchAtLogin(_:))
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let activity = NSMenuItem(title: "Open Activity Monitor", action: #selector(openActivityMonitor), keyEquivalent: "")
        activity.target = self
        menu.addItem(activity)

        menu.addItem(NSMenuItem(title: "Quit CPUMonitor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func toggleMetric(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let metric = Metric(rawValue: raw) else { return }
        let on = sender.state != .on
        defaults.set(on, forKey: metric.defaultsKey)
        sender.state = on ? .on : .off
        refresh()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        defaults.set(Double(sender.tag), forKey: Defaults.interval)
        intervalItems.forEach { $0.state = $0 === sender ? .on : .off }
        startTimer()
    }

    @objc private func toggleColorize(_ sender: NSMenuItem) {
        let on = sender.state != .on
        defaults.set(on, forKey: Defaults.colorize)
        sender.state = on ? .on : .off
        refresh()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nRun CPUMonitor from the bundled CPUMonitor.app (ideally in /Applications) to enable this."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        sender.state = service.status == .enabled ? .on : .off
    }

    @objc private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}
