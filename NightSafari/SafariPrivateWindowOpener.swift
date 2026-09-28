import Foundation

@MainActor
final class SafariPrivateWindowOpener<Automation: SafariWindowAutomation> {
	let automation: Automation
	let pollInterval: Duration
	let maximumPollAttempts: Int
	let requiredStableSnapshotCount: Int
	private var recentWindow: (window: Automation.Window, scriptID: Int)?

	init(automation: Automation, pollInterval: Duration = .milliseconds(100),
		maximumPollAttempts: Int = 100, requiredStableSnapshotCount: Int = 10) {
		self.automation = automation
		self.pollInterval = pollInterval
		self.maximumPollAttempts = maximumPollAttempts
		self.requiredStableSnapshotCount = requiredStableSnapshotCount
	}

	func open(_ urls: [URL]) async throws {
		guard urls.isEmpty == false else { return }

		try await automation.prepare()
		try Task.checkCancellation()
		let existingWindows = try await stableWindowSnapshot()
		try automation.createPrivateWindow()
		let target = try await verifiedNewWindow(excluding: existingWindows)
		try Task.checkCancellation()
		try automation.open(urls, inWindowID: target.scriptID)
		recentWindow = target
	}

	func activateOrOpenPrivateWindow() async throws {
		try await automation.prepare()
		try Task.checkCancellation()

		// Reuse only a window whose identity and private chrome we verified in this session.
		if let recentWindow,
			let existingWindows = try automation.snapshot(),
			existingWindows.windows.contains(recentWindow.window),
			existingWindows.scriptIDs.contains(recentWindow.scriptID),
			automation.isPrivateWindow(recentWindow.window) {
			try automation.activate(recentWindow.window)
			return
		}

		recentWindow = nil
		let existingWindows = try await stableWindowSnapshot()
		try automation.createPrivateWindow()
		let target = try await verifiedNewWindow(excluding: existingWindows)
		try Task.checkCancellation()
		try automation.activate(target.window)
		recentWindow = target
	}

	private func stableWindowSnapshot() async throws -> SafariWindowSnapshot<Automation.Window> {
		var previous: SafariWindowSnapshot<Automation.Window>?
		var stableCount = 0

		for _ in 0..<maximumPollAttempts {
			try Task.checkCancellation()
			if let current = try automation.snapshot() {
				stableCount = current == previous ? stableCount + 1 : 0
				if stableCount >= requiredStableSnapshotCount {
					return current
				}
				previous = current
			} else {
				previous = nil
				stableCount = 0
			}
			try await Task.sleep(for: pollInterval)
		}

		throw PrivateBrowsingError.safariNotReady
	}

	private func verifiedNewWindow(
		excluding previous: SafariWindowSnapshot<Automation.Window>
	) async throws -> (window: Automation.Window, scriptID: Int) {
		for _ in 0..<maximumPollAttempts {
			try Task.checkCancellation()
			if let current = try automation.snapshot(),
				let target = current.newWindow(since: previous),
				automation.isPrivateWindow(target.window),
				let confirmed = try automation.snapshot(),
				confirmed == current,
				automation.isPrivateWindow(target.window) {
				return target
			}
			try await Task.sleep(for: pollInterval)
		}

		throw PrivateBrowsingError.privateWindowUnverified
	}
}

extension SafariPrivateWindowOpener where Automation == SystemSafariAutomation {
	convenience init() {
		self.init(automation: SystemSafariAutomation())
	}
}
