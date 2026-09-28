import Foundation
import Testing
@testable import NightSafari

@MainActor
struct SafariPrivateWindowOpenerTests {
	@Test
	func requestsPermissionBeforeCapturingOrCreatingWindows() async throws {
		let automation = FakeSafariWindowAutomation()
		let url = try #require(URL(string: "https://example.com"))
		try await opener(automation).open([url])
		#expect(automation.operations.first == "prepare")
		#expect(automation.operations.last == "open")
		#expect(automation.openedWindowIDs == [202])
		#expect(automation.openedURLs == [[url]])
	}

	@Test
	func permissionFailureCreatesNoWindowAndLoadsNoURLs() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.prepareError = PrivateBrowsingError.automationRequired
		let url = try #require(URL(string: "https://example.com"))
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener(automation).open([url])
		}
		#expect(automation.operations == ["prepare"])
		#expect(automation.openedURLs.isEmpty)
	}

	@Test
	func aNewOrdinaryWindowNeverReceivesURLs() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.privateWindows = []
		let url = try #require(URL(string: "https://example.com"))
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener(automation).open([url])
		}
		#expect(automation.openedURLs.isEmpty)
	}

	@Test
	func anExistingPrivateWindowIsNotReused() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.privateWindows = [1]
		automation.createdSnapshots = [automation.initial]
		let url = try #require(URL(string: "https://example.com"))
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener(automation).open([url])
		}
		#expect(automation.openedURLs.isEmpty)
	}

	@Test
	func ambiguousNewWindowsNeverReceiveURLs() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.createdSnapshots = [SafariWindowSnapshot(windows: [1, 2, 3], scriptIDs: [101, 202, 303])]
		let url = try #require(URL(string: "https://example.com"))
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener(automation).open([url])
		}
		#expect(automation.openedURLs.isEmpty)
	}

	@Test
	func windowReplacementDuringVerificationNeverReceivesURLs() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.createdSnapshots.append(SafariWindowSnapshot(windows: [1, 3], scriptIDs: [101, 303]))
		let url = try #require(URL(string: "https://example.com"))
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener(automation).open([url])
		}
		#expect(automation.openedURLs.isEmpty)
	}

	@Test
	func foregroundOrderDoesNotChangeTheTargetID() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.createdSnapshots.append(SafariWindowSnapshot(windows: [2, 1], scriptIDs: [101, 202]))
		let url = try #require(URL(string: "https://example.com"))
		try await opener(automation).open([url])
		#expect(automation.openedWindowIDs == [202])
	}

	@Test
	func waitsForPrivateBrowserChromeToBecomeAvailable() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.privateChecksBeforeReady = 2
		let url = try #require(URL(string: "https://example.com"))
		try await opener(automation).open([url])
		#expect(automation.openedWindowIDs == [202])
	}

	@Test
	func cancellationDoesNotCreateAWindow() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.prepareError = CancellationError()
		let url = try #require(URL(string: "https://example.com"))
		await #expect(throws: CancellationError.self) {
			try await opener(automation).open([url])
		}
		#expect(automation.operations == ["prepare"])
	}

	@Test
	func dockLaunchCreatesAVerifiedPrivateWindowWithoutNavigating() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.privateWindows = [1, 2]
		try await opener(automation).activateOrOpenPrivateWindow()
		#expect(automation.operations.first == "prepare")
		#expect(automation.activatedWindows == [2])
		#expect(automation.openedURLs.isEmpty)
	}

	@Test
	func dockClickReusesTheLastWindowWithoutChangingItsTabs() async throws {
		let automation = FakeSafariWindowAutomation()
		let opener = opener(automation)
		let url = try #require(URL(string: "https://example.com"))
		try await opener.open([url])
		try await opener.activateOrOpenPrivateWindow()
		try await opener.activateOrOpenPrivateWindow()
		#expect(automation.operations.filter { $0 == "create" }.count == 1)
		#expect(automation.activatedWindows == [2, 2])
		#expect(automation.openedURLs == [[url]])
	}

	@Test
	func dockClickUsesTheMostRecentlyOpenedWindow() async throws {
		let automation = FakeSafariWindowAutomation()
		let opener = opener(automation)
		try await opener.activateOrOpenPrivateWindow()
		automation.setExistingWindows(SafariWindowSnapshot(windows: [1, 2], scriptIDs: [101, 202]))
		automation.createdSnapshots = [SafariWindowSnapshot(windows: [1, 2, 3], scriptIDs: [101, 202, 303])]
		automation.privateWindows = [2, 3]
		let url = try #require(URL(string: "https://example.com"))
		try await opener.open([url])
		try await opener.activateOrOpenPrivateWindow()
		#expect(automation.activatedWindows == [2, 3])
		#expect(automation.openedWindowIDs == [303])
	}

	@Test
	func aClosedRememberedWindowIsReplacedWithANewPrivateWindow() async throws {
		let automation = FakeSafariWindowAutomation()
		let opener = opener(automation)
		try await opener.activateOrOpenPrivateWindow()
		automation.setExistingWindows(SafariWindowSnapshot(windows: [1], scriptIDs: [101]))
		automation.createdSnapshots = [SafariWindowSnapshot(windows: [1, 3], scriptIDs: [101, 303])]
		automation.privateWindows = [3]
		try await opener.activateOrOpenPrivateWindow()
		#expect(automation.activatedWindows == [2, 3])
		#expect(automation.operations.filter { $0 == "create" }.count == 2)
	}

	@Test
	func aRememberedWindowMustStillBePrivateBeforeReusingIt() async throws {
		let automation = FakeSafariWindowAutomation()
		let opener = opener(automation)
		try await opener.activateOrOpenPrivateWindow()
		automation.setExistingWindows(SafariWindowSnapshot(windows: [1, 2], scriptIDs: [101, 202]))
		automation.createdSnapshots = [SafariWindowSnapshot(windows: [1, 2, 3], scriptIDs: [101, 202, 303])]
		automation.privateWindows = [3]
		try await opener.activateOrOpenPrivateWindow()
		#expect(automation.activatedWindows == [2, 3])
	}

	@Test
	func dockLaunchNeverActivatesAnUnverifiedNewWindow() async throws {
		let automation = FakeSafariWindowAutomation()
		automation.privateWindows = []
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener(automation).activateOrOpenPrivateWindow()
		}
		#expect(automation.activatedWindows.isEmpty)
		#expect(automation.openedURLs.isEmpty)
	}

	@Test
	func dockActivationFailureDoesNotCreateExtraWindows() async throws {
		let automation = FakeSafariWindowAutomation()
		let opener = opener(automation)
		try await opener.activateOrOpenPrivateWindow()
		automation.activationError = PrivateBrowsingError.safariActivationFailed
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener.activateOrOpenPrivateWindow()
		}
		#expect(automation.operations.filter { $0 == "create" }.count == 1)
	}

	@Test
	func dockLaunchChecksPermissionsBeforeReusingAWindow() async throws {
		let automation = FakeSafariWindowAutomation()
		let opener = opener(automation)
		try await opener.activateOrOpenPrivateWindow()
		automation.prepareError = PrivateBrowsingError.accessibilityDenied
		await #expect(throws: PrivateBrowsingError.self) {
			try await opener.activateOrOpenPrivateWindow()
		}
		#expect(automation.operations.last == "prepare")
		#expect(automation.activatedWindows == [2])
	}

	private func opener(_ automation: FakeSafariWindowAutomation) -> SafariPrivateWindowOpener<FakeSafariWindowAutomation> {
		SafariPrivateWindowOpener(automation: automation, pollInterval: .zero,
			maximumPollAttempts: 5, requiredStableSnapshotCount: 1)
	}
}
