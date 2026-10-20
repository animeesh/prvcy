# Password Protect — macOS App

## 1. Project Overview

Build a lightweight macOS application that allows a user to password-protect
a specific folder containing private documents, such as financial records,
salary details, and bank documents.

The application should provide a simple, native Mac experience with minimal
user interaction.

The app must use actual encryption. A password prompt alone is not sufficient
to protect files.

## 2. Primary Goals

- Create a password-protected vault from a selected folder.
- Require a password to unlock the vault.
- Open unlocked vaults in Finder.
- Allow the user to lock the vault again.
- Provide a simple graphical interface.
- Eventually add a Finder Quick Action named "Password Protect".
- Keep everything local to the Mac.
- Avoid external servers, cloud storage, and unnecessary dependencies.

## 3. Technology Stack

Language: Swift

Platform: macOS

Editor: Visual Studio Code

Encryption and vault storage:
- Use macOS encrypted disk images.
- Use the built-in `hdiutil` utility.
- Support AES-256 encryption where available.
- Never implement custom cryptographic algorithms.
- Never store passwords in plaintext.

User interface:
- Use SwiftUI where practical.
- Prefer native macOS controls and dialogs.

Finder integration:
- Investigate macOS Shortcuts, Finder Quick Actions, and Automator.
- Implement folder protection through a Quick Action in a later phase.

## 4. Expected User Experience

### Workflow A: Protect a Folder

1. Open the Password Protect application.
2. Select "Protect a Folder".
3. Choose an existing folder in Finder.
4. Choose the destination for the encrypted vault.
5. Enter a password.
6. Confirm the password.
7. Create the encrypted disk image.
8. Verify that the vault was created successfully.
9. Display the vault location and next steps.

The original folder must remain untouched until the user explicitly
confirms that the vault works and requests removal of the original.

Never automatically delete the source folder.

### Workflow B: Unlock a Vault

1. Double-click an encrypted vault file or select "Unlock Vault" in the app.
2. Request the vault password.
3. Pass the password securely to macOS's disk-image utility.
4. Mount the vault only after successful authentication.
5. Open the mounted volume in Finder.
6. Display a clear success or error message.

### Workflow C: Lock a Vault

1. The user selects "Lock Vault".
2. The app identifies the mounted vault volume.
3. The app requests that the volume be unmounted.
4. If files are in use, explain why locking failed and how to retry.
5. Confirm successful unmounting.

Do not report a vault as locked until unmounting succeeds.

## 5. User Interface

The main window should contain:

- Protect a Folder
- Unlock a Vault
- Lock a Vault
- Help / About

Protect a Folder should provide:
- Folder selection dialog
- Vault destination selection
- Password entry
- Password confirmation
- Creation progress
- Success or failure message

Unlock a Vault should provide:
- Vault selection
- Password prompt
- Unlock progress
- Open in Finder after successful mounting

Keep the interface minimal and easy to understand.

Do not display passwords in logs, error messages, or terminal output.

## 6. Security Requirements

Security is a core requirement.

- Use genuine encrypted disk images, not hidden folders.
- Prefer AES-256 encryption where supported.
- Never save passwords in source code or configuration files.
- Never log passwords.
- Avoid command-line arguments that expose passwords in process listings.
- Use a secure mechanism for supplying passwords to system utilities.
- Do not enable automatic password saving in Keychain by default.
- Do not overwrite an existing vault without explicit confirmation.
- Do not delete original files automatically.
- Handle incorrect passwords safely.
- Handle interrupted vault creation.
- Ensure mounted vaults are unmounted before reporting them as locked.
- Explain that files remain accessible while the vault is mounted.
- Do not claim secure deletion of the original files or backups.
- Avoid unnecessary administrator privileges.

Investigate whether the chosen macOS command-line interface supports
secure password input through standard input or another protected mechanism.
Do not assume that every `hdiutil` operation supports the same options.

Never put a password directly into a shell command string.

Use Foundation Process APIs or another safe process-launching mechanism.
Do not construct shell commands by concatenating user-provided paths.

## 7. Vault Creation

Use macOS's `hdiutil` utility to create an encrypted disk image.

Before implementing this feature:

