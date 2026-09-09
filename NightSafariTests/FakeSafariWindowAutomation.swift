import Foundation
@testable import NightSafari

@MainActor
final class FakeSafariWindowAutomation: SafariWindowAutomation {
	let initial = SafariWindowSnapshot(windows: [1], scriptIDs: Set([101]))
	var createdSnapshots: [SafariWindowSnapshot<Int>?] = [
		SafariWindowSnapshot(windows: [1, 2], scriptIDs: Set([101, 202]))
	]
	var privateWindows: Set<Int> = [2]
	var prepareError: (any Error)?
	var privateChecksBeforeReady = 0
	private(set) var operations: [String] = []
	private(set) var openedWindowIDs: [Int] = []
	private(set) var openedURLs: [[URL]] = []
	private var hasCreatedWindow = false
	private var snapshotIndex = 0

	func prepare() async throws {
		operations.append("prepare")
		if let prepareError { throw prepareError }
	}

	func snapshot() throws -> SafariWindowSnapshot<Int>? {
		operations.append("snapshot")
		guard hasCreatedWindow else { return initial }
		guard createdSnapshots.isEmpty == false else { return nil }
		let result = createdSnapshots[min(snapshotIndex, createdSnapshots.count - 1)]
		snapshotIndex += 1
		return result
	}

	func createPrivateWindow() throws {
		operations.append("create")
		hasCreatedWindow = true
	}

	func isPrivateWindow(_ window: Int) -> Bool {
		operations.append("verify")
		if privateChecksBeforeReady > 0 {
			privateChecksBeforeReady -= 1
			return false
		}
		return privateWindows.contains(window)
	}

	func open(_ urls: [URL], inWindowID windowID: Int) throws {
		operations.append("open")
		openedWindowIDs.append(windowID)
		openedURLs.append(urls)
	}
}
