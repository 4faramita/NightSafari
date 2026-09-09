@preconcurrency import ApplicationServices
import AppKit

@MainActor
enum SystemAccessibilityPermission {
	static var hasAccess: Bool {
		AXIsProcessTrusted()
	}

	static func requestAccess() {
		AXIsProcessTrustedWithOptions([
			kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
		] as CFDictionary)
	}

	static func openSettings() {
		guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
			return
		}

		NSWorkspace.shared.open(url)
	}
}
