import 'semantic_version.dart';

final class UpdateException implements Exception {
  final String message;
  final bool isConnectivityFailure;

  const UpdateException(this.message, {this.isConnectivityFailure = false});

  @override
  String toString() => message;
}

final class GitHubReleaseAsset {
  final String name;
  final Uri downloadUrl;
  final int size;

  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });
}

final class GitHubRelease {
  final String tagName;
  final SemanticVersion version;
  final int? buildNumber;
  final String notes;
  final GitHubReleaseAsset apk;
  final GitHubReleaseAsset checksum;

  const GitHubRelease({
    required this.tagName,
    required this.version,
    required this.buildNumber,
    required this.notes,
    required this.apk,
    required this.checksum,
  });

  static GitHubRelease fromJson(
    Map<String, dynamic> json, {
    required String owner,
    required String repository,
  }) {
    if (json['draft'] == true || json['prerelease'] == true) {
      throw const UpdateException('სტაბილური განახლება ვერ მოიძებნა.');
    }

    final tagName = json['tag_name'];
    if (tagName is! String) {
      throw const UpdateException('GitHub-ის რელიზს ვერსიის tag არ აქვს.');
    }
    final version = SemanticVersion.tryParse(tagName);
    if (version == null || !version.isStable) {
      throw const UpdateException('GitHub-ის რელიზის ვერსია არასწორია.');
    }

    final rawAssets = json['assets'];
    if (rawAssets is! List) {
      throw const UpdateException('რელიზის ფაილების სია არასწორია.');
    }
    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map((asset) => _parseAsset(asset, owner, repository))
        .toList();

    final apks = assets
        .where((asset) => asset.name.toLowerCase().endsWith('.apk'))
        .toList();
    if (apks.length != 1) {
      throw const UpdateException(
        'რელიზში ერთი APK ფაილი უნდა იყოს. დეველოპერს დაუკავშირდი.',
      );
    }
    final apk = apks.single;
    final checksumAssets = assets.where((asset) {
      final name = asset.name.toLowerCase();
      return name == '${apk.name.toLowerCase()}.sha256' || name == 'sha256sums';
    }).toList();
    if (checksumAssets.length != 1) {
      throw const UpdateException(
        'რელიზს APK-ის SHA-256 checksum არ ახლავს. განახლება ვერ შესრულდება.',
      );
    }

    final rawNotes = (json['body'] as String?)?.trim() ?? '';
    final buildMarkers = RegExp(
      r'<!-- payday-build: (\d+) -->',
    ).allMatches(rawNotes).toList();
    if (buildMarkers.length > 1) {
      throw const UpdateException(
        'GitHub Release-ის build metadata არასწორია.',
      );
    }
    final buildNumber = buildMarkers.isEmpty
        ? null
        : int.tryParse(buildMarkers.single.group(1)!);
    if (buildMarkers.isNotEmpty && (buildNumber == null || buildNumber < 1)) {
      throw const UpdateException(
        'GitHub Release-ის build metadata არასწორია.',
      );
    }

    return GitHubRelease(
      tagName: tagName,
      version: version,
      buildNumber: buildNumber,
      notes: rawNotes.replaceAll(RegExp(r'\s*<!-- payday-build: \d+ -->'), ''),
      apk: apk,
      checksum: checksumAssets.single,
    );
  }

  static GitHubReleaseAsset _parseAsset(
    Map<String, dynamic> json,
    String owner,
    String repository,
  ) {
    final name = json['name'];
    final rawUrl = json['browser_download_url'];
    final size = json['size'];
    if (name is! String ||
        name.isEmpty ||
        rawUrl is! String ||
        size is! int ||
        size < 0) {
      throw const UpdateException(
        'GitHub-ის რელიზის ფაილის მონაცემები არასწორია.',
      );
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const UpdateException('რელიზის ფაილის მისამართი უსაფრთხო არ არის.');
    }
    final segments = uri.pathSegments;
    if (segments.length != 6 ||
        segments[0] != owner ||
        segments[1] != repository ||
        segments[2] != 'releases' ||
        segments[3] != 'download' ||
        segments[4].isEmpty ||
        segments[5] != name) {
      throw const UpdateException(
        'რელიზის ფაილის მისამართი ამ GitHub repository-ს არ ეკუთვნის.',
      );
    }
    return GitHubReleaseAsset(name: name, downloadUrl: uri, size: size);
  }
}
