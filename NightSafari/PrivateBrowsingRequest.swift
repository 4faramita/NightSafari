import Foundation

enum PrivateBrowsingRequest: Equatable {
	case openURLs([URL])
	case activatePrivateWindow
}
