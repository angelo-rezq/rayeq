import 'package:rayeq/demo_data.dart' show previewFixturesEnabled;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/review_fixtures.dart';
import 'package:rayeq/royal_theme.dart';

import 'forms_review_test.dart' show capture;

class DemoSnapshotApi extends ReviewApi {
  final Map<String, dynamic> snapshot;
  DemoSnapshotApi(this.snapshot);
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    if (snapshot.containsKey(path)) return snapshot[path];
    return super.request(
      method,
      path,
      body: body,
      query: query,
      idempotencyKey: idempotencyKey,
    );
  }
}

class PhotoClient implements HttpClient {
  final Map<String, List<int>> images;
  PhotoClient(this.images);
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      PhotoRequest(images[url.toString()]);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class PhotoHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class PhotoRequest implements HttpClientRequest {
  final List<int>? bytes;
  PhotoRequest(this.bytes);
  @override
  final HttpHeaders headers = PhotoHeaders();
  @override
  Future<HttpClientResponse> close() async => PhotoResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  final List<int>? bytes;
  PhotoResponse(this.bytes);
  @override
  int get statusCode => bytes == null ? 404 : 200;
  @override
  int get contentLength => bytes?.length ?? 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes ?? []).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  if (!previewFixturesEnabled) {
    test(
      'live demo screenshot replay requires preview build flag',
      () {},
      skip: 'Run with --dart-define=PREVIEW_FIXTURES=true',
    );
    return;
  }
  testWidgets(
    'live demo snapshots show full-width AR EN home and public profile with published images',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetDevicePixelRatio();
        t.view.resetPhysicalSize();
        debugNetworkImageHttpClientProvider = null;
        imageCache.clear();
      });
      final raw = jsonDecode(
        File('test/fixtures/public-profile-demo.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final paths = jsonDecode(
        File('test/fixtures/public-profile-media.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final images = paths.map(
        (k, v) => MapEntry(k, File(v as String).readAsBytesSync()),
      );
      debugNetworkImageHttpClientProvider = () => PhotoClient(images);
      for (final font in {
        'PlexArabic': ['PlexArabic-400.ttf', 'PlexArabic-600.ttf'],
        'BrandArabic': ['BrandArabic.ttf'],
        'BrandLatin': ['BrandLatin.ttf'],
        'MaterialIcons': ['material'],
      }.entries) {
        final loader = FontLoader(font.key);
        for (final file in font.value) {
          loader.addFont(
            rootBundle.load(
              file == 'material'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$file',
            ),
          );
        }
        await loader.load();
      }
      for (final lang in ['ar', 'en']) {
        appLocale.value = lang == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        for (final width in [320, 390, 430]) {
          t.view.physicalSize = Size(width.toDouble(), 844);
          for (final page in ['home', 'profile']) {
            final boundary = GlobalKey();
            SharedPreferences.setMockInitialValues({});
            final api = DemoSnapshotApi(raw);
            final Widget home = LiveShell(api: api);
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: appLocale.value,
                  supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  theme: rayeqTheme(),
                  builder: rayeqBackdrop,
                  home: home,
                ),
              ),
            );
            await t.pump(const Duration(milliseconds: 120));
            await t.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 80));
            });
            await t.pumpAndSettle();
            if (page == 'profile') {
              await t.tap(
                find.text(lang == 'ar' ? 'أحمد حسن' : 'Ahmed Hassan').first,
              );
              await t.pump(const Duration(milliseconds: 400));
              await t.runAsync(() async {
                await Future<void>.delayed(const Duration(milliseconds: 100));
              });
              await t.pump(const Duration(milliseconds: 400));
              await t.runAsync(() async {
                await Future<void>.delayed(const Duration(milliseconds: 150));
              });
              await t.pumpAndSettle();
            }
            expect(t.takeException(), isNull, reason: '$page $lang $width');
            if (page == 'home') {
              final carousel = find.byWidgetPredicate(
                (w) => w is ListView && w.scrollDirection == Axis.horizontal,
              );
              expect(
                t.getSize(carousel.first).width,
                width.toDouble(),
                reason: 'carousel must reach physical viewport edges',
              );
              final chips = find.byWidgetPredicate(
                (w) =>
                    w is SingleChildScrollView &&
                    w.scrollDirection == Axis.horizontal,
              );
              expect(t.getSize(chips.first).width, width.toDouble());
            }
            if (width == 390) {
              await capture(t, boundary, 'build3-$page-$lang');
              await t.drag(
                find.byType(Scrollable).first,
                const Offset(0, -560),
              );
              await t.runAsync(() async {
                await Future<void>.delayed(const Duration(milliseconds: 100));
              });
              await t.pumpAndSettle();
              await capture(t, boundary, 'build3-$page-lower-$lang');
            }
            await t.pumpWidget(const SizedBox.shrink());
            await t.pumpAndSettle();
          }
        }
      }
    },
  );
}
