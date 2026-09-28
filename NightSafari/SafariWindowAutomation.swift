import Foundation

@MainActor
protocol SafariWindowAutomation {
	associatedtype Window: Equatable

	/// Completes permission requests before any window identity is captured.
	func prepare() async throws
	func snapshot() throws -> SafariWindowSnapshot<Window>?
	func createPrivateWindow() throws
	func isPrivateWindow(_ window: Window) -> Bool
	func activate(_ window: Window) throws
	func open(_ urls: [URL], inWindowID windowID: Int) throws
}
