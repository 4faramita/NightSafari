import Foundation

@MainActor
struct SafariPrivateWindowOpener<Automation: SafariWindowAutomation> {
	let automation: Automation
	var pollInterval: Duration = .milliseconds(100)
	var maximumPollAttempts = 100
	var requiredStableSnapshotCount = 10

	func open(_ urls: [URL]) async throws {
		guard urls.isEmpty == false else { return }

		try await automation.prepare()
		try Task.checkCancellation()
		let existingWindows = try await stableWindowSnapshot()
		try automation.createPrivateWindow()
		let windowID = try await verifiedNewWindowID(excluding: existingWindows)
		try Task.checkCancellation()
		try automation.open(urls, inWindowID: windowID)
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

	private func verifiedNewWindowID(
		excluding previous: SafariWindowSnapshot<Automation.Window>
	) async throws -> Int {
		for _ in 0..<maximumPollAttempts {
			try Task.checkCancellation()
			if let current = try automation.snapshot(),
				let target = current.newWindow(since: previous),
				automation.isPrivateWindow(target.window),
				let confirmed = try automation.snapshot(),
				confirmed == current,
				automation.isPrivateWindow(target.window) {
				return target.scriptID
			}
			try await Task.sleep(for: pollInterval)
		}

		throw PrivateBrowsingError.privateWindowUnverified
	}
}

extension SafariPrivateWindowOpener where Automation == SystemSafariAutomation {
	init() {
		self.init(automation: SystemSafariAutomation())
	}
}
