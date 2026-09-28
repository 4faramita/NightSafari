import AppKit
import Testing
@testable import NightSafari

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppDelegateTests {
	@Test
	func directLaunchOpensPrivateBrowsing() async {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder)
		var settingsRequests = 0
		let delegate = AppDelegate(model: model, directLaunchDelay: .zero) { settingsRequests += 1 }
		await withCheckedContinuation { continuation in
			model.onQueueDrained = { continuation.resume() }
			delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
		}
		#expect(recorder.requests == [.activatePrivateWindow])
		#expect(settingsRequests == 0)
	}

	@Test(arguments: [true, false])
	func dockReopenOpensPrivateBrowsingRegardlessOfSettingsVisibility(hasVisibleWindows: Bool) async {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder)
		var settingsRequests = 0
		let delegate = AppDelegate(model: model) { settingsRequests += 1 }
		let shouldReopenWindows = delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: hasVisibleWindows)
		await waitUntilQueueDrains(model)
		#expect(shouldReopenWindows == false)
		#expect(recorder.requests == [.activatePrivateWindow])
		#expect(settingsRequests == 0)
	}

	@Test(arguments: [true, false])
	func URLLaunchDoesNotAlsoOpenAnEmptyWindow(urlsArriveBeforeLaunch: Bool) async throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder)
		let delegate = AppDelegate(model: model, directLaunchDelay: .zero, showSettingsAction: {})
		let url = try #require(URL(string: "https://example.com"))
		let launch = Notification(name: NSApplication.didFinishLaunchingNotification)
		if urlsArriveBeforeLaunch {
			delegate.application(.shared, open: [url])
			delegate.applicationDidFinishLaunching(launch)
		} else {
			delegate.applicationDidFinishLaunching(launch)
			delegate.application(.shared, open: [url])
		}
		await waitUntilQueueDrains(model)
		#expect(recorder.requests == [.openURLs([url])])
	}

	@Test
	func reopenDuringLaunchDoesNotDuplicateThePrivateWindowRequest() async {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder)
		let delegate = AppDelegate(model: model, directLaunchDelay: .zero, showSettingsAction: {})
		delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
		_ = delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false)
		await waitUntilQueueDrains(model)
		#expect(recorder.requests == [.activatePrivateWindow])
	}

	@Test
	func dockSettingsMenuUsesTheSharedSettingsAction() throws {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder)
		var settingsRequests = 0
		let delegate = AppDelegate(model: model) { settingsRequests += 1 }
		let menu = try #require(delegate.applicationDockMenu(.shared))
		let item = try #require(menu.items.first)
		#expect(item.title == String(localized: .menuSettings))
		#expect(item.target === delegate)
		let action = try #require(item.action)
		#expect(NSApplication.shared.sendAction(action, to: item.target, from: item))
		#expect(settingsRequests == 1)
		#expect(recorder.requests.isEmpty)
		#expect(delegate.applicationShouldTerminateAfterLastWindowClosed(.shared) == false)
	}

	@Test
	func choosingSettingsBeforeLaunchFinishesSuppressesPrivateBrowsing() {
		let recorder = RecordingOpenURLs()
		let model = makeModel(recorder)
		var settingsRequests = 0
		let delegate = AppDelegate(model: model) { settingsRequests += 1 }
		delegate.showSettings()
		delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
		#expect(settingsRequests == 1)
		#expect(model.isProcessing == false)
		#expect(recorder.requests.isEmpty)
	}

	@Test
	func failedDockRequestShowsSettingsAndRemainsRetryable() async {
		let recorder = RecordingOpenURLs()
		recorder.failuresRemaining = 1
		let model = makeModel(recorder)
		var settingsRequests = 0
		let delegate = AppDelegate(model: model) { settingsRequests += 1 }
		_ = delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false)
		await waitUntilQueueDrains(model)
		#expect(settingsRequests == 1)
		#expect(model.canRetry)
		#expect(model.presentedError != nil)
	}

	private func makeModel(_ recorder: RecordingOpenURLs) -> ApplicationModel {
		ApplicationModel(openURLsAction: recorder.open, openPrivateWindowAction: recorder.openPrivateWindow,
			accessibilityStatus: { true }, requestAccessibilityAction: {},
			automationStatusAction: { nil }, requestAutomationAction: { .granted })
	}

	private func waitUntilQueueDrains(_ model: ApplicationModel) async {
		guard model.isProcessing else { return }
		await withCheckedContinuation { continuation in
			model.onQueueDrained = { continuation.resume() }
		}
		model.onQueueDrained = nil
	}
}
