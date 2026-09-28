# NightSafari

> Open links in a newly created private Safari window

NightSafari is a lightweight URL handler for browser picker apps and a Dock launcher for private Safari windows. Each group of links is opened in a new private Safari window. It never closes existing Safari windows or tabs.

The main use case is opening a link privately from a browser picker app such as [Velja](https://sindresorhus.com/velja).

Requires macOS 13.5 or later.

## Install

- Download a signed and notarized release from the distributor.
- Move NightSafari to `/Applications`.
- Open NightSafari once, review why each permission is needed, and allow Accessibility access.
- Choose “Request Safari Access” and allow the macOS Automation request.
- Use “Open Test Page Privately” to verify the setup.

If a permission was denied, NightSafari provides buttons that open the corresponding Privacy & Security settings.

## Usage

Open an HTTP or HTTPS URL with NightSafari as you would with a regular browser. For example, enable NightSafari in Velja and select it from the browser prompt.

Keep NightSafari in the Dock and click its icon to open a private Safari window. While NightSafari stays running, later clicks bring forward the most recent private window it opened, restoring it if minimized. If that window was closed or can no longer be verified as private, NightSafari creates a new private window. Windows opened manually in Safari are left alone, and the remembered window is cleared when NightSafari quits.

Right-click NightSafari’s Dock icon and choose “Settings…” to open its settings window. When NightSafari is the frontmost app, its app menu and Command-Comma open the same window; Command-Comma is not a global shortcut. NightSafari stays running after opening links or closing settings; use Quit or Command-Q to exit. Missing permissions and failed requests also reveal settings, where the request can be retried.

Keep Safari’s toolbar visible so NightSafari can verify its private address field. If Safari’s interface cannot be verified, or more than one window appears during setup, NightSafari leaves the links unopened and offers Retry. New incoming links wait behind a failed batch until it is retried.

## Privacy

URLs are processed only on the Mac. NightSafari does not store them or send them to the developer.

## Direct distribution

This project is configured for direct distribution, not the Mac App Store. A public release must be signed with a Developer ID Application certificate, submitted to Apple for notarization, and stapled before packaging.

The Release configuration uses the hardened runtime and does not force an Apple Development signing identity. Use Xcode Organizer’s “Developer ID” distribution flow with the distributor’s Apple Developer account.

The app intentionally does not enable App Sandbox because it uses Accessibility to activate Safari’s New Private Window menu command and verify the browser toolbar, then Safari Automation to load links into that specific window.

Private-window verification reads localized UI descriptions from the installed Safari resources. It does not use webpage titles or content as proof of private browsing. Changes to Safari’s interface or resources may require an update; an unrecognized interface stops navigation.

## License

The code is available under the MIT License. A copy is included in the application bundle.

Safari and its icon are trademarks of Apple Inc. This project is not affiliated with or endorsed by Apple.
