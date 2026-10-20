# Password Protect

A macOS convenience app that asks for a PIN inside the app before opening a
selected folder in Finder.

> **Not security:** Ordinary macOS folders do not support password prompts.
> Finder and other apps can still open a folder directly without this app.
> This PIN gate only controls the app's own Open Folder action; it does not
> encrypt or protect folder contents.

## Use

1. Build and launch the app bundle:
   ```sh
   sh Scripts/package-app.sh
   ```
2. Choose **Set or Change Folder PIN**, select the original folder, then enter
   and confirm a numeric PIN. The app saves a salted PIN verifier locally and
   opens the original folder in Finder.
3. Later, choose **Enter PIN and Open Folder**, select the same folder, and
   enter the PIN. A matching PIN opens the original folder in Finder; an
   incorrect PIN is rejected by the app.

The PIN verifier is stored in this Mac user's app preferences and is not stored
as plaintext. Because this is a convenience gate rather than a security
boundary, someone with access to the Mac can bypass the app and open the folder
directly.

## Development

Requirements: macOS 26 or later and Swift 6.0 or later.

Build the executable with Swift Package Manager:

```sh
swift build
```

Run the folder-PIN smoke tests with the installed Command Line Tools:

```sh
sh Scripts/test-folder-pin.sh
```

Run it directly during development:

```sh
swift run PasswordProtect
```

Direct SwiftPM launch opens the main app window. The development machine has
macOS 27.0.1 and Swift 6.3.2; full Xcode is not installed.
