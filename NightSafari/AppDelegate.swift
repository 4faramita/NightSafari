import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	let model = ApplicationModel()

	private lazy var settingsWindowController = SettingsWindowController(model: model)
	private var directLaunchTask: Task<Void, Never>?
	private var quitTask: Task<Void, Never>?
	private var receivedURLs = false

	override init() {
		super.init()

		model.onFailure = { [weak self] in
			self?.showSettings()
		}
		model.onQueueDrained = { [weak self] in
			self?.scheduleQuitIfAppropriate()
		}
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		model.refreshPermissions()

		guard receivedURLs == false else { return }

		directLaunchTask = Task { [weak self] in
			do {
				try await Task.sleep(for: .milliseconds(350))
				guard Task.isCancelled == false else { return }
				self?.showSettings()
			} catch {
				return
			}
		}
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		model.refreshPermissions()
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		guard urls.isEmpty == false else { return }

		receivedURLs = true
		directLaunchTask?.cancel()
		quitTask?.cancel()
		model.enqueue(urls)
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		model.isProcessing == false
	}

	private func showSettings() {
		quitTask?.cancel()
		settingsWindowController.show()
	}

	private func scheduleQuitIfAppropriate() {
		guard settingsWindowController.isVisible == false else { return }

		quitTask?.cancel()
		quitTask = Task {
			do {
				try await Task.sleep(for: .seconds(2))
				guard Task.isCancelled == false, model.isProcessing == false else { return }
				NSApp.terminate(nil)
			} catch {
				return
			}
		}
	}
}
