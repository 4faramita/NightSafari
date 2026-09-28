import SwiftUI

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	var body: some Scene {
		Settings {
			SettingsView(model: appDelegate.model)
		}
		.commands {
			CommandGroup(replacing: .appSettings) {
				Button(.menuSettings) {
					appDelegate.showSettings()
				}
				.keyboardShortcut(",", modifiers: .command)
			}
		}
	}
}
