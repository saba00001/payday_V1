# Android signed releases and mandatory updates

PayDay checks GitHub's public `releases/latest` endpoint before showing the
normal app interface in Android release builds. Debug, profile, and non-Android
builds do not run the update gate. A failed release lookup keeps the app blocked
and offers retry; a release without a valid APK and matching SHA-256 asset is
not installable.

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

```yaml
version: 1.0.0+1
```

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
from Android again; if installation was cancelled or failed, the mandatory
update screen remains.

APK and checksum assets must be hosted by the same GitHub repository's
`releases/download/<tag>/` URL, over HTTPS. Redirects are restricted to
GitHub's release asset hosts. The checksum asset must be named
`<apk-name>.sha256` (containing the digest and optionally the matching APK
filename) or `SHA256SUMS` (containing a matching entry). An absent, malformed,
or mismatching checksum fails closed.

The release gate depends on GitHub being reachable on each Android release
app launch. Offline launches cannot proceed into the app; the update screen
provides retry, not a bypass.
