import Combine
import Foundation

@MainActor
final class ApplicationModel: ObservableObject {
	typealias OpenURLsAction = @MainActor ([URL]) async throws -> Void
	typealias AutomationStatusAction = @MainActor () async -> PermissionStatus?
	typealias RequestAutomationAction = @MainActor () async throws -> PermissionStatus

	@Published private(set) var accessibilityGranted = false
	@Published private(set) var automationStatus = PermissionStatus.notDetermined
	@Published private(set) var isProcessing = false
	@Published private(set) var isRequestingAutomation = false
	@Published private(set) var canRetry = false
	@Published var presentedError: AppPresentationError?

	var canOpenTestPage: Bool {
		accessibilityGranted
			&& automationStatus == .granted
			&& isProcessing == false
			&& canRetry == false
	}

	var canRetryNow: Bool {
		canRetry
			&& accessibilityGranted
			&& automationStatus != .denied
			&& isProcessing == false
	}

	var shouldShowAutomationSettings: Bool {
		automationStatus == .denied
	}

	var onFailure: (() -> Void)?
	var onQueueDrained: (() -> Void)?

	private let openURLsAction: OpenURLsAction
	private let accessibilityStatus: () -> Bool
	private let requestAccessibilityAction: () -> Void
	private let automationStatusAction: AutomationStatusAction
	private let requestAutomationAction: RequestAutomationAction
	private var queue: [[URL]] = []
	private var retryBatch: [URL]?
	private var processingTask: Task<Void, Never>?
	private var automationRefreshTask: Task<Void, Never>?
	private var automationRequestTask: Task<Void, Never>?

	init(
		openURLsAction: @escaping OpenURLsAction = { urls in
			try await SafariPrivateWindowOpener().open(urls)
		},
		accessibilityStatus: @escaping () -> Bool = { SystemAccessibilityPermission.hasAccess },
		requestAccessibilityAction: @escaping () -> Void = { SystemAccessibilityPermission.requestAccess() },
		automationStatusAction: @escaping AutomationStatusAction = {
			await SystemAutomationPermission.currentStatus()
		},
		requestAutomationAction: @escaping RequestAutomationAction = {
			try await SystemAutomationPermission.requestAccess()
		}
	) {
		self.openURLsAction = openURLsAction
		self.accessibilityStatus = accessibilityStatus
		self.requestAccessibilityAction = requestAccessibilityAction
		self.automationStatusAction = automationStatusAction
		self.requestAutomationAction = requestAutomationAction
		accessibilityGranted = accessibilityStatus()
	}

	isolated deinit {
		processingTask?.cancel()
		automationRefreshTask?.cancel()
		automationRequestTask?.cancel()
	}

	func refreshPermissions() {
		accessibilityGranted = accessibilityStatus()
		guard automationRefreshTask == nil, automationRequestTask == nil else { return }

		let action = automationStatusAction
		automationRefreshTask = Task { [weak self] in
			let status = await action()
			guard let self else { return }

			if Task.isCancelled == false, let status {
				automationStatus = status
			}
			automationRefreshTask = nil
		}
	}

	func requestAccessibility() {
		requestAccessibilityAction()
		refreshPermissions()
	}

	func openAccessibilitySettings() {
		SystemAccessibilityPermission.openSettings()
	}

	func openAutomationSettings() {
		guard shouldShowAutomationSettings else { return }
		SystemAutomationPermission.openSettings()
	}

	func requestAutomation() {
		guard automationStatus == .notDetermined, automationRequestTask == nil else { return }

		automationRefreshTask?.cancel()
		automationRefreshTask = nil
		isRequestingAutomation = true
		let action = requestAutomationAction
		automationRequestTask = Task { [weak self] in
			do {
				let status = try await action()
				guard let self else { return }
				automationStatus = status
			} catch is CancellationError {
				// Cancellation is expected when the model is released.
			} catch {
				guard let self else { return }
				presentedError = AppPresentationError(error)
			}

			guard let self else { return }
			isRequestingAutomation = false
			automationRequestTask = nil
		}
	}

	func enqueue(_ urls: [URL]) {
		let supportedURLs = urls.filter(\.isSupportedNavigationURL)
		guard supportedURLs.isEmpty == false else { return }

		queue.append(supportedURLs)
		startProcessingIfNeeded()
	}

	func openTestPage() {
		guard canOpenTestPage, let testURL = URL(string: "https://example.com") else { return }
		enqueue([testURL])
	}

	func retry() {
		guard canRetryNow, let retryBatch else { return }

		self.retryBatch = nil
		canRetry = false
		presentedError = nil
		queue.insert(retryBatch, at: 0)
		startProcessingIfNeeded()
	}

	private func startProcessingIfNeeded() {
		guard processingTask == nil, retryBatch == nil else { return }

		isProcessing = true
		processingTask = Task { [weak self] in
			await self?.drainQueue()
		}
	}

	private func drainQueue() async {
		while Task.isCancelled == false, queue.isEmpty == false {
			let urls = queue.removeFirst()

			do {
				try await openURLsAction(urls)
				automationStatus = .granted
				retryBatch = nil
				canRetry = false
			} catch is CancellationError {
				queue.insert(urls, at: 0)
				break
			} catch let error as PrivateBrowsingError {
				if error.isAutomationDenied {
					automationStatus = .denied
				}

				retryBatch = urls
				canRetry = true
				presentedError = AppPresentationError(error)
				onFailure?()
				break
			} catch {
				retryBatch = urls
				canRetry = true
				presentedError = AppPresentationError(error)
				onFailure?()
				break
			}
		}

		processingTask = nil
		isProcessing = false
		onQueueDrained?()
	}
}

private extension URL {
	var isSupportedNavigationURL: Bool {
		guard let scheme = scheme?.lowercased() else { return false }
		return ["http", "https", "file"].contains(scheme)
	}
}
