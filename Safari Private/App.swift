import SwiftUI

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	var body: some Scene {
		Settings {}
	}
}

private enum AppTiming {
	static let quitDelay: Duration = .seconds(10)
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
	private var quitTask: Task<Void, Never>?

	func applicationDidFinishLaunching(_ notification: Notification) {
		if !Permissions.Accessibility.hasAccess {
			_ = Permissions.Accessibility.requestAccess()
		}

		scheduleQuit()
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		guard Permissions.Accessibility.hasAccess || Permissions.Accessibility.requestAccess() else {
			let alert = NSAlert()
			alert.messageText = "You need to allow Accessibility and Automation access in “System Settings › Privacy & Security”."
			alert.runModal()
			NSApp.terminate(nil)
			return
		}

		Task { @MainActor in
			await openPrivateSafariWindow(with: urls)
			scheduleQuit()
		}
	}

	@MainActor
	private func scheduleQuit() {
		quitTask?.cancel()

		quitTask = Task {
			do {
				try await Task.sleep(for: AppTiming.quitDelay)
				NSApp.terminate(nil)
			} catch {}
		}
	}
}
