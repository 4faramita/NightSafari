import Foundation
@testable import NightSafari

@MainActor
final class RecordingOpenURLs {
	private(set) var batches: [[URL]] = []
	private(set) var requests: [PrivateBrowsingRequest] = []
	private(set) var maximumConcurrentCalls = 0
	var failuresRemaining = 0

	private var concurrentCalls = 0

	func open(_ urls: [URL]) async throws {
		batches.append(urls)
		try await record(.openURLs(urls))
	}

	func openPrivateWindow() async throws {
		try await record(.activatePrivateWindow)
	}

	private func record(_ request: PrivateBrowsingRequest) async throws {
		concurrentCalls += 1
		maximumConcurrentCalls = max(maximumConcurrentCalls, concurrentCalls)
		requests.append(request)

		defer {
			concurrentCalls -= 1
		}

		await Task.yield()

		if failuresRemaining > 0 {
			failuresRemaining -= 1
			throw PrivateBrowsingError.privateWindowUnverified
		}
	}
}
