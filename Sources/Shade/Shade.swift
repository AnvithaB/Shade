import AppKit

struct Settings: Codable, Equatable {
    var enabled = true
    var opacity = 0.18
    var red = 0.08
    var green = 0.42
    var blue = 0.40

    var color: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
    mutating func sanitize() {
        opacity = opacity.isFinite ? min(0.65, max(0, opacity)) : 0.18
        red = red.isFinite ? min(1, max(0, red)) : 0.08
        green = green.isFinite ? min(1, max(0, green)) : 0.42
        blue = blue.isFinite ? min(1, max(0, blue)) : 0.40
    }
    static func load(from defaults: UserDefaults) -> Settings {
        guard let data = defaults.data(forKey: "settings"),
              var value = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        value.sanitize()
        return value
    }
    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "settings") }
    }
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController {
    private(set) var windows: [OverlayWindow] = []

    func rebuild(settings: Settings) {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { screen in
            let frame = screen.frame
            let window = OverlayWindow(contentRect: frame, styleMask: .borderless,
                                       backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.hidesOnDeactivate = false
            window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.animationBehavior = .none
            window.isMovable = false
            window.setFrame(frame, display: false)
            window.setAccessibilityElement(false)
            return window
        }
        apply(settings)
    }

    func apply(_ settings: Settings) {
        for window in windows {
            window.backgroundColor = settings.color.withAlphaComponent(settings.opacity)
            if settings.enabled && settings.opacity > 0 { window.orderFrontRegardless() }
            else { window.orderOut(nil) }
        }
    }

    func close() { windows.forEach { $0.close() }; windows.removeAll() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var settings = Settings.load(from: .standard)
    let overlays = OverlayController()
    var statusItem: NSStatusItem!
    let toggleItem = NSMenuItem(title: "Tint On", action: #selector(toggle), keyEquivalent: "")
    let intensityLabel = NSTextField(labelWithString: "")
    let slider = NSSlider(value: 0.18, minValue: 0, maxValue: 0.65, target: nil, action: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--self-test") { runTests(); return }
        // Opening an already running app must not stack a second tint on top.
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.shade.app")
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil); return
        }
        buildMenu()
        overlays.rebuild(settings: settings)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displaysChanged),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        refreshControls()
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.statusItem.button?.performClick(nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.button?.performClick(nil)
        return false
    }

    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "moon.circle.fill", accessibilityDescription: "Shade")
        statusItem.button?.setAccessibilityLabel("Shade")
        let menu = NSMenu()
        let title = NSMenuItem(title: "Shade · Screen Tint", action: nil, keyEquivalent: "")
        menu.addItem(title)
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let controls = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: 82))
        intensityLabel.frame = NSRect(x: 18, y: 52, width: 234, height: 18)
        intensityLabel.font = .systemFont(ofSize: 12)
        controls.addSubview(intensityLabel)
        slider.frame = NSRect(x: 18, y: 24, width: 234, height: 24)
        slider.target = self
        slider.action = #selector(changeOpacity)
        slider.isContinuous = true
        slider.setAccessibilityLabel("Tint intensity")
        controls.addSubview(slider)
        let hint = NSTextField(labelWithString: "Gentle                                      Strong")
        hint.frame = NSRect(x: 18, y: 4, width: 234, height: 16)
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        controls.addSubview(hint)
        let item = NSMenuItem()
        item.view = controls
        menu.addItem(item)
        let color = NSMenuItem(title: "Choose Tint Color…", action: #selector(chooseColor), keyEquivalent: "")
        color.target = self
        menu.addItem(color)
        let reset = NSMenuItem(title: "Reset to Gentle Teal", action: #selector(reset), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Shade", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func refreshControls() {
        toggleItem.state = settings.enabled ? .on : .off
        toggleItem.title = settings.enabled ? "Tint On — Click to Turn Off" : "Tint Off — Click to Turn On"
        slider.doubleValue = settings.opacity
        intensityLabel.stringValue = "Intensity: \(Int((settings.opacity * 100).rounded()))%"
        statusItem.button?.toolTip = settings.enabled ? "Shade: tint on" : "Shade: tint off"
        statusItem.button?.appearsDisabled = !settings.enabled

    }

    func update() {
        settings.sanitize()
        settings.save(to: .standard)
        overlays.apply(settings)
        refreshControls()
    }

    @objc func toggle() { settings.enabled.toggle(); update() }
    @objc func changeOpacity() { settings.opacity = slider.doubleValue; update() }
    @objc func reset() {
        settings = Settings()
        NSColorPanel.shared.color = settings.color
        update()
    }
    @objc func chooseColor() {
        let panel = NSColorPanel.shared
        panel.title = "Shade Tint Color"
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = settings.color
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    @objc func colorChanged(_ panel: NSColorPanel) {
        guard let color = panel.color.usingColorSpace(.sRGB) else { return }
        settings.red = color.redComponent
        settings.green = color.greenComponent
        settings.blue = color.blueComponent
        update()
    }
    @objc func displaysChanged() { overlays.rebuild(settings: settings); refreshControls() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { overlays.close() }

    func runTests() {
        let suite = "local.shade.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(Settings.load(from: defaults) == Settings(), "First-launch defaults")
        var saved = Settings(enabled: false, opacity: 0.31, red: 0.2, green: 0.5, blue: 0.7)
        saved.save(to: defaults)
        precondition(Settings.load(from: defaults) == saved, "Settings round-trip")
        defaults.set(Data("invalid".utf8), forKey: "settings")
        precondition(Settings.load(from: defaults) == Settings(), "Corrupt settings recovery")
        saved.opacity = 99
        saved.red = -5
        saved.sanitize()
        precondition(saved.opacity == 0.65 && saved.red == 0, "Safe value bounds")
        overlays.rebuild(settings: Settings())
        precondition(!overlays.windows.isEmpty, "Connected display detected")
        let expectedFrames = NSScreen.screens.map(\.frame)
        precondition(overlays.windows.map(\.frame) == expectedFrames, "Display coverage")
        for window in overlays.windows {
            precondition(window.ignoresMouseEvents && !window.canBecomeKey && !window.canBecomeMain, "Input passes through")
            precondition(window.isVisible && !window.isOpaque && !window.hasShadow, "Visible translucent overlay")
            precondition(window.collectionBehavior.contains(.canJoinAllSpaces) && window.collectionBehavior.contains(.fullScreenAuxiliary), "Spaces behavior")
        }
        var off = Settings(); off.enabled = false
        overlays.apply(off)
        precondition(overlays.windows.allSatisfy { !$0.isVisible }, "Toggle removes tint")
        var zero = Settings(); zero.opacity = 0
        overlays.apply(zero)
        precondition(overlays.windows.allSatisfy { !$0.isVisible }, "Zero intensity removes tint")
        overlays.rebuild(settings: off)
        precondition(overlays.windows.map(\.frame) == expectedFrames && overlays.windows.allSatisfy { !$0.isVisible }, "Display rebuild preserves off state")
        overlays.close()
        print("PASS: defaults, persistence, corrupt settings, bounds, display coverage, click-through/non-key windows, transparency, Spaces flags, toggle, zero intensity, display rebuild.")
        NSApp.terminate(nil)
    }
}

@main
enum ShadeMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--check-settings") {
            let original = Settings(enabled: false, opacity: 0.31, red: 0.2, green: 0.5, blue: 0.7)
            let encoded = try! JSONEncoder().encode(original)
            precondition(try! JSONDecoder().decode(Settings.self, from: encoded) == original)
            precondition((try? JSONDecoder().decode(Settings.self, from: Data("invalid".utf8))) == nil)
            var bounded = Settings(enabled: true, opacity: .infinity, red: -1, green: 2, blue: .nan)
            bounded.sanitize()
            precondition(bounded.opacity == 0.18 && bounded.red == 0 && bounded.green == 1 && bounded.blue == 0.40)
            let normal = Settings()
            precondition(normal.enabled && normal.opacity == 0.18)
            print("PASS: settings encode/decode, invalid data rejection, nonfinite/range bounds, default settings.")
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
