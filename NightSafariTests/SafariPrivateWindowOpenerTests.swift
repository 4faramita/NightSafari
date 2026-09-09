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

	private func opener(_ automation: FakeSafariWindowAutomation) -> SafariPrivateWindowOpener<FakeSafariWindowAutomation> {
		SafariPrivateWindowOpener(automation: automation, pollInterval: .zero,
			maximumPollAttempts: 5, requiredStableSnapshotCount: 1)
	}
}
