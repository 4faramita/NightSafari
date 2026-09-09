import Foundation

enum AppleScriptSourceBuilder {
	static let windowIDs = "tell application id \"com.apple.Safari\" to get id of every window"

	static func openURLs(_ urls: [URL], inWindowID windowID: Int) -> String {
		let commands = urls.enumerated().map { index, url in
			let escapedURL = url.absoluteString.appleScriptEscaped

			if index == 0 {
				return "set URL of current tab of targetWindow to \"\(escapedURL)\""
			}

			return "set current tab of targetWindow to (make new tab at end of tabs of targetWindow with properties {URL:\"\(escapedURL)\"})"
		}

		return """
		tell application id "com.apple.Safari"
			if not (exists window id \(windowID)) then error "The verified Safari window is no longer available." number -1719
			set targetWindow to window id \(windowID)
			\(commands.joined(separator: "\n\t"))
			return id of targetWindow as text
		end tell
		"""
	}
}

private extension String {
	var appleScriptEscaped: String {
		replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\"", with: "\\\"")
			.replacingOccurrences(of: "\r", with: "\\r")
			.replacingOccurrences(of: "\n", with: "\\n")
	}
}
