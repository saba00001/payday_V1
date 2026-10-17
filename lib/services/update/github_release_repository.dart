import 'dart:convert';

import 'package:dio/dio.dart';

import 'github_release.dart';

abstract interface class ReleaseRepository {
  Future<GitHubRelease> fetchLatestStableRelease();
}

final class GitHubReleaseRepository implements ReleaseRepository {
  static const _defaultRepository = String.fromEnvironment(
    'UPDATE_REPOSITORY',
    defaultValue: 'saba00001/payday_V1',
  );
  final Dio _dio;
  final String _repository;

  GitHubReleaseRepository({Dio? dio, String? repository})
    : _dio = dio ?? Dio(),
      _repository = repository ?? _defaultRepository;

  @override
  Future<GitHubRelease> fetchLatestStableRelease() async {
    final parts = _repository.split('/');
    if (parts.length != 2 ||
        !_validRepositoryPart.hasMatch(parts[0]) ||
        !_validRepositoryPart.hasMatch(parts[1])) {
      throw const UpdateException(
        'GitHub repository არ არის დაყენებული. განახლებისთვის დაუკავშირდი დეველოპერს.',
      );
    }
    final owner = parts[0];
    final repository = parts[1];
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repository/releases/latest',
    );

    try {
      final response = await _dio
          .get<dynamic>(
            uri.toString(),
            options: Options(
              headers: const {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                'User-Agent': 'PayDay-Android-Updater',
              },
              followRedirects: false,
              validateStatus: (status) => status == 200,
              responseType: ResponseType.plain,
            ),
          )
          .timeout(const Duration(seconds: 20));
      final body = response.data;
      if (body is! String) {
        throw const UpdateException('GitHub-ის პასუხის ფორმატი არასწორია.');
      }
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        throw const UpdateException('GitHub-ის პასუხის ფორმატი არასწორია.');
      }
      return GitHubRelease.fromJson(data, owner: owner, repository: repository);
    } on UpdateException {
      rethrow;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 403 || status == 429) {
        throw const UpdateException(
          'GitHub-ის მოთხოვნების ლიმიტი ამოიწურა. სცადე მოგვიანებით.',
        );
      }
      if (status == 404) {
        throw const UpdateException(
          'GitHub Release ვერ მოიძებნა. სცადე მოგვიანებით ან დაუკავშირდი დეველოპერს.',
        );
      }
      if (status != null) {
        if (status == 200) {
          throw const UpdateException('GitHub-ის პასუხის ფორმატი არასწორია.');
        }
        throw UpdateException(
          'GitHub-თან კავშირი ვერ მოხერხდა (HTTP $status).',
        );
      }
      throw const UpdateException(
        'ინტერნეტთან დაკავშირება ვერ მოხერხდა. შეამოწმე კავშირი და სცადე თავიდან.',
      );
    } on FormatException {
      throw const UpdateException('GitHub-ის პასუხის ფორმატი არასწორია.');
    } on Exception {
      throw const UpdateException(
        'განახლების შემოწმება ვერ მოხერხდა. სცადე თავიდან.',
      );
    }
  }
}

final RegExp _validRepositoryPart = RegExp(r'^[A-Za-z0-9_.-]+$');
