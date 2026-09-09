import ApplicationServices
import Foundation

struct SafariAccessibilityElement: Equatable, SafariAccessibilityNode {
	let element: AXUIElement

	static func == (lhs: Self, rhs: Self) -> Bool {
		CFEqual(lhs.element, rhs.element)
	}

	var role: String? { value(kAXRoleAttribute) as? String }
	var accessibilityDescription: String? { value(kAXDescriptionAttribute) as? String }
	var children: [Self] { elements(kAXChildrenAttribute) ?? [] }

	func value(_ attribute: String) -> CFTypeRef? {
		var value: CFTypeRef?
		guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
		return value
	}

	func elements(_ attribute: String) -> [Self]? {
		(value(attribute) as? [AXUIElement])?.map { Self(element: $0) }
	}
}
