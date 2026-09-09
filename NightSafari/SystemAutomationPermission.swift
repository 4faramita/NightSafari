import AppKit
import CoreServices

@MainActor
enum SystemAutomationPermission {
	private nonisolated static let safariBundleIdentifier = "com.apple.Safari"

	static func currentStatus() async -> PermissionStatus? {
		guard NSRunningApplication.runningApplications(
			withBundleIdentifier: safariBundleIdentifier
		).isEmpty == false else {
			return nil
		}

		let result = await determinePermission(askUserIfNeeded: false)
		return permissionStatus(for: result)
	}

	static func requestAccess() async throws -> PermissionStatus {
		try await launchSafariIfNeeded()

		let result = await determinePermission(askUserIfNeeded: true)
		if let status = permissionStatus(for: result) {
			return status
		}

		let message = NSError(
			domain: NSOSStatusErrorDomain,
			code: Int(result)
		).localizedDescription
		throw PrivateBrowsingError.automationFailed(
			AppleScriptExecutionError(message: message, code: Int(result))
		)
	}

	static func openSettings() {
		guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
			return
		}

		NSWorkspace.shared.open(url)
	}

	private static func launchSafariIfNeeded() async throws {
		guard NSRunningApplication.runningApplications(
			withBundleIdentifier: safariBundleIdentifier
		).isEmpty else {
			return
		}

		guard let safariURL = NSWorkspace.shared.urlForApplication(
			withBundleIdentifier: safariBundleIdentifier
		) else {
			throw PrivateBrowsingError.safariUnavailable
		}

		let configuration = NSWorkspace.OpenConfiguration()
		configuration.activates = false
		configuration.addsToRecentItems = false

		do {
			_ = try await NSWorkspace.shared.openApplication(
				at: safariURL,
				configuration: configuration
			)
		} catch {
			throw PrivateBrowsingError.safariLaunchFailed(error.localizedDescription)
		}
	}

	private nonisolated static func determinePermission(
		askUserIfNeeded: Bool
	) async -> OSStatus {
		let task = Task.detached(priority: .userInitiated) {
			let target = NSAppleEventDescriptor(bundleIdentifier: safariBundleIdentifier)
			guard let descriptor = target.aeDesc else { return OSStatus(paramErr) }

			return AEDeterminePermissionToAutomateTarget(
				descriptor,
				typeWildCard,
				typeWildCard,
				askUserIfNeeded
			)
		}
		return await task.value
	}

	private nonisolated static func permissionStatus(for result: OSStatus) -> PermissionStatus? {
		switch result {
		case noErr:
			.granted
		case OSStatus(errAEEventNotPermitted):
			.denied
		case OSStatus(errAEEventWouldRequireUserConsent):
			.notDetermined
		default:
			nil
		}
	}
}
