import Foundation

struct SafariInterfaceStrings {
	let newPrivateWindowTitles: Set<String>
	let privateAddressFieldDescriptions: Set<String>

	static func load(safariURL: URL) -> Self {
		// These are Safari's own UI resources, not this app's translations. Read
		// every installed localization because Safari may use a different language.
		let bundles = [
			Bundle(url: safariURL),
			Bundle(path: "/System/Library/PrivateFrameworks/Safari.framework")
		].compactMap { $0 }
		var menuTitles = Set<String>()
		var fieldDescriptions = Set<String>()

		for bundle in bundles {
			for localization in bundle.localizations {
				guard
					let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: localization),
					let data = try? Data(contentsOf: url),
					let strings = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
				else { continue }

				if let title = strings["New Private Window"], title.isEmpty == false {
					menuTitles.insert(title)
				}
				if let description = strings["smart search field in a private window"], description.isEmpty == false {
					fieldDescriptions.insert(description)
				}
			}
		}

		return Self(newPrivateWindowTitles: menuTitles, privateAddressFieldDescriptions: fieldDescriptions)
	}
}
