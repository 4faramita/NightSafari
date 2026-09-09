import AppKit
import ApplicationServices
import CoreServices

@MainActor
final class SystemSafariAutomation: @MainActor SafariWindowAutomation {
	private var safari: NSRunningApplication?
	private var interfaceStrings: SafariInterfaceStrings?

	func prepare() async throws {
		guard SystemAccessibilityPermission.hasAccess else {
			throw PrivateBrowsingError.accessibilityDenied
		}
		guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else {
			throw PrivateBrowsingError.safariUnavailable
		}

		switch try await SystemAutomationPermission.requestAccess() {
		case .granted:
			break
		case .denied:
			throw PrivateBrowsingError.automationFailed(AppleScriptExecutionError(
				message: String(localized: .errorAutomationDenied), code: Int(errAEEventNotPermitted)))
		case .notDetermined:
			throw PrivateBrowsingError.automationRequired
		}
		try Task.checkCancellation()

		guard let safari = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
			throw PrivateBrowsingError.safariNotReady
		}
		self.safari = safari
		interfaceStrings = SafariInterfaceStrings.load(safariURL: safariURL)
		guard safari.activate(options: []) else {
			throw PrivateBrowsingError.safariActivationFailed
		}
	}

	func snapshot() throws -> SafariWindowSnapshot<SafariAccessibilityElement>? {
		guard let safari, safari.isFinishedLaunching, safari.isTerminated == false else { return nil }
		let application = SafariAccessibilityElement(element: AXUIElementCreateApplication(safari.processIdentifier))
		guard let before = application.elements(kAXWindowsAttribute) else { return nil }
		let ids = try windowIDs()
		guard let after = application.elements(kAXWindowsAttribute),
			before.count == after.count, before.allSatisfy(after.contains) else { return nil }
		return SafariWindowSnapshot(windows: after, scriptIDs: ids)
	}

	func createPrivateWindow() throws {
		guard let safari, let interfaceStrings else { throw PrivateBrowsingError.safariNotReady }
		let application = SafariAccessibilityElement(element: AXUIElementCreateApplication(safari.processIdentifier))
		guard let value = application.value(kAXMenuBarAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else {
			throw PrivateBrowsingError.privateWindowCommandUnavailable
		}
		let menuBar = SafariAccessibilityElement(element: value as! AXUIElement)
		let items = menuBar.children.flatMap(\.children).flatMap(\.children).filter { item in
			item.role == kAXMenuItemRole as String
				&& (item.value(kAXTitleAttribute) as? String).map(interfaceStrings.newPrivateWindowTitles.contains) == true
		}
		guard items.count == 1, let item = items.first,
			item.value(kAXEnabledAttribute) as? Bool == true,
			AXUIElementPerformAction(item.element, kAXPressAction as CFString) == .success else {
			throw PrivateBrowsingError.privateWindowCommandUnavailable
		}
	}

	func isPrivateWindow(_ window: SafariAccessibilityElement) -> Bool {
		guard let interfaceStrings else { return false }
		return SafariPrivateBrowsingVerifier.isPrivateWindow(window,
			addressFieldDescriptions: interfaceStrings.privateAddressFieldDescriptions)
	}

	func open(_ urls: [URL], inWindowID windowID: Int) throws {
		do {
			_ = try SystemAppleScriptRunner.run(AppleScriptSourceBuilder.openURLs(urls, inWindowID: windowID))
		} catch let error as AppleScriptExecutionError {
			throw PrivateBrowsingError.automationFailed(error)
		}
		_ = safari?.activate(options: [])
	}

	private func windowIDs() throws -> Set<Int> {
		do {
			let descriptor = try SystemAppleScriptRunner.run(AppleScriptSourceBuilder.windowIDs)
			guard descriptor.descriptorType == typeAEList else { throw PrivateBrowsingError.privateWindowUnverified }
			var ids = Set<Int>()
			for index in 0..<descriptor.numberOfItems {
				guard let item = descriptor.atIndex(index + 1), item.int32Value > 0 else {
					throw PrivateBrowsingError.privateWindowUnverified
				}
				ids.insert(Int(item.int32Value))
			}
			guard ids.count == descriptor.numberOfItems else { throw PrivateBrowsingError.privateWindowUnverified }
			return ids
		} catch let error as AppleScriptExecutionError {
			throw PrivateBrowsingError.automationFailed(error)
		}
	}
}
