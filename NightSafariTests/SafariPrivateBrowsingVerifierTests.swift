import Testing
@testable import NightSafari

struct SafariPrivateBrowsingVerifierTests {
	private let description = "smart search field in a private window"

	@Test(arguments: ["smart search field in a private window", "私密視窗中的智慧型搜尋欄位", "プライベートウインドウのスマート検索フィールド"])
	func acceptsTheInstalledSafariLocalization(_ description: String) {
		let window = TestSafariAccessibilityNode(role: "AXWindow", children: [
			TestSafariAccessibilityNode(role: "AXToolbar", children: [
				TestSafariAccessibilityNode(role: "AXTextField", accessibilityDescription: description)
			])
		])
		#expect(SafariPrivateBrowsingVerifier.isPrivateWindow(window, addressFieldDescriptions: [description]))
	}

	@Test
	func rejectsOrdinaryAddressFields() {
		let window = TestSafariAccessibilityNode(role: "AXWindow", children: [
			TestSafariAccessibilityNode(role: "AXToolbar", children: [
				TestSafariAccessibilityNode(role: "AXTextField", accessibilityDescription: "smart search field")
			])
		])
		#expect(SafariPrivateBrowsingVerifier.isPrivateWindow(window, addressFieldDescriptions: [description]) == false)
	}

	@Test
	func pageContentCannotImpersonateAPrivateToolbar() {
		let window = TestSafariAccessibilityNode(role: "AXWindow", children: [
			TestSafariAccessibilityNode(role: "AXWebArea", children: [
				TestSafariAccessibilityNode(role: "AXToolbar", children: [
					TestSafariAccessibilityNode(role: "AXTextField", accessibilityDescription: description)
				])
			])
		])
		#expect(SafariPrivateBrowsingVerifier.isPrivateWindow(window, addressFieldDescriptions: [description]) == false)
	}

	@Test
	func windowTitlesAndMissingChromeDoNotProvePrivateBrowsing() {
		let window = TestSafariAccessibilityNode(role: "AXWindow", accessibilityDescription: description)
		#expect(SafariPrivateBrowsingVerifier.isPrivateWindow(window, addressFieldDescriptions: [description]) == false)
	}

	@Test
	func missingSafariTranslationsFailVerification() {
		let window = TestSafariAccessibilityNode(role: "AXWindow", children: [
			TestSafariAccessibilityNode(role: "AXToolbar", children: [
				TestSafariAccessibilityNode(role: "AXTextField", accessibilityDescription: description)
			])
		])
		#expect(SafariPrivateBrowsingVerifier.isPrivateWindow(window, addressFieldDescriptions: []) == false)
	}
}
