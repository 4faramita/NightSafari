import Combine
import Foundation
import Testing
@testable import NightSafari

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ApplicationModelTests {
	@Test
	func processesIncomingBatchesSeriallyInOrder() async throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder: recorder)
		let firstURL = try #require(URL(string: "https://example.com/first"))
		let secondURL = try #require(URL(string: "https://example.com/second"))

		model.enqueue([firstURL])
		model.enqueue([secondURL])
		await waitUntilQueueDrains(model)

		#expect(recorder.batches == [[firstURL], [secondURL]])
		#expect(recorder.maximumConcurrentCalls == 1)
	}

	@Test
	func preservesFailedBatchForRetry() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder: recorder)
		let url = try #require(URL(string: "https://example.com"))

		model.enqueue([url])
		await waitUntilQueueDrains(model)
		#expect(model.canRetry)
		#expect(model.presentedError != nil)

		model.retry()
		await waitUntilQueueDrains(model)
		#expect(recorder.batches == [[url], [url]])
		#expect(model.canRetry == false)
	}

	@Test
	func doesNotRetryUntilRequiredPermissionsAreAvailable() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder: recorder, accessibilityGranted: false)
		let url = try #require(URL(string: "https://example.com"))

		model.enqueue([url])
		await waitUntilQueueDrains(model)
		#expect(model.canRetry)
		#expect(model.canRetryNow == false)

		model.retry()
		#expect(recorder.batches == [[url]])
	}

	@Test
	func requestingAutomationUpdatesPermissionState() async throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(
			recorder: recorder,
			requestAutomationAction: { .granted }
		)

		model.requestAutomation()
		await waitForAutomationRequest(model)

		#expect(model.automationStatus == .granted)
		#expect(model.canOpenTestPage)
		#expect(model.shouldShowAutomationSettings == false)
	}

	@Test
	func deniedAutomationRevealsSystemSettingsAction() async throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(
			recorder: recorder,
			requestAutomationAction: { .denied }
		)

		model.requestAutomation()
		await waitForAutomationRequest(model)

		#expect(model.automationStatus == .denied)
		#expect(model.shouldShowAutomationSettings)
		#expect(model.canOpenTestPage == false)
	}

	@Test
	func refreshesKnownAutomationStatus() async throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(
			recorder: recorder,
			automationStatusAction: { .granted }
		)

		model.refreshPermissions()
		await waitForAutomationStatus(.granted, in: model)

		#expect(model.canOpenTestPage)
	}

	@Test
	func resumesQueuedBatchesInOrderAfterRetry() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder: recorder)
		let firstURL = try #require(URL(string: "https://example.com/first"))
		let secondURL = try #require(URL(string: "https://example.com/second"))

		model.enqueue([firstURL])
		model.enqueue([secondURL])
		await waitUntilQueueDrains(model)
		#expect(recorder.batches == [[firstURL]])

		model.retry()
		await waitUntilQueueDrains(model)
		#expect(recorder.batches == [[firstURL], [firstURL], [secondURL]])
	}

	@Test
	func ignoresUnsupportedURLSchemes() throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder: recorder)
		let mailURL = try #require(URL(string: "mailto:person@example.com"))

		model.enqueue([mailURL])

		#expect(model.isProcessing == false)
		#expect(recorder.batches.isEmpty)
	}

	@Test
	func laterArrivalsWaitForTheFailedBatchToBeRetried() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder: recorder)
		let first = try #require(URL(string: "https://example.com/failed"))
		let second = try #require(URL(string: "https://example.com/queued"))
		let third = try #require(URL(string: "https://example.com/later"))

		model.enqueue([first])
		model.enqueue([second])
		await waitUntilQueueDrains(model)
		model.enqueue([third])
		#expect(model.isProcessing == false)
		await waitUntilQueueDrains(model)
		#expect(model.canRetry)
		#expect(recorder.batches == [[first]])

		model.retry()
		await waitUntilQueueDrains(model)
		#expect(recorder.batches == [[first], [first], [second], [third]])
		#expect(model.canRetry == false)
	}

	@Test
	func setupTestCannotDiscardThePendingRetry() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder: recorder)
		model.requestAutomation()
		await waitForAutomationRequest(model)
		let url = try #require(URL(string: "https://example.com/failed"))

		model.enqueue([url])
		await waitUntilQueueDrains(model)
		#expect(model.canOpenTestPage == false)
		model.openTestPage()
		await waitUntilQueueDrains(model)
		#expect(model.canRetry)
		#expect(recorder.batches == [[url]])

		model.retry()
		await waitUntilQueueDrains(model)
		#expect(recorder.batches == [[url], [url]])
		#expect(model.canOpenTestPage)
	}

	@Test
	func repeatedFailuresKeepTheFirstBatchAheadOfLaterArrivals() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 2
		let model = makeModel(recorder: recorder)
		let first = try #require(URL(string: "https://example.com/failed"))
		let second = try #require(URL(string: "https://example.com/later"))
		model.enqueue([first])
		await waitUntilQueueDrains(model)
		model.enqueue([second])
		model.retry()
		await waitUntilQueueDrains(model)
		#expect(model.canRetry)
		#expect(recorder.batches == [[first], [first]])
		model.retry()
		await waitUntilQueueDrains(model)
		#expect(recorder.batches == [[first], [first], [first], [second]])
	}

	@Test
	func dockRequestsAndIncomingURLsUseTheSameSerialQueue() async throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder: recorder)
		let url = try #require(URL(string: "https://example.com"))
		model.openPrivateWindow()
		model.enqueue([url])
		await waitUntilQueueDrains(model)
		#expect(recorder.requests == [.activatePrivateWindow, .openURLs([url])])
		#expect(recorder.maximumConcurrentCalls == 1)
	}

	@Test
	func repeatedDockClicksAreCoalescedWhileAnOpenIsPending() async {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder: recorder)
		model.openPrivateWindow()
		model.openPrivateWindow()
		await waitUntilQueueDrains(model)
		#expect(recorder.requests == [.activatePrivateWindow])
		model.openPrivateWindow()
		await waitUntilQueueDrains(model)
		#expect(recorder.requests == [.activatePrivateWindow, .activatePrivateWindow])
	}

	@Test
	func failedDockRequestIsRetriedBeforeLaterURLs() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder: recorder)
		let url = try #require(URL(string: "https://example.com"))
		model.openPrivateWindow()
		model.enqueue([url])
		await waitUntilQueueDrains(model)
		#expect(model.canRetry)
		#expect(model.presentedError != nil)
		model.retry()
		await waitUntilQueueDrains(model)
		#expect(recorder.requests == [.activatePrivateWindow, .activatePrivateWindow, .openURLs([url])])
		#expect(model.canRetry == false)
	}

	@Test
	func dockClickRevealsSettingsWithoutDiscardingFailedURLs() async throws {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder: recorder)
		let url = try #require(URL(string: "https://example.com"))
		model.enqueue([url])
		await waitUntilQueueDrains(model)
		var settingsRequests = 0
		model.onFailure = { settingsRequests += 1 }
		model.openPrivateWindow()
		#expect(settingsRequests == 1)
		#expect(recorder.requests == [.openURLs([url])])
		model.retry()
		await waitUntilQueueDrains(model)
		#expect(recorder.requests == [.openURLs([url]), .openURLs([url])])
	}

	private func makeModel(
		recorder: RecordingOpenURLs,
		accessibilityGranted: Bool = true,
		automationStatusAction: @escaping ApplicationModel.AutomationStatusAction = { nil },
		requestAutomationAction: @escaping ApplicationModel.RequestAutomationAction = { .granted }
	) -> ApplicationModel {
		ApplicationModel(
			openURLsAction: recorder.open,
			openPrivateWindowAction: recorder.openPrivateWindow,
			accessibilityStatus: { accessibilityGranted },
			requestAccessibilityAction: {},
			automationStatusAction: automationStatusAction,
			requestAutomationAction: requestAutomationAction
		)
	}

	private func waitUntilQueueDrains(_ model: ApplicationModel) async {
		guard model.isProcessing else { return }
		await withCheckedContinuation { continuation in
			model.onQueueDrained = { continuation.resume() }
		}
		model.onQueueDrained = nil
	}

	private func waitForAutomationRequest(_ model: ApplicationModel) async {
		for await isRequesting in model.$isRequestingAutomation.values {
			if isRequesting == false { return }
		}
	}

	private func waitForAutomationStatus(_ status: PermissionStatus, in model: ApplicationModel) async {
		for await current in model.$automationStatus.values {
			if current == status { return }
		}
	}
}
