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

		if not safariRunning then
			repeat 40 times
				delay 0.05
				tell application "System Events"
					if exists application process "Safari" then exit repeat
				end tell
			end repeat
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
				\#(allURLsScript)
			end tell
		else
			tell application "Safari"
				set windowCountBefore to count of windows
			end tell

			tell application "System Events" to tell application process "Safari"
				set frontmost to true
				keystroke "n" using {shift down, command down}
			end tell

			tell application "Safari"
				repeat 20 times
					if (count of windows) > windowCountBefore then exit repeat
					delay 0.05
				end repeat
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
