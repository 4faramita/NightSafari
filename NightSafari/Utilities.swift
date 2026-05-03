import Cocoa
import ApplicationServices

private enum NightSafariConfig {
	static let newWindowKeyCode: CGKeyCode = 0x2D // N
	static let privateWindowOpenTimeoutSeconds = 1.0
	static let pollIntervalSeconds = 0.05
}

func openPrivateSafariWindow(with urls: [URL]) async {
	guard !urls.isEmpty else { return }
	guard let launchState = await launchOrActivateSafari() else { return }
	let pid = launchState.pid

	let axApp = AXUIElementCreateApplication(pid)

		if let privateWindow = findPrivateWindow(in: axApp) {
			AXUIElementPerformAction(privateWindow, kAXRaiseAction as CFString)
			let openedNatively = await openURLsInSafariNatively(urls)
			activateSafari(pid: pid)

			guard openedNatively || runSafariFallbackAutomation(urls: urls, shouldOpenLocations: true, shouldCloseNonFrontWindows: false) else {
				return
			}
			_ = closeFrontSafariWindowStartPageTab()
		} else {
		postKeystroke(virtualKey: NightSafariConfig.newWindowKeyCode, flags: [.maskCommand, .maskShift], to: pid) // Cmd+Shift+N

		let privateWindowAppeared = await pollUntil(
			seconds: NightSafariConfig.privateWindowOpenTimeoutSeconds,
			interval: NightSafariConfig.pollIntervalSeconds
		) {
			findPrivateWindow(in: axApp) != nil
		}

		guard privateWindowAppeared, let privateWindow = findPrivateWindow(in: axApp) else {
			NSLog("NightSafari: Timed out waiting for private window to appear.")
			return
		}

		AXUIElementPerformAction(privateWindow, kAXRaiseAction as CFString)

		let openedNatively = await openURLsInSafariNatively(urls)
			let closedNonFrontWindows = launchState.didColdLaunch
				? closeNonFrontAXWindows(in: axApp, keeping: privateWindow)
				: true

			activateSafari(pid: pid)
			if !openedNatively || !closedNonFrontWindows {
				_ = runSafariFallbackAutomation(
					urls: urls,
					shouldOpenLocations: !openedNatively,
					shouldCloseNonFrontWindows: !closedNonFrontWindows
				)
			}
			_ = closeFrontSafariWindowStartPageTab()
		}
}

// MARK: - Safari launch / activate

private let safariBundleID = "com.apple.Safari"

private struct SafariLaunchState {
	let pid: pid_t
	let didColdLaunch: Bool
}

private func launchOrActivateSafari() async -> SafariLaunchState? {
	if let app = NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).first {
		return SafariLaunchState(pid: app.processIdentifier, didColdLaunch: false)
	}
	guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: safariBundleID) else { return nil }
	let config = NSWorkspace.OpenConfiguration()
	config.activates = false
	config.hides = true
	guard let app = try? await NSWorkspace.shared.openApplication(at: safariURL, configuration: config) else { return nil }
	return SafariLaunchState(pid: app.processIdentifier, didColdLaunch: true)
}

private func activateSafari(pid: pid_t) {
	guard let app = NSRunningApplication(processIdentifier: pid) else { return }
	app.activate(options: [])
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

private func openURLsInSafariNatively(_ urls: [URL]) async -> Bool {
	guard !urls.isEmpty else { return true }
	guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: safariBundleID) else { return false }

	let config = NSWorkspace.OpenConfiguration()
	config.activates = false

	return await withCheckedContinuation { continuation in
		NSWorkspace.shared.open(urls, withApplicationAt: safariURL, configuration: config) { _, error in
			if let error {
				NSLog("NightSafari: Native URL open failed: %@", error.localizedDescription)
				continuation.resume(returning: false)
				return
			}

			continuation.resume(returning: true)
		}
	}
}

