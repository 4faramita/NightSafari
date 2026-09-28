import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	let model: ApplicationModel

	private lazy var settingsWindowController = SettingsWindowController(model: model)
	private let showSettingsAction: (() -> Void)?
	private let directLaunchDelay: Duration
	private var directLaunchTask: Task<Void, Never>?
	private var receivedLaunchRequest = false

	override convenience init() {
		self.init(model: ApplicationModel())
		// Hosted tests must not control Safari when the app launches as their test runner.
		receivedLaunchRequest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
	}

	init(model: ApplicationModel, directLaunchDelay: Duration = .milliseconds(350),
		showSettingsAction: (() -> Void)? = nil) {
		self.model = model
		self.directLaunchDelay = directLaunchDelay
		self.showSettingsAction = showSettingsAction
		super.init()

		model.onFailure = { [weak self] in
			self?.showSettings()
		}
	}

	isolated deinit {
		directLaunchTask?.cancel()
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		model.refreshPermissions()

		guard receivedLaunchRequest == false else { return }

		let delay = directLaunchDelay
		directLaunchTask = Task { [weak self] in
			do {
				try await Task.sleep(for: delay)
				guard Task.isCancelled == false else { return }
				self?.model.openPrivateWindow()
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

		receivedLaunchRequest = true
		directLaunchTask?.cancel()
		model.enqueue(urls)
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		receivedLaunchRequest = true
		directLaunchTask?.cancel()
		model.openPrivateWindow()
		return false
	}

	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		let menu = NSMenu()
		let settingsItem = NSMenuItem(title: String(localized: .menuSettings),
			action: #selector(showSettings), keyEquivalent: "")
		settingsItem.target = self
		menu.addItem(settingsItem)
		return menu
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		false
	}

	@objc func showSettings() {
		receivedLaunchRequest = true
		directLaunchTask?.cancel()
		if let showSettingsAction {
			showSettingsAction()
		} else {
			settingsWindowController.show()
		}
	}
}
