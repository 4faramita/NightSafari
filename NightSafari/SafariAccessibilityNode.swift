@MainActor
protocol SafariAccessibilityNode {
	var role: String? { get }
	var accessibilityDescription: String? { get }
	var children: [Self] { get }
}
