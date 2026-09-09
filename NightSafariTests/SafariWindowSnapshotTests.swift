import Testing
@testable import NightSafari

struct SafariWindowSnapshotTests {
	@Test
	func selectsTheOnlyNewIdentityOnBothSurfaces() throws {
		let before = SafariWindowSnapshot(windows: [1, 2], scriptIDs: Set([101, 202]))
		let after = SafariWindowSnapshot(windows: [2, 3, 1], scriptIDs: Set([101, 202, 303]))
		let target = try #require(after.newWindow(since: before))
		#expect(target.window == 3)
		#expect(target.scriptID == 303)
	}

	@Test(arguments: [
		(windows: [1, 2, 3], ids: [101, 202]),
		(windows: [1, 2], ids: [101, 202, 303]),
		(windows: [2, 3], ids: [101, 202]),
		(windows: [1, 2], ids: [202, 303])
	])
	func rejectsAmbiguousOrReplacedWindows(_ input: (windows: [Int], ids: [Int])) {
		let before = SafariWindowSnapshot(windows: [1], scriptIDs: Set([101]))
		let after = SafariWindowSnapshot(windows: input.windows, scriptIDs: Set(input.ids))
		#expect(after.newWindow(since: before) == nil)
	}
}
