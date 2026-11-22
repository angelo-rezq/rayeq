import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/app_updates.dart';

void main() {
  Map<String, dynamic> metadata() => {
    'latestBuild': 3,
    'minSupportedBuild': 2,
    'latestVersion': '1.2.0',
    'apkUrl': 'https://rayeq-platform.onrender.com/download/build3.apk',
    'sha256': 'a' * 64,
    'releaseNotesAr': 'تحسينات',
  };
  test('version policy uses numeric builds and valid signed-host metadata', () {
    final u = UpdateInfo.parse(metadata());
    expect(u.latestBuild, 3);
    expect(u.minSupportedBuild, 2);
    expect(u.downloadable, true);
  });
  test('minimum cannot exceed advertised build', () {
    final m = metadata()..['minSupportedBuild'] = 4;
    expect(() => UpdateInfo.parse(m), throwsFormatException);
  });
  test('versions cannot be string values', () {
    final m = metadata()..['latestBuild'] = '3';
    expect(() => UpdateInfo.parse(m), throwsFormatException);
  });
  test('other download origins and HTTP are rejected', () {
    for (final url in [
      'http://rayeq-platform.onrender.com/a.apk',
      'https://example.com/a.apk',
      'https://evil.invalid@rayeq-platform.onrender.com/a.apk',
    ]) {
      final m = metadata()..['apkUrl'] = url;
      expect(UpdateInfo.parse(m).downloadable, false);
    }
  });
  test('missing or malformed checksum cannot be downloaded', () {
    for (final hash in ['', '123', 'z' * 64]) {
      final m = metadata()..['sha256'] = hash;
      expect(UpdateInfo.parse(m).downloadable, false);
    }
  });
  test('only explicitly configured additional release host is allowed', () {
    const host = String.fromEnvironment('UPDATE_DOWNLOAD_HOST');
    for (final url in [
      'https://rayeq-releases.onrender.com/a.apk',
      'https://rayeq-releases.onrender.com.evil.invalid/a.apk',
      'https://rayeq-releases.onrender.com:444/a.apk',
    ]) {
      final m = metadata()..['apkUrl'] = url;
      expect(
        UpdateInfo.parse(m).downloadable,
        host == 'rayeq-releases.onrender.com' &&
            url == 'https://rayeq-releases.onrender.com/a.apk',
      );
    }
  });
}
