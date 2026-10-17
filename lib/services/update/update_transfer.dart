import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'github_release.dart';

abstract interface class UpdateTransfer {
  Future<void> downloadToFile(
    Uri url,
    File destination, {
    required void Function(int received, int total) onProgress,
  });

  Future<String> getText(Uri url);
}

final class DioUpdateTransfer implements UpdateTransfer {
  final Dio _dio;

  DioUpdateTransfer({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<void> downloadToFile(
    Uri url,
    File destination, {
    required void Function(int received, int total) onProgress,
  }) async {
    var current = url;
    IOSink? sink;
    try {
      for (var redirect = 0; redirect <= 5; redirect++) {
        _validateTransferUrl(current);
        final response = await _dio.get<ResponseBody>(
          current.toString(),
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            receiveTimeout: const Duration(minutes: 5),
            validateStatus: (status) => status != null,
          ),
        );
        final status = response.statusCode ?? 0;
        if (status >= 300 && status < 400) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null || redirect == 5) {
            throw const UpdateException(
              'APK ჩამოტვირთვის გადამისამართება არასწორია.',
            );
          }
          await response.data?.stream.listen((_) {}).cancel();
          current = current.resolve(location);
          continue;
        }
        if (status != HttpStatus.ok || response.data == null) {
          throw UpdateException('APK ჩამოტვირთვა ვერ მოხერხდა (HTTP $status).');
        }

        final total =
            int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
            ) ??
            -1;
        var received = 0;
        sink = destination.openWrite();
        await for (final chunk in response.data!.stream) {
          received += chunk.length;
          sink.add(chunk);
          onProgress(received, total);
        }
        await sink.flush();
        await sink.close();
        sink = null;
        if (received == 0) {
          throw const UpdateException('ჩამოტვირთული APK ცარიელია.');
        }
        return;
      }
      throw const UpdateException(
        'APK ჩამოტვირთვის გადამისამართება ვერ დასრულდა.',
      );
    } on FileSystemException {
      throw const UpdateException(
        'ფაილის შენახვა ვერ მოხერხდა. შეამოწმე მოწყობილობის თავისუფალი მეხსიერება.',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode case final int status) {
        throw UpdateException('APK ჩამოტვირთვა ვერ მოხერხდა (HTTP $status).');
      }
      throw const UpdateException(
        'APK ჩამოტვირთვა შეწყდა. შეამოწმე ინტერნეტი და სცადე თავიდან.',
      );
    } finally {
      await sink?.close();
    }
  }

  @override
  Future<String> getText(Uri url) async {
    var current = url;
    for (var redirect = 0; redirect <= 5; redirect++) {
      _validateTransferUrl(current);
      final response = await _dio.get<List<int>>(
        current.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || redirect == 5) {
          throw const UpdateException('Checksum-ის მისამართი არასწორია.');
        }
        current = current.resolve(location);
        continue;
      }
      if (status != HttpStatus.ok || response.data == null) {
        throw UpdateException(
          'Checksum ჩამოტვირთვა ვერ მოხერხდა (HTTP $status).',
        );
      }
      return utf8.decode(response.data!, allowMalformed: false);
    }
    throw const UpdateException('Checksum ჩამოტვირთვა ვერ დასრულდა.');
  }

  void _validateTransferUrl(Uri uri) {
    final allowed =
        uri.host == 'github.com' ||
        uri.host == 'objects.githubusercontent.com' ||
        uri.host == 'release-assets.githubusercontent.com' ||
        uri.host == 'github-releases.githubusercontent.com';
    if (uri.scheme != 'https' ||
        !allowed ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      throw const UpdateException(
        'ჩამოტვირთვის მისამართი უსაფრთხო არ არის. ინსტალაცია შეჩერდა.',
      );
    }
  }
}
