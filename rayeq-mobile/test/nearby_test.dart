import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/demo_data.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/nearby.dart';
import 'package:rayeq/royal_theme.dart';

const service = {
  'id': 's1',
  'nameAr': 'حلاقة وتصفيف',
  'nameEn': 'Haircut & styling',
  'englishReady': true,
};
const area = {
  'id': 'a1',
  'nameAr': 'وسط البلد',
  'nameEn': 'Central Cairo',
  'englishReady': true,
};
const barber = {
  'id': 'b1',
  'nameAr': 'أحمد حسن',
  'nameEn': 'Ahmed Hassan',
  'availabilityStatus': 'available',
  'approximateDistance': {'minKm': 2, 'maxKm': 4},
};
const available = {
  'availabilityStatus': 'available',
  'effectiveAvailabilityStatus': 'available',
  'isFresh': true,
  'hasCoarseZone': true,
};
http.Response response(Map<String, dynamic> data) => http.Response(
  jsonEncode({'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Widget app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: appLocale.value,
  supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: rayeqTheme(),
  builder: rayeqBackdrop,
  home: home,
);

void main() {
  setUp(() {
    appLocale.value = const Locale('en');
    FlutterSecureStorage.setMockInitialValues({});
  });
  test('staff display alias is English-only and does not rewrite the name', () {
    final value = {
      'name': 'أحمد حسن',
      'displayNameEn': 'Ahmed Hassan',
      'role': 'worker',
    };
    expect(displayProfileName(value), 'Ahmed Hassan');
    expect(value['name'], 'أحمد حسن');
    appLocale.value = const Locale('ar', 'EG');
    expect(displayProfileName(value), 'أحمد حسن');
  });
  testWidgets(
    'nearby waits for a tap, submits a lookup and returns only the chosen barber',
    (t) async {
      var locationReads = 0;
      final calls = <Map<String, dynamic>>[];
      NearbySelection? selection;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/barbers/nearby');
          calls.add(jsonDecode(r.body));
          return response({
            'barbers': [barber],
            'checkedAt': '2026-11-22T16:30:00Z',
            'selectionIsReservation': false,
          });
        }),
      );
      await t.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selection = await Navigator.push<NearbySelection>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NearbyBarbersPage(
                        api: api,
                        service: service,
                        catalog: const {
                          'areas': [area],
                        },
                        locationReader: () async {
                          locationReads++;
                          return {'latitude': 30.05, 'longitude': 31.24};
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(locationReads, 0);
      expect(calls, isEmpty);
      await t.tap(find.text('Use my location'));
      await t.pumpAndSettle();
      expect(locationReads, 1);
      expect(calls.single['latitude'], 30.05);
      expect(calls.single.containsKey('preferredBarberId'), false);
      expect(find.text('Ahmed Hassan'), findsOneWidget);
      expect(find.text('2 - 4 km approx.'), findsOneWidget);
      await t.ensureVisible(find.text('Choose barber'));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose barber'));
      await t.pumpAndSettle();
      expect(selection?.id, 'b1');
      expect(selection?.location?['longitude'], 31.24);
      expect(calls.length, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'manual area search sends no coordinates and requires no location permission',
    (t) async {
      var reads = 0;
      Map<String, dynamic>? body;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          body = jsonDecode(r.body);
          return response({
            'barbers': [
              {...barber, 'approximateDistance': null},
            ],
            'mode': 'area',
          });
        }),
      );
      await t.pumpWidget(
        app(
          NearbyBarbersPage(
            api: api,
            service: service,
            catalog: const {
              'areas': [area],
            },
            areaId: 'a1',
            locationReader: () async {
              reads++;
              return {};
            },
          ),
        ),
      );
      await t.tap(find.text('Search this area'));
      await t.pumpAndSettle();
      expect(reads, 0);
      expect(body?['areaId'], 'a1');
      expect(body?.containsKey('latitude'), false);
      expect(
        find.text('In the selected area, no distance estimate'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'denied location keeps the manual route available and sends nothing',
    (t) async {
      var calls = 0;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          calls++;
          return response({});
        }),
      );
      await t.pumpWidget(
        app(
          NearbyBarbersPage(
            api: api,
            service: service,
            catalog: const {
              'areas': [area],
            },
            locationReader: () async {
              throw const ApiFailure(
                'LOCATION_DENIED',
                'الموقع مش متاح. تقدر تختار المنطقة يدويًا.',
              );
            },
          ),
        ),
      );
      await t.tap(find.text('Use my location'));
      await t.pumpAndSettle();
      expect(calls, 0);
      expect(
        find.text('Location is unavailable. You can choose an area manually.'),
        findsOneWidget,
      );
      expect(find.text('Search this area'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'worker availability never opts in or reads GPS by itself; heartbeat pauses',
    (t) async {
      final methods = <String>[];
      var reads = 0;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          methods.add(r.method);
          return response(available);
        }),
      );
      final c = WorkerAvailabilityController(
        api,
        locationReader: () async {
          reads++;
          return {'latitude': 30.05, 'longitude': 31.24};
        },
      );
      c.bindUser({'id': 'w1', 'role': 'worker'});
      await t.pumpAndSettle();
      expect(methods, ['GET']);
      expect(c.optedIn, false);
      expect(reads, 0);
      await c.update('available');
      expect(c.optedIn, true);
      expect(reads, 0);
      await t.pump(const Duration(minutes: 5));
      await t.pumpAndSettle();
      expect(methods.where((m) => m == 'PATCH').length, 2);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      await t.pump(const Duration(minutes: 10));
      await t.pumpAndSettle();
      expect(methods.where((m) => m == 'PATCH').length, 2);
      expect(reads, 0);
      c.bindUser(null);
      await t.pump(const Duration(minutes: 6));
      expect(methods.where((m) => m == 'PATCH').length, 2);
      c.dispose();
    },
  );
  testWidgets(
    'worker zone sharing and clearing are explicit separate actions',
    (t) async {
      final bodies = <Map<String, dynamic>>[];
      var reads = 0;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          if (r.method == 'PATCH') bodies.add(jsonDecode(r.body));
          return response(available);
        }),
      );
      final c = WorkerAvailabilityController(
        api,
        locationReader: () async {
          reads++;
          return {'latitude': 30.05, 'longitude': 31.24};
        },
      );
      c.bindUser({'id': 'w1', 'role': 'worker'});
      await t.pumpAndSettle();
      await c.update('available');
      expect(bodies.last.containsKey('location'), false);
      await c.update('available', shareLocation: true);
      expect(reads, 1);
      expect(bodies.last['location'], {'latitude': 30.05, 'longitude': 31.24});
      await c.update('offline', clearLocation: true);
      expect(bodies.last['location'], null);
      expect(bodies.last.containsKey('location'), true);
      expect(c.optedIn, false);
      c.dispose();
    },
  );
  testWidgets('phone-sized nearby and worker layouts in Arabic and English', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await (FontLoader('PlexArabic')
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    Future<void> capture(GlobalKey key, String name) async {
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory(
          Platform.environment['RAYEQ_VISUAL_OUTPUT'] ??
              '${Directory.systemTemp.path}/rayeq-visual-review',
        );
        await output.create(recursive: true);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final language in ['ar', 'en']) {
      appLocale.value = language == 'ar'
          ? const Locale('ar', 'EG')
          : const Locale('en');
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient(
          (r) async => r.url.path.endsWith('/barbers/nearby')
              ? response({
                  'barbers': [barber],
                  'selectionIsReservation': false,
                })
              : response(available),
        ),
      );
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: app(
            NearbyBarbersPage(
              api: api,
              service: service,
              catalog: const {
                'areas': [area],
              },
              areaId: 'a1',
              locationReader: () async => {
                'latitude': 30.05,
                'longitude': 31.24,
              },
            ),
          ),
        ),
      );
      await t.tap(
        find.text(language == 'ar' ? 'استخدم موقعي' : 'Use my location'),
      );
      await t.pumpAndSettle();
      await capture(key, 'nearby-top-$language');
      await t.ensureVisible(
        find.text(language == 'ar' ? 'اختار الحلاق' : 'Choose barber'),
      );
      await t.pumpAndSettle();
      await capture(key, 'nearby-card-$language');
      final c = WorkerAvailabilityController(api);
      c.bindUser({'id': 'w1', 'role': 'worker'});
      await t.pumpAndSettle();
      final workerKey = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: workerKey,
          child: app(
            Scaffold(
              appBar: AppBar(
                title: Text(language == 'ar' ? 'جدولي' : 'Schedule'),
              ),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: [WorkerAvailabilityPanel(controller: c)],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await capture(workerKey, 'worker-availability-$language');
      await t.pumpWidget(const SizedBox());
      c.dispose();
    }
  });
}
