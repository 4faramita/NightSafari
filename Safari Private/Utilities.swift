import Cocoa
import ApplicationServices


func openPrivateSafariWindow(with urls: [URL]) {
	guard !urls.isEmpty else { return }
	guard let pid = launchOrActivateSafari() else { return }

	let axApp = AXUIElementCreateApplication(pid)

	if let privateWindow = findPrivateWindow(in: axApp) {
		AXUIElementPerformAction(privateWindow, kAXRaiseAction as CFString)
		safariOpenLocations(urls)
	} else {
		let before = axWindowCount(axApp)
		postKeystroke(virtualKey: 0x2D, flags: [.maskCommand, .maskShift], to: pid) // Cmd+Shift+N
		pollUntil(seconds: 1.0, interval: 0.05) { axWindowCount(axApp) > before }
		safariOpenLocations(urls)
		runAppleScript("tell application \"Safari\" to close tab 1 of front window")
	}
}

// MARK: - Safari launch / activate

private let safariBundleID = "com.apple.Safari"

private func launchOrActivateSafari() -> pid_t? {
	if let app = NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).first {
		app.activate(options: [])
		return app.processIdentifier
	}
	guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: safariBundleID) else { return nil }
	let config = NSWorkspace.OpenConfiguration()
	config.activates = true
	var launched: NSRunningApplication?
	let sem = DispatchSemaphore(value: 0)
	NSWorkspace.shared.openApplication(at: safariURL, configuration: config) { app, _ in
		launched = app
		sem.signal()
	}
	_ = sem.wait(timeout: .now() + 5)
	return launched?.processIdentifier
}

// MARK: - Accessibility helpers

private func findPrivateWindow(in axApp: AXUIElement) -> AXUIElement? {
	var ref: CFTypeRef?
	guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success,
		  let windows = ref as? [AXUIElement] else { return nil }
	return windows.first { window in
		var titleRef: CFTypeRef?
		AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
		return (titleRef as? String)?.contains("Private Browsing") == true
	}
}

private func axWindowCount(_ axApp: AXUIElement) -> Int {
	var ref: CFTypeRef?
	guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success,
		  let windows = ref as? [AXUIElement] else { return 0 }
	return windows.count
}

// MARK: - Input helpers

private func postKeystroke(virtualKey: CGKeyCode, flags: CGEventFlags, to pid: pid_t) {
	let src = CGEventSource(stateID: .hidSystemState)
	let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)
	let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)
	down?.flags = flags
	up?.flags = flags
	down?.postToPid(pid)
	up?.postToPid(pid)
}

private func safariOpenLocations(_ urls: [URL]) {
	let commands = urls.map { "open location \"\($0.absoluteString)\"" }.joined(separator: "\n\t")
	runAppleScript("tell application \"Safari\"\n\t\(commands)\nend tell")
}

// MARK: - Polling

private func pollUntil(seconds: Double, interval: Double, condition: () -> Bool) {
	for _ in 0..<Int(seconds / interval) {
		if condition() { return }
		Thread.sleep(forTimeInterval: interval)
	}
}

// MARK: - AppleScript fallback (kept for potential future use)

@discardableResult
func runAppleScript(_ source: String) -> String? {
	NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
}


enum Permissions {
	enum Accessibility {
		static var hasAccess: Bool { AXIsProcessTrusted() }

		static func requestAccess() -> Bool {
			AXIsProcessTrustedWithOptions([
				kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
			] as CFDictionary)
		}
	}
}
