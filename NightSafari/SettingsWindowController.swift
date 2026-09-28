import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
	private let model: ApplicationModel

	init(model: ApplicationModel) {
		self.model = model

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = String(localized: .settingsWindowTitle)
		window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
		window.center()
		window.setFrameAutosaveName("SettingsWindow")
		window.isReleasedWhenClosed = false

		super.init(window: window)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func show() {
		model.refreshPermissions()
		showWindow(nil)
		window?.makeKeyAndOrderFront(nil)
		_ = NSRunningApplication.current.activate(options: [])
	}
}
