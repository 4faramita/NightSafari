import Foundation

struct AppPresentationError: Identifiable {
	let id = UUID()
	let message: String

	init(_ error: Error) {
		message = error.localizedDescription
	}
}
