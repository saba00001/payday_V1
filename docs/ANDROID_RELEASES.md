# Android releases, updates, and local backups

On Android release builds, PayDay checks `saba00001/payday_V1` for the latest
stable GitHub Release before showing the normal app. If a newer version is
available, access remains blocked until the update is installed. If the check
cannot reach GitHub (for example, when the device is offline), PayDay opens
normally and retries the check when the app returns to the foreground. Workday
tracking, salary calculations, backups, and reminders do not require internet.
The startup screen shows a short animated PayDay mark; debug builds and
non-Android platforms do not perform update checks.

## Existing Android identity

The Android application ID is currently `com.example.payday` in
`android/app/build.gradle.kts`. Keep that exact ID for every update. The
published `v1.0.2` APK is signed with a certificate whose SHA-256 digest is
`f333ea34b4c83c276e36cec926faeaa57567390832552021aa01472722870db9`. The
corresponding private signing key is not present in the repository or this
development environment. Configure the original key in GitHub Actions secrets;
do not generate a replacement key. The release workflow compares the newly
built APK's certificate with the currently published APK before replacing its
assets. Android will reject updates signed with a different key.

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

The current project version is `1.0.3+5` in `pubspec.yaml`. Do not reset the
version or build number. The existing `v1.0.1` and `v1.0.2` Releases and tags
are historical releases and should not be deleted or moved.

For a new public release:

1. Update the semantic version and increase the Android build number. Each APK
   must have a higher Android version code than the currently published APK.
2. Commit and push the changes to `main`.
3. In GitHub Actions, run **Android signed release** from `main`, set the
   release tag to match `pubspec.yaml` (for example `v1.0.3` for
   `1.0.3+5`), and set `source_ref` to `main`.
4. The workflow validates the version, requires all four signing secrets,
   verifies both the keystore and private-key passwords, builds the signed
   universal APK, checks signing-certificate and version-code continuity
   against the existing `v1.0.2` APK, calculates the SHA-256 checksum, and
   creates the GitHub Release.

5. Verify the Release is public and has exactly one `.apk` plus its matching
   `.apk.sha256` checksum file.

Do not delete or replace assets from an existing Release when publishing a new
version. The workflow creates a new Release only after the build and signing
checks succeed. If the workflow reports a signing-key validation error, correct
the corresponding repository Actions secret in GitHub Settings; never send
keystore passwords through chat or commit them to the repository.

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

The checksum detects accidental or transport corruption; it is not a digital
signature. Android's package installer separately verifies that the APK is
signed with a certificate accepted for this installed application. Do not
replace a release asset unless the signing-certificate continuity check passes.

If GitHub is unreachable or the release response cannot be validated, the
normal interface stays blocked and the user can retry the check. No update is
claimed to have succeeded until Android reports the installed version after
the system installer returns.

## Local data and backup recovery

PayDay continues to keep objects, workdays, salary periods, advances, payments,
reminder settings, and work schedule in Android app-private
`SharedPreferences`. Normal app updates preserve this private data as long as
the application ID and signing key remain the same. A corrupt stored record is
reported instead of being silently treated as an empty collection.

Older records may omit fields that the model schema defines as optional; those
records are loaded with the model's backward-compatible defaults. Before a
storage schema version advances, PayDay saves a raw local recovery snapshot.
If local data still cannot be read, Settings offers validated internal
snapshots and external backup selection. Starting with new data is a separate,
explicitly confirmed action and keeps a recovery snapshot first.

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