1. Inspect the available `hdiutil` options on the target Mac.
2. Determine a reliable method to create an encrypted image from a folder.
3. Determine how passwords can be supplied without exposing them.
4. Handle spaces and special characters in file paths.
5. Handle large folders and insufficient disk space.
6. Prevent accidental overwriting of existing vaults.
7. Verify that the created vault can actually be mounted.

Do not assume that a disk-image command succeeded merely because the
process started. Check its exit status and verify the resulting file.

Prefer a sparse-bundle or another suitable image format if it provides
a better fit for the intended workflow. Explain the trade-offs before
choosing a format.

## 8. Project Structure

Use a clean and maintainable project structure.

Suggested organization:

PasswordProtect/
├── README.md
├── PROJECT_SPEC.md
├── Sources/
│   ├── PasswordProtectApp.swift
│   ├── ContentView.swift
│   ├── VaultService.swift
│   ├── DiskImageService.swift
│   ├── PasswordPromptView.swift
│   └── ProcessRunner.swift
└── Tests/
    └── VaultServiceTests.swift

Adapt the structure to the build system chosen for the project.

Do not create unnecessary abstractions or dependencies.

Separate user-interface code from disk-image operations.

## 9. Finder Integration

Implement this after the core application works.

Desired behavior:

1. Right-click a folder in Finder.
2. Select "Password Protect".
3. Launch the app or invoke its folder-protection workflow.
4. Select a destination and set a password.
5. Create the encrypted vault.

Investigate the most practical supported macOS integration.

Do not claim that Finder can intercept every double-click on an ordinary
folder. Standard Finder extensions and Quick Actions do not provide a
universal mechanism for intercepting arbitrary folder-opening operations.

The encrypted vault should be opened through macOS's supported disk-image
mounting mechanism.

## 10. Error Handling

Provide clear messages for:

- Invalid password
- Unsupported disk-image operation
- Insufficient disk space
- Existing destination file
- Permission denied
- Vault already mounted
- Vault already locked
- Volume busy or in use
- Interrupted creation
- Unexpected system utility failure

Do not expose passwords or sensitive document names unnecessarily.

## 11. Development Workflow

Build the application incrementally.

Phase 1:
- Inspect the current project and available macOS development tools.
- Confirm the installed Swift version.
- Choose a build approach suitable for macOS.
- Create the minimal working application.

Phase 2:
- Implement folder selection.
- Implement encrypted vault creation.
- Verify vault creation and mounting manually.

Phase 3:
- Implement password-protected unlocking.
- Open the mounted volume in Finder.
- Implement locking and unmounting.

Phase 4:
- Improve error handling.
- Test incorrect passwords and interrupted operations.
- Test folders containing spaces and large files.
- Test existing vaults and mounted volumes.

Phase 5:
- Add Finder Quick Action integration.
- Document installation and usage.

Phase 6:
- Package the application as a macOS .app.
- Document signing requirements and distribution options.

## 12. Instructions for the Coding Assistant

Act as a senior macOS software engineer.

Before writing code:

1. Inspect the existing project files.
2. Check the available development tools.
3. Explain the selected build approach briefly.
4. Identify any macOS limitations that affect the requested behavior.

Then implement the application in small, testable steps.

For each step:
- Explain which files will be created or modified.
- Provide complete, working code.
- Include exact terminal commands where needed.
- Run appropriate build or test commands when available.
- Diagnose errors using their actual output.
- Do not claim a build or test succeeded unless it was verified.
- Avoid rewriting unrelated files.
- Do not skip ahead when a prerequisite fails.

Use Swift best practices, meaningful names, appropriate error handling,
and clear documentation.

Prioritize a working, secure vault over cosmetic features.

## 13. Definition of Done

The first usable version is complete when:

- A user can select a folder.
- The app creates an encrypted vault from its contents.
- The vault can be mounted using the correct password.
- An incorrect password does not unlock the vault.
- The mounted files are accessible in Finder.
- The vault can be unmounted successfully.
- Original files are not deleted automatically.
- Passwords are not logged or stored in plaintext.
- Common errors are handled gracefully.

Finder Quick Action integration and standalone packaging can follow once
the core workflow has been tested successfully.