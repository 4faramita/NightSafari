import Foundation

struct AppleScriptExecutionError: LocalizedError, Equatable {
	let message: String
	let code: Int?

	var errorDescription: String? {
		if let code {
			return "\(message) (code: \(code))"
		}

		return message
	}
}