@discardableResult
private func closeNonFrontAXWindows(in axApp: AXUIElement, keeping frontWindow: AXUIElement) -> Bool {
	var ref: CFTypeRef?
	guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success,
		  let windows = ref as? [AXUIElement] else { return false }

	var success = true

	for window in windows where !CFEqual(window, frontWindow) {
		let result = AXUIElementPerformAction(window, "AXClose" as CFString)
		if result != .success {
			success = false
			NSLog("NightSafari: Failed to close non-front window with AX (AXError: %d).", result.rawValue)
		}
	}

	return success
}

@discardableResult
private func runSafariFallbackAutomation(
	urls: [URL],
	shouldOpenLocations: Bool,
	shouldCloseNonFrontWindows: Bool
) -> Bool {
	let openLocationsBlock = shouldOpenLocations
		? urls
			.map { "\t\topen location \"\($0.absoluteString.appleScriptEscaped)\"" }
			.joined(separator: "\n")
		: ""

	let closeNonFrontWindowsBlock = shouldCloseNonFrontWindows
		? """
		\t\tset otherWindows to every window whose id is not frontWindowID
		\t\trepeat with targetWindow in otherWindows
		\t\t\ttry
		\t\t\t\tclose targetWindow
		\t\t\tend try
		\t\tend repeat
		"""
		: ""

	let source = """
	tell application "Safari"
		if (count of windows) > 0 then
			set frontWindowID to id of front window
	\(openLocationsBlock.isEmpty ? "" : "\n\(openLocationsBlock)")
	\(closeNonFrontWindowsBlock.isEmpty ? "" : "\n\(closeNonFrontWindowsBlock)")
		end if
	end tell
	"""

	switch runAppleScript(source) {
		case .success:
			return true
		case .failure(let error):
			NSLog("NightSafari: Fallback AppleScript failed: %@", error.localizedDescription)
			return false
	}
}

@discardableResult
private func closeFrontSafariWindowStartPageTab() -> Bool {
	switch runAppleScript("""
	tell application "Safari"
		if (count of windows) > 0 then
			set frontWindowID to id of front window
			set startPageURLs to {"favorites://", "favorites:///", "about:blank", "x-apple-startpage://", "x-apple-startpage:///"}
			repeat with targetTab in (tabs of window id frontWindowID)
				try
					set tabURL to URL of targetTab
				on error
					set tabURL to ""
				end try
				if startPageURLs contains tabURL then
					try
						close targetTab
					end try
					exit repeat
				end if
			end repeat
		end if
	end tell
	""") {
		case .success:
			return true
		case .failure(let error):
			NSLog("NightSafari: Failed to close Start Page tab: %@", error.localizedDescription)
			return false
	}
}

// MARK: - Polling

private func pollUntil(seconds: Double, interval: Double, condition: () -> Bool) async -> Bool {
	for _ in 0..<Int(seconds / interval) {
		if condition() { return true }
		try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
	}

	return condition()
}

// MARK: - AppleScript

@discardableResult
func runAppleScript(_ source: String) -> Result<String?, AppleScriptExecutionError> {
	guard let script = NSAppleScript(source: source) else {
		return .failure(AppleScriptExecutionError(message: "Could not create NSAppleScript.", code: nil))
	}

	var error: NSDictionary?
	let output = script.executeAndReturnError(&error)

	guard let error else {
		return .success(output.stringValue)
	}

	let message = (error[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error."
	let code = error[NSAppleScript.errorNumber] as? Int
	return .failure(AppleScriptExecutionError(message: message, code: code))
}


enum Permissions {
	enum Accessibility {
		static var hasAccess: Bool { AXIsProcessTrusted() }

		static func requestAccess() -> Bool {
			AXIsProcessTrustedWithOptions([
				kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
			] as CFDictionary)
		}
	}
}

struct AppleScriptExecutionError: LocalizedError {
	let message: String
	let code: Int?

	var errorDescription: String? {
		if let code {
			return "\(message) (code: \(code))"
		}

		return message
	}
}

private extension String {
	var appleScriptEscaped: String {
		replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\"", with: "\\\"")
	}
}
