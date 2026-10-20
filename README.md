# Password Protect

A native macOS app for creating and managing encrypted folder vaults.

## Development

Requirements: macOS 26 or later and Swift 6.0 or later.

The development machine used for validation has macOS 27.0.1 and Swift 6.3.2
with the Command Line Tools SDK. Full Xcode is not installed, so `xcodebuild`
and signed `.app` packaging were not available.

Build the app executable with Swift Package Manager:

```sh
swift build
```

Run the app with:

```sh
swift run PasswordProtect
```

Do not add `.` after `swift run`; SwiftPM treats it as an executable product
name. The command stays attached while the GUI app is running, so it may show
no further terminal output after the build completes. Quit or interrupt the
process to return to the shell.

The app creates AES-256-encrypted sparsebundle images, never deletes the
selected source folder, and does not save passwords. Passwords are passed to
macOS through standard input. The creation workflow also attempts to mount and
eject the new image before reporting success.

This macOS version marks the `hdiutil` create, attach, and detach verbs as
deprecated. The app uses the documented `diskutil image` equivalents for
creating and attaching images, and a normal `diskutil eject` for locking.
Mounted-image discovery uses `hdiutil info`.

Swift Package Manager builds an executable, not a signed or distributable
`.app` bundle. Packaging and Finder Quick Action integration are not included
yet.
