import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/app_updates.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

Map<String, dynamic> release({String? clock}) => {
  'latestBuild': 3,
  'minSupportedBuild': 2,
  'latestVersion': '1.2.0',
  'apkUrl': 'https://rayeq-platform.onrender.com/download/build3.apk',
  'sha256': 'a' * 64,
  'publishedAt': '2026-11-22T10:49:01Z',
  'mandatoryAfter': '2026-11-24T10:49:01Z',
  if (clock != null) 'serverTime': clock,
};

class PolicyApi extends RayeqApi {
  final Map<String, dynamic> response;
  final int? failFromCall;
  int calls = 0;
  PolicyApi(this.response, {this.failFromCall})
    : super(baseUrl: 'https://example.invalid/api/v1');
  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? query,
  }) async {
    calls++;
    if (failFromCall != null && calls >= failFromCall!)
      throw StateError('Offline test');
    return response;
  }
}

class SlowPolicyApi extends RayeqApi {
  final pending = Completer<Map<String, dynamic>>();
  SlowPolicyApi() : super(baseUrl: 'https://example.invalid/api/v1');
  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? query,
  }) => pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    appLocale.value = const Locale('en');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppUpdateGateState.system, (call) async {
          if (call.method == 'installedBuild') return 2;
          throw PlatformException(code: 'TEST_NO_INSTALLER');
        });
  });
  tearDown(() {
    appLocale.value = const Locale('ar', 'EG');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppUpdateGateState.system, null);
  });

  test('grace is measured from publication, not first seen', () {
    final info = UpdateInfo.parse(release());
    expect(
      info.isRequiredFor(2, now: DateTime.parse('2026-11-24T10:49:00Z')),
      false,
    );
    expect(
      info.isRequiredFor(2, now: DateTime.parse('2026-11-24T10:49:01Z')),
      true,
    );
    expect(
      info.isRequiredFor(2, now: DateTime.parse('2026-11-24T10:49:02Z')),
      true,
    );
  });
  test('minimum build cannot shorten the two-day grace', () {
    final info = UpdateInfo.parse(release()..['minSupportedBuild'] = 3);
    expect(
      info.isRequiredFor(2, now: DateTime.parse('2026-11-23T10:49:01Z')),
      false,
    );
  });
  test('publication alone gives a 48-hour deadline', () {
    final info = UpdateInfo.parse(release()..remove('mandatoryAfter'));
    expect(info.enforcementAt, DateTime.parse('2026-11-24T10:49:01Z'));
  });
  test(
    'explicit deadline works for a legacy release without publish field',
    () {
      final info = UpdateInfo.parse(release()..remove('publishedAt'));
      expect(
        info.isRequiredFor(2, now: DateTime.parse('2026-11-24T10:49:01Z')),
        true,
      );
    },
  );
  test('server clock wins over an incorrect device clock', () {
    final info = UpdateInfo.parse(release(clock: '2026-11-23T10:49:01Z'));
    expect(info.isRequiredFor(2, now: DateTime.utc(2030)), false);
    expect(
      info.remainingGrace(now: DateTime.utc(2030)),
      const Duration(hours: 24),
    );
  });
  test('installed latest or newer is never gated', () {
    final info = UpdateInfo.parse(release(clock: '2026-11-26T10:49:01Z'));
    expect(info.isRequiredFor(3), false);
    expect(info.isRequiredFor(4), false);
  });
  test('missing release timing never invents a mandatory deadline', () {
    final info = UpdateInfo.parse(
      release()
        ..remove('publishedAt')
        ..remove('mandatoryAfter'),
    );
    expect(info.isRequiredFor(2, now: DateTime.utc(2030)), false);
    expect(info.remainingGrace(), isNull);
  });
  test('invalid or missing package metadata never forces an update', () {
    for (final url in ['', 'https://example.invalid/a.apk']) {
      final info = UpdateInfo.parse(
        release(clock: '2026-11-26T10:49:01Z')..['apkUrl'] = url,
      );
      expect(info.isRequiredFor(2), false);
    }
  });
  test('inconsistent or malformed timing is rejected', () {
    for (final value in [
      '2026-11-24T10:49:01',
      '2026-11-32T10:49:01Z',
      '2026-02-30T10:49:01Z',
      '2026-11-24T25:49:01Z',
      'invalid',
    ]) {
      final data = release()..['mandatoryAfter'] = value;
      expect(() => UpdateInfo.parse(data), throwsFormatException);
    }
    expect(
      () => UpdateInfo.parse(
        release()..['mandatoryAfter'] = '2026-11-23T10:49:01Z',
      ),
      throwsFormatException,
    );
  });

  Future<void> pumpGate(WidgetTester tester, PolicyApi api) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: rayeqTheme(),
        home: AppUpdateGate(
          api: api,
          child: const Scaffold(body: Text('APP_READY')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void policyWidgetTest(String description, WidgetTesterCallback callback) {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );
  }

  policyWidgetTest('failed live check opens app instead of locking it', (
    tester,
  ) async {
    await pumpGate(tester, PolicyApi(release(), failFromCall: 1));
    expect(find.text('APP_READY'), findsOneWidget);
    expect(find.byType(UpdateDialog), findsNothing);
  });
  policyWidgetTest('incomplete release opens app even if minimum is raised', (
    tester,
  ) async {
    await pumpGate(
      tester,
      PolicyApi(
        release(clock: '2026-11-26T10:49:01Z')
          ..['minSupportedBuild'] = 3
          ..['apkUrl'] = '',
      ),
    );
    expect(find.text('APP_READY'), findsOneWidget);
  });
  policyWidgetTest('optional update can be deferred inside first two days', (
    tester,
  ) async {
    await pumpGate(tester, PolicyApi(release(clock: '2026-11-23T10:49:01Z')));
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('APP_READY'), findsNothing);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('APP_READY'), findsOneWidget);
  });
  policyWidgetTest('expired grace blocks back and has no Not now', (
    tester,
  ) async {
    await pumpGate(tester, PolicyApi(release(clock: '2026-11-24T10:49:01Z')));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    expect(find.text('APP_READY'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('APP_READY'), findsNothing);
  });
  policyWidgetTest('an open optional dialog becomes required at its deadline', (
    tester,
  ) async {
    await pumpGate(tester, PolicyApi(release(clock: '2026-11-24T10:48:31Z')));
    expect(find.text('Not now'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
  });
  policyWidgetTest('a deferred update is checked again when grace expires', (
    tester,
  ) async {
    final api = PolicyApi(release(clock: '2026-11-24T10:48:31Z'));
    await pumpGate(tester, api);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    api.response['serverTime'] = '2026-11-24T10:49:02Z';
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('Update required'), findsOneWidget);
  });
  policyWidgetTest('failed recheck from a required update releases the app', (
    tester,
  ) async {
    await pumpGate(
      tester,
      PolicyApi(release(clock: '2026-11-24T10:49:02Z'), failFromCall: 2),
    );
    await tester.tap(find.text('Download now'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDialog), findsNothing);
    expect(find.text('APP_READY'), findsOneWidget);
  });
  policyWidgetTest(
    'cold start opens after soft wait while version check continues',
    (tester) async {
      final api = SlowPolicyApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: rayeqTheme(),
          home: AppUpdateGate(
            api: api,
            child: const Scaffold(body: Text('APP_READY')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('APP_READY'), findsNothing);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(find.text('APP_READY'), findsOneWidget);
      expect(api.pending.isCompleted, isFalse);
      api.pending.complete(release()..['latestBuild'] = 2);
      await tester.pumpAndSettle();
      expect(find.text('APP_READY'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  policyWidgetTest('failed automatic checks retry twice and remain fail open', (
    tester,
  ) async {
    final api = PolicyApi(release(), failFromCall: 1);
    await pumpGate(tester, api);
    expect(api.calls, 1);
    expect(find.text('APP_READY'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(api.calls, 3);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(api.calls, 3);
    expect(find.text('APP_READY'), findsOneWidget);
  });
}
