@testable import NightSafari

struct TestSafariAccessibilityNode: SafariAccessibilityNode {
	let role: String?
	var accessibilityDescription: String?
	var children: [Self] = []
}
