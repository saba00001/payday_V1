# Android releases, updates, and local backups

PayDay checks `saba00001/payday_V1` for a stable GitHub Release when an Android
release build starts. This check runs in the background: if GitHub is offline,
the normal app remains available and all stored data continues to work locally.
When a newer release exists, PayDay offers an update without blocking app use.
APK downloads still require a valid SHA-256 checksum before Android's installer
is opened.

## Existing Android identity

The Android application ID is currently `com.example.payday` in
`android/app/build.gradle.kts`. Keep that exact ID for every update. The
existing release build was configured with the debug signing key; that is not
compatible with production distribution. The first published release must be
signed using one stable production keystore, and every subsequent release must
use that same keystore and key alias. Android will reject updates signed with a
different key. Do not change or lose the keystore.

## One-time GitHub setup

1. Create a private backup of the production Android upload/release keystore.
   Do not commit it to the repository.
2. Base64-encode the keystore file and add these Actions repository secrets:
   - `PAYDAY_KEYSTORE_BASE64`
   - `PAYDAY_KEYSTORE_PASSWORD`
   - `PAYDAY_KEY_ALIAS`
   - `PAYDAY_KEY_PASSWORD`
3. Enable GitHub Actions for the repository. The release workflow needs
   `contents: write` permission to create a GitHub Release. If organization
   policy restricts workflow permissions, allow this workflow to write
   repository contents.
4. Verify the repository's application signing identity before sending an APK
   to users. The configured GitHub repository name is supplied to the app at
   build time by Actions (`github.repository`); it is not stored as a guessed
   owner/repository in the source.

For example, encode a keystore locally with `base64 -w 0 release-key.jks` on
Linux/macOS, or `[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-key.jks"))`
in PowerShell. Paste the result only into GitHub's secret field.

## Versioning

`pubspec.yaml` uses Flutter's `major.minor.patch+buildNumber` format:

For example, the current project version can be found directly in `pubspec.yaml`.
Do not reset the version or build number.

For every release:

1. Update the semantic version and increase the Android build number, for
   example `version: 1.0.1+2`.
2. Commit and push the change to the release branch.
3. Create and push the matching stable version tag, for example:

   ```sh
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. GitHub Actions validates that the tag version matches `pubspec.yaml`, builds
   a signed universal APK, calculates its SHA-256 checksum, and attaches both
   files to a stable GitHub Release with generated notes.
5. Verify the Release is public and has exactly one `.apk` plus its matching
   `.apk.sha256` checksum file.

The first release for users on an older app must use a greater semantic version
than the version they have installed. The build number must always increase,
even for releases where only metadata has changed.

## Local commands

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
```

The repository workflow is the supported signed release command. A local
release build must provide the same four `PAYDAY_*` signing environment
variables and the actual public repository identifier:

```sh
flutter build apk --release \
  --dart-define=UPDATE_REPOSITORY=OWNER/REPOSITORY
```

Replace `OWNER/REPOSITORY` with the actual public repository. Never build a
user-facing release with a debug key or a different application ID.

## Installer and security behavior

Android requires the user to allow package installs from PayDay. The app opens
the system permission page and starts Android's normal package installer only
after the user grants permission. It does not silently install APKs. On
reopening or returning from the installer, the app reads the installed version
from Android again; if installation was cancelled or failed, the update offer
remains available.

APK and checksum assets must be hosted by the same GitHub repository's
`releases/download/<tag>/` URL, over HTTPS. Redirects are restricted to
GitHub's release asset hosts. The checksum asset must be named
`<apk-name>.sha256` (containing the digest and optionally the matching APK
filename) or `SHA256SUMS` (containing a matching entry). An absent, malformed,
or mismatching checksum fails closed.

If GitHub is unreachable or the release response cannot be validated, the app
continues normally and checks again the next time it starts or resumes. No
update is claimed to have succeeded until Android reports the installed
version after the system installer returns.

## Local data and backup recovery

PayDay continues to keep objects, workdays, salary periods, advances, payments,
reminder settings, and work schedule in Android app-private
`SharedPreferences`. Normal app updates preserve this private data as long as
the application ID and signing key remain the same. A corrupt stored record is
reported instead of being silently treated as an empty collection.

In **Settings → Data**, use **Create backup** to save a versioned JSON backup
through Android's system file picker. Choose a location outside PayDay's
private app folder (for example, Documents, Downloads, or a user-selected
cloud drive) if the file must survive uninstalling the app. To restore after
reinstalling, install PayDay, open Settings → Data → **Restore from backup**,
select the `.paydaybackup` file, and confirm replacement. The file format,
records, unique IDs, and SHA-256 integrity digest are checked before any
current preferences are changed. The app also stores a limited set of
pre-restore/pre-clear snapshots in its private files directory. A private
snapshot is removed when the app is uninstalled and is not a substitute for an
external backup.

Android normally removes app-private data when the app is uninstalled. Keep an
external backup if you need to restore data after uninstalling or changing
devices. A restore replaces the app's current data; PayDay creates an internal
snapshot first and rolls back if writing or verification fails.

## Reminders

Reminders use Android's local AlarmManager and work without internet access.
Changing the reminder time cancels and replaces the same alarm, and the
receiver restores it after reboot, time changes, timezone changes, and an app
update. Android 12+ exact-alarm access and Android 13+ notification permission
can be managed in Settings. Android may still restrict exact timing or
notifications when a permission is denied or battery policies intervene.
