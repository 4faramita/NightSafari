import Foundation

struct SafariWindowSnapshot<Window: Equatable>: Equatable {
	let windows: [Window]
	let scriptIDs: Set<Int>

	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.scriptIDs == rhs.scriptIDs
			&& lhs.windows.count == rhs.windows.count
			&& lhs.windows.allSatisfy(rhs.windows.contains)
	}

	/// A one-to-one addition on both surfaces establishes the mapping without
	/// relying on frontmost order, titles, bounds, or private window-server APIs.
	func newWindow(since previous: Self) -> (window: Window, scriptID: Int)? {
		guard
			windows.count == previous.windows.count + 1,
			previous.windows.allSatisfy(windows.contains),
			scriptIDs.isSuperset(of: previous.scriptIDs),
			scriptIDs.count == previous.scriptIDs.count + 1,
			let window = windows.first(where: { previous.windows.contains($0) == false }),
			let scriptID = scriptIDs.subtracting(previous.scriptIDs).first
		else { return nil }

		return (window, scriptID)
	}
}
