import Foundation

enum PrivateBrowsingError: LocalizedError {
	case accessibilityDenied
	case safariUnavailable
	case safariLaunchFailed(String)
	case safariNotReady
	case safariActivationFailed
	case automationRequired
	case privateWindowCommandUnavailable
	case privateWindowUnverified
	case automationFailed(AppleScriptExecutionError)

	var isAutomationDenied: Bool {
		guard case .automationFailed(let error) = self else { return false }
		return error.code == -1743
	}

	var errorDescription: String? {
		switch self {
		case .accessibilityDenied:
			String(localized: .errorAccessibilityDenied)
		case .safariUnavailable:
			String(localized: .errorSafariUnavailable)
		case .safariLaunchFailed(let message):
			String(localized: .errorSafariLaunchFailed(message))
		case .safariNotReady:
			String(localized: .errorSafariNotReady)
		case .safariActivationFailed:
			String(localized: .errorSafariActivationFailed)
		case .automationRequired:
			String(localized: .errorAutomationRequired)
		case .privateWindowCommandUnavailable:
			String(localized: .errorPrivateWindowCommandUnavailable)
		case .privateWindowUnverified:
			String(localized: .errorPrivateWindowUnverified)
		case .automationFailed(let error) where error.code == -1743:
			String(localized: .errorAutomationDenied)
		case .automationFailed(let error):
			String(localized: .errorAutomationFailed(error.localizedDescription))
		}
	}
}
