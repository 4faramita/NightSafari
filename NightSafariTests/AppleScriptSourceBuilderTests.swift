import Foundation
import Testing
@testable import NightSafari

struct AppleScriptSourceBuilderTests {
	@Test
	func opensEveryURLInTheVerifiedWindow() throws {
		let firstURL = try #require(URL(string: "https://example.com/first"))
		let secondURL = try #require(URL(string: "https://example.com/second"))

		let source = AppleScriptSourceBuilder.openURLs([firstURL, secondURL], inWindowID: 123)

		#expect(source.contains("set targetWindow to window id 123"))
		#expect(source.contains("exists window id 123"))
		#expect(source.contains("front window") == false)
		#expect(source.contains("set URL of current tab of targetWindow to \"https://example.com/first\""))
		#expect(source.contains("make new tab at end of tabs of targetWindow"))
		#expect(source.contains("https://example.com/second"))
	}

	@Test
	func neverClosesSafariContent() throws {
		let url = try #require(URL(string: "https://example.com"))

		let source = AppleScriptSourceBuilder.openURLs([url], inWindowID: 123)

		#expect(source.localizedCaseInsensitiveContains("close") == false)
	}

	@Test
	func producesValidAppleScriptSyntax() throws {
		let url = try #require(URL(string: "https://example.com"))
		let script = try #require(NSAppleScript(source: AppleScriptSourceBuilder.openURLs([url], inWindowID: 123)))
		var error: NSDictionary?

		#expect(script.compileAndReturnError(&error))
		#expect(error == nil)
	}
}
