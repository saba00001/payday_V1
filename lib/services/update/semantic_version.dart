final class SemanticVersion implements Comparable<SemanticVersion> {
  static final RegExp _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;
  final String? buildMetadata;

  const SemanticVersion._({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
    required this.buildMetadata,
  });

  static SemanticVersion? tryParse(String value) {
    final normalized = value.trim().startsWith('v')
        ? value.trim().substring(1)
        : value.trim();
    final match = _pattern.firstMatch(normalized);
    if (match == null) return null;

    final prerelease = match.group(4)?.split('.') ?? const <String>[];
    if (prerelease.any(
      (part) =>
          RegExp(r'^\d+$').hasMatch(part) &&
          part.length > 1 &&
          part.startsWith('0'),
    )) {
      return null;
    }

    return SemanticVersion._(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: prerelease,
      buildMetadata: match.group(5),
    );
  }

  bool get isStable => prerelease.isEmpty;

  @override
  int compareTo(SemanticVersion other) {
    final core = major.compareTo(other.major);
    if (core != 0) return core;
    final minorResult = minor.compareTo(other.minor);
    if (minorResult != 0) return minorResult;
    final patchResult = patch.compareTo(other.patch);
    if (patchResult != 0) return patchResult;

    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;

    final sharedLength = prerelease.length < other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var index = 0; index < sharedLength; index++) {
      final left = prerelease[index];
      final right = other.prerelease[index];
      if (left == right) continue;
      final leftNumeric = int.tryParse(left);
      final rightNumeric = int.tryParse(right);
      if (leftNumeric != null && rightNumeric != null) {
        return leftNumeric.compareTo(rightNumeric);
      }
      if (leftNumeric != null) return -1;
      if (rightNumeric != null) return 1;
      return left.compareTo(right);
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  @override
  String toString() =>
      '$major.$minor.$patch'
      '${prerelease.isEmpty ? '' : '-${prerelease.join('.')}'}'
      '${buildMetadata == null ? '' : '+$buildMetadata'}';
}
