import Foundation
@testable import NightSafari

@MainActor
final class RecordingOpenURLs {
	private(set) var batches: [[URL]] = []
	private(set) var maximumConcurrentCalls = 0
	var failuresRemaining = 0

	private var concurrentCalls = 0

	func open(_ urls: [URL]) async throws {
		concurrentCalls += 1
		maximumConcurrentCalls = max(maximumConcurrentCalls, concurrentCalls)
		batches.append(urls)

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
