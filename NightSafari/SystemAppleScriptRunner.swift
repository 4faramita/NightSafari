import AppKit

@MainActor
enum SystemAppleScriptRunner {
	static func run(_ source: String) throws -> NSAppleEventDescriptor {
		guard let script = NSAppleScript(source: source) else {
			throw AppleScriptExecutionError(
				message: String(localized: .errorAppleScriptCreation),
				code: nil
			)
		}

		var error: NSDictionary?
		let output = script.executeAndReturnError(&error)

		guard let error else {
			return output
		}

		throw AppleScriptExecutionError(
			message: (error[NSAppleScript.errorMessage] as? String) ?? String(localized: .errorUnknownAutomation),
			code: error[NSAppleScript.errorNumber] as? Int
		)
	}
}
