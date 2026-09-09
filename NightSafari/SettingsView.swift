import SwiftUI

struct SettingsView: View {
	@ObservedObject var model: ApplicationModel

	var body: some View {
		Form {
			Section {
				Text(.settingsExplanation)
					.fixedSize(horizontal: false, vertical: true)
			} header: {
				Text(.settingsTitle)
			}

			Section {
				LabeledContent(String(localized: .settingsAccessibility)) {
					PermissionStatusLabel(
						status: model.accessibilityGranted ? .granted : .denied
					)
				}

				HStack {
					Button(.settingsRequestAccessibility) {
						model.requestAccessibility()
					}
					.disabled(model.accessibilityGranted)

					Button(.settingsOpenAccessibility) {
						model.openAccessibilitySettings()
					}
				}

				LabeledContent(String(localized: .settingsAutomation)) {
					PermissionStatusLabel(status: model.automationStatus)
				}

				Text(automationGuidance)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if model.automationStatus == .notDetermined {
					HStack {
						Button(.settingsRequestAutomation, systemImage: "hand.raised") {
							model.requestAutomation()
						}
						.disabled(model.isRequestingAutomation)

						if model.isRequestingAutomation {
							ProgressView()
								.controlSize(.small)
							Text(.settingsRequestingAutomation)
								.foregroundStyle(.secondary)
						}
					}
				} else if model.shouldShowAutomationSettings {
					Button(.settingsOpenAutomation) {
						model.openAutomationSettings()
					}
				}
			} header: {
				Text(.settingsPermissionsHeader)
			} footer: {
				Text(.settingsPermissionsFooter)
			}

			Section {
				HStack {
					Button(.settingsTest, systemImage: "globe") {
						model.openTestPage()
					}
					.disabled(model.canOpenTestPage == false)

					if model.canRetry {
						Button(.settingsRetry, systemImage: "arrow.clockwise") {
							model.retry()
						}
						.disabled(model.canRetryNow == false)
					}

					if model.isProcessing {
						ProgressView()
							.controlSize(.small)
						Text(.settingsOpening)
							.foregroundStyle(.secondary)
					}
				}
			} header: {
				Text(.settingsActionsHeader)
			}

			Section {
				Text(.settingsPrivacy)
					.fixedSize(horizontal: false, vertical: true)
			} header: {
				Text(.settingsPrivacyHeader)
			}
		}
		.formStyle(.grouped)
		.padding()
		.frame(minWidth: 500, minHeight: 480)
		.task {
			model.refreshPermissions()
		}
		.alert(
			String(localized: .errorTitle),
			isPresented: Binding(
				get: { model.presentedError != nil },
				set: { isPresented in
					if isPresented == false {
						model.presentedError = nil
					}
				}
			),
			presenting: model.presentedError
		) { _ in
			Button(.buttonOk, role: .cancel) {}
		} message: { error in
			Text(error.message)
		}
	}

	private var automationGuidance: LocalizedStringResource {
		switch model.automationStatus {
		case .notDetermined:
			.settingsAutomationNotRequested
		case .granted:
			.settingsAutomationGrantedHelp
		case .denied:
			.settingsAutomationDeniedHelp
		}
	}
}
