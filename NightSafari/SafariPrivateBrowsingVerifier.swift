import ApplicationServices

enum SafariPrivateBrowsingVerifier {
	static func isPrivateWindow<Node: SafariAccessibilityNode>(
		_ window: Node,
		addressFieldDescriptions: Set<String>
	) -> Bool {
		guard window.role == kAXWindowRole as String else { return false }
		var remainingNodes = 512
		return containsPrivateAddressField(window, inToolbar: false, depth: 0, remainingNodes: &remainingNodes,
			addressFieldDescriptions: addressFieldDescriptions)
	}

	private static func containsPrivateAddressField<Node: SafariAccessibilityNode>(
		_ node: Node,
		inToolbar: Bool,
		depth: Int,
		remainingNodes: inout Int,
		addressFieldDescriptions: Set<String>
	) -> Bool {
		guard depth < 16, remainingNodes > 0 else { return false }
		remainingNodes -= 1
		let role = node.role
		// Page content can imitate labels and ARIA toolbars. Only browser chrome
		// may supply the evidence that a window is private.
		guard role != "AXWebArea", role != "AXHTMLArea" else { return false }
		let inToolbar = inToolbar || role == kAXToolbarRole as String
		if inToolbar,
			role == kAXTextFieldRole as String || role == kAXComboBoxRole as String,
			let description = node.accessibilityDescription,
			addressFieldDescriptions.contains(description) {
			return true
		}

		for child in node.children {
			if containsPrivateAddressField(child, inToolbar: inToolbar, depth: depth + 1,
				remainingNodes: &remainingNodes, addressFieldDescriptions: addressFieldDescriptions) {
				return true
			}
		}
		return false
	}
}
