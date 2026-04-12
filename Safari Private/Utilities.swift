import SwiftUI


func openPrivateSafariWindow(with urls: [URL]) {
	guard !urls.isEmpty else { return }

	let firstURL = urls[0].absoluteString
	let allURLsScript = urls.map { #"open location "\#($0.absoluteString)""# }.joined(separator: "\n\t\t\t")
	let remainingURLsScript = urls.dropFirst().map { #"open location "\#($0.absoluteString)""# }.joined(separator: "\n\t\t\t")

	runAppleScript(
		#"""
		tell application "System Events"
			set safariRunning to (exists application process "Safari")
		end tell

		tell application "Safari" to activate

		if safariRunning then
			delay 0.2
		else
			delay 1.0
		end if

		set foundPrivateWindow to false

		tell application "System Events"
			tell application process "Safari"
				set frontmost to true
				repeat with w in windows
					if name of w contains "Private Browsing" then
						perform action "AXRaise" of w
						set foundPrivateWindow to true
						exit repeat
					end if
				end repeat
			end tell
		end tell

		if foundPrivateWindow then
			tell application "Safari"
				delay 0.1
				\#(allURLsScript)
			end tell
		else
			tell application "System Events" to tell application process "Safari"
				set frontmost to true
				keystroke "n" using {shift down, command down}
			end tell

			tell application "Safari"
				delay 0.3
				set startPageTab to current tab of front window
				\#(allURLsScript)
				close startPageTab
			end tell
		end if
		"""#
	)
}


@discardableResult
func runAppleScript(_ source: String) -> String? {
	NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
}


enum Permissions {
	enum Accessibility {
		static var hasAccess: Bool { AXIsProcessTrusted() }

		static func requestAccess() -> Bool {
			AXIsProcessTrustedWithOptions([
				kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
			] as CFDictionary)
		}
	}
}
