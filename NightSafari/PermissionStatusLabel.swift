import SwiftUI

struct PermissionStatusLabel: View {
	let status: PermissionStatus

	var body: some View {
		Label(title, systemImage: symbolName)
			.foregroundStyle(color)
	}

	private var title: String {
		switch status {
		case .notDetermined:
			String(localized: .permissionNotDetermined)
		case .granted:
			String(localized: .permissionGranted)
		case .denied:
			String(localized: .permissionDenied)
		}
	}

	private var symbolName: String {
		switch status {
		case .notDetermined:
			"questionmark.circle"
		case .granted:
			"checkmark.circle.fill"
		case .denied:
			"exclamationmark.triangle.fill"
		}
	}

	private var color: Color {
		switch status {
		case .notDetermined:
			.secondary
		case .granted:
			.green
		case .denied:
			.orange
		}
	}
}
