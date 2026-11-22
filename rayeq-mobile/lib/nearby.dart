import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'demo_data.dart';
import 'localization.dart';
import 'royal_theme.dart';

String nearbyText(String ar, String en) =>
    appLocale.value.languageCode == 'en' ? en : ar;

typedef LocationReader = Future<Map<String, double>> Function();

Future<Map<String, double>> readApproximateLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ApiFailure(
      'LOCATION_DISABLED',
      'شغّل خدمة الموقع أو اختار المنطقة يدويًا.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const ApiFailure(
      'LOCATION_DENIED',
      'الموقع مش متاح. تقدر تختار المنطقة يدويًا.',
    );
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 18),
    ),
  );
  final age = DateTime.now().difference(position.timestamp);
  if (age >= const Duration(minutes: 15) ||
      age < const Duration(minutes: -1) ||
      !position.latitude.isFinite ||
      !position.longitude.isFinite ||
      position.accuracy > 10000) {
    throw const ApiFailure(
      'LOCATION_STALE',
      'تعذر تحديد موقع حديث. جرّب تاني أو اختار المنطقة.',
    );
  }
  // Only an approximate zone leaves the phone, never the precise device fix.
  return {
    'latitude': (position.latitude * 100).round() / 100,
    'longitude': (position.longitude * 100).round() / 100,
  };
}

class NearbySelection {
  final Map<String, dynamic> barber;
  final Map<String, double>? location;
  final String? areaId;
  final String? checkedAt;
  const NearbySelection({
    required this.barber,
    this.location,
    this.areaId,
    this.checkedAt,
  });
  String get id => '${barber['id']}';
  String get name => appLocale.value.languageCode == 'en'
      ? '${barber['nameEn'] ?? nearbyText('حلاق', 'Barber')}'
      : '${barber['nameAr'] ?? nearbyText('حلاق', 'Barber')}';
}

class NearbyBarbersPage extends StatefulWidget {
  final RayeqApi api;
  final Map<String, dynamic> service, catalog;
  final String? areaId, requestedAt;
  final LocationReader? locationReader;
  const NearbyBarbersPage({
    super.key,
    required this.api,
    required this.service,
    required this.catalog,
    this.areaId,
    this.requestedAt,
    this.locationReader,
  });
  @override
  State<NearbyBarbersPage> createState() => _NearbyBarbersPageState();
}

class _NearbyBarbersPageState extends State<NearbyBarbersPage> {
  String? areaId;
  Map<String, double>? location;
  Map<String, dynamic>? result;
  bool busy = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    areaId = widget.areaId;
  }

  Future<void> search({required bool useLocation}) async {
    if (busy) return;
    if (!useLocation && areaId == null) {
      setState(
        () => error = nearbyText('اختار منطقة الأول.', 'Choose an area first.'),
      );
      return;
    }
    setState(() {
      busy = true;
      error = '';
      result = null;
    });
    try {
      final coordinates = useLocation
          ? await (widget.locationReader ?? readApproximateLocation)()
          : null;
      final response = await widget.api.post('barbers/nearby', {
        'serviceId': widget.service['id'],
        if (coordinates != null) ...coordinates,
        if (areaId != null) 'areaId': areaId,
        if (widget.requestedAt != null) 'requestedAt': widget.requestedAt,
      });
      if (!mounted) return;
      setState(() {
        result = response;
        location = coordinates;
      });
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = tr(e.message));
    } catch (_) {
      if (mounted)
        setState(
          () => error = nearbyText(
            'تعذر البحث دلوقتي. جرّب تاني أو اختار المنطقة يدويًا.',
            'Search is unavailable. Try again or choose an area manually.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = (widget.catalog['areas'] as List? ?? [])
        .where((a) => catalogEnglishReady(a as Map))
        .toList();
    final rawBarbers = result?['barbers'] as List? ?? [];
    final barbers = rawBarbers
        .where(
          (b) =>
              b['availabilityStatus'] == 'available' &&
              (appLocale.value.languageCode != 'en' ||
                  ('${b['nameEn'] ?? ''}'.trim().isNotEmpty &&
                      !RegExp(r'[\u0600-\u06ff]').hasMatch('${b['nameEn']}'))),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(nearbyText('حلاقين قريبين منك', 'Barbers near you')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                displayServiceName(widget.service),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                nearbyText(
                  'بنستخدم موقعك التقريبي مرة واحدة لما تضغط الزر. مفيش تتبع مباشر، وتقدر تختار المنطقة يدويًا.',
                  'Use your approximate location once when you tap below. No live tracking. You can choose an area instead.',
                ),
                style: const TextStyle(color: royalMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy ? null : () => search(useLocation: true),
                icon: const Icon(Icons.my_location_rounded),
                label: Text(nearbyText('استخدم موقعي', 'Use my location')),
              ),
              if (rawBarbers.length != barbers.length &&
                  appLocale.value.languageCode == 'en')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Some barber profiles are not ready in English. Switch to Arabic to see them.',
                    style: TextStyle(color: royalMuted, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: areas.any((a) => a['id'] == areaId)
                    ? areaId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: nearbyText(
                    'أو اختار المنطقة',
                    'Or choose an area',
                  ),
                ),
                items: [
                  for (final area in areas)
                    DropdownMenuItem(
                      value: '${area['id']}',
                      child: Text(displayAreaName(area)),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        areaId = v;
                        result = null;
                        location = null;
                      }),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => search(useLocation: false),
                icon: const Icon(Icons.search_rounded),
                label: Text(nearbyText('دوّر في المنطقة', 'Search this area')),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: LinearProgressIndicator(),
                ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    error,
                    style: const TextStyle(color: Color(0xffffbe9d)),
                  ),
                ),
              if (result != null) ...[
                const SizedBox(height: 16),
                Text(
                  nearbyText('المتاح دلوقتي', 'Available now'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  nearbyText(
                    'اختيارك بيتراجع وقت الإرسال. لو الحلاق لسه متاح، حجزك بيتأكد معاه مباشرة.',
                    'Your choice is checked again at submission. If the barber is still available, your booking is confirmed directly with them.',
                  ),
                  style: const TextStyle(color: royalMuted, fontSize: 12),
                ),
                if (result?['demoOnly'] == true ||
                    result?['availabilityIsPreview'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      nearbyText(
                        'معاينة للتوفر، مش تأكيد لزيارة فعلية.',
                        'Availability preview, not a confirmed visit.',
                      ),
                      style: const TextStyle(color: royalGold, fontSize: 12),
                    ),
                  ),
                if (barbers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      nearbyText(
                        'مفيش حلاقين متاحين للاختيار دلوقتي. جرّب منطقة تانية أو ابعت طلب من غير اختيار حلاق.',
                        'No barbers are available to choose right now. Try another area or request a visit without choosing a barber.',
                      ),
                    ),
                  ),
                for (final raw in barbers)
                  _barberCard(Map<String, dynamic>.from(raw)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _barberCard(Map<String, dynamic> barber) {
    final distance = barber['approximateDistance'];
    final name = appLocale.value.languageCode == 'en'
        ? '${barber['nameEn']}'
        : '${barber['nameAr'] ?? ''}';
    final band =
        distance is Map && distance['minKm'] is num && distance['maxKm'] is num
        ? '${(distance['minKm'] as num).toStringAsFixed(0)} - ${(distance['maxKm'] as num).toStringAsFixed(0)} ${nearbyText('كم تقريبًا', 'km approx.')}'
        : nearbyText(
            'في المنطقة المختارة، بدون مسافة دقيقة',
            'In the selected area, no distance estimate',
          );
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: royalSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: royalLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut_rounded, color: royalGold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(band, style: const TextStyle(color: royalMuted, fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                NearbySelection(
                  barber: barber,
                  location: location,
                  areaId: areaId,
                  checkedAt: result?['checkedAt'] as String?,
                ),
              ),
              child: Text(nearbyText('اختار الحلاق', 'Choose barber')),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerAvailabilityController extends ChangeNotifier
    with WidgetsBindingObserver {
  final RayeqApi api;
  final LocationReader locationReader;
  WorkerAvailabilityController(this.api, {LocationReader? locationReader})
    : locationReader = locationReader ?? readApproximateLocation {
    WidgetsBinding.instance.addObserver(this);
  }
  String? _workerId;
  Map<String, dynamic>? data;
  String error = '';
  bool busy = false, optedIn = false, _foreground = true, _disposed = false;
  String _status = 'offline';
  Timer? _timer;
  DateTime? _lastHeartbeat;
  void bindUser(Map<String, dynamic>? user) {
    final id = user?['role'] == 'worker' ? '${user!['id']}' : null;
    if (id == _workerId) return;
    _timer?.cancel();
    optedIn = false;
    data = null;
    error = '';
    _workerId = id;
    busy = false;
    if (id != null) unawaited(load());
  }

  bool get active => _workerId != null && !_disposed;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (!active || busy) return;
    busy = true;
    changed();
    final owner = _workerId;
    try {
      final value = await api.getMap('worker/availability');
      if (owner != _workerId || _disposed) return;
      data = value;
      _status = '${value['availabilityStatus'] ?? 'offline'}';
      error = '';
    } on ApiFailure catch (e) {
      if (owner == _workerId) {
        error = tr(e.message);
        if (e.status == 401 || e.status == 403) {
          optedIn = false;
          _timer?.cancel();
        }
      }
    } catch (_) {
      if (owner == _workerId)
        error = nearbyText(
          'تعذر تحديث التوفر.',
          'Could not refresh availability.',
        );
    } finally {
      if (owner == _workerId) {
        busy = false;
        changed();
      }
    }
  }

  Future<void> update(
    String status, {
    bool shareLocation = false,
    bool clearLocation = false,
    bool heartbeat = false,
  }) async {
    if (!active || busy || (heartbeat && (!optedIn || !_foreground))) return;
    final owner = _workerId;
    busy = true;
    error = '';
    changed();
    try {
      final coordinates = shareLocation ? await locationReader() : null;
      if (owner != _workerId || _disposed) return;
      final value = await api.patch('worker/availability', {
        'availabilityStatus': status,
        if (shareLocation) 'location': coordinates,
        if (clearLocation) 'location': null,
      });
      if (owner != _workerId || _disposed) return;
      data = value;
      _status = status;
      optedIn = status != 'offline';
      _lastHeartbeat = DateTime.now();
      _arrangeHeartbeat();
    } on ApiFailure catch (e) {
      if (owner == _workerId) {
        error = tr(e.message);
        if (e.status == 401 || e.status == 403) {
          optedIn = false;
          _timer?.cancel();
        }
      }
    } catch (_) {
      if (owner == _workerId)
        error = nearbyText(
          'تعذر تحديث التوفر. جرّب تاني.',
          'Could not update availability. Try again.',
        );
    } finally {
      if (owner == _workerId) {
        busy = false;
        changed();
      }
    }
  }

  void _arrangeHeartbeat() {
    _timer?.cancel();
    if (!active || !optedIn || !_foreground) return;
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (active && optedIn && _foreground)
        unawaited(update(_status, heartbeat: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _timer?.cancel();
      return;
    }
    if (optedIn &&
        _lastHeartbeat != null &&
        DateTime.now().difference(_lastHeartbeat!) <
            const Duration(minutes: 15)) {
      unawaited(update(_status, heartbeat: true));
      _arrangeHeartbeat();
    } else {
      optedIn = false;
      _timer?.cancel();
      unawaited(load());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class WorkerAvailabilityPanel extends StatelessWidget {
  final WorkerAvailabilityController controller;
  const WorkerAvailabilityPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status =
          '${controller.data?['effectiveAvailabilityStatus'] ?? 'offline'}';
      String label(String value) => switch (value) {
        'available' => nearbyText('متاح', 'Available'),
        'busy' => nearbyText('مشغول', 'Busy'),
        _ => nearbyText('غير متاح', 'Offline'),
      };
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: royalSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: royalLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nearbyText('توفرك للزيارات', 'Your availability'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: nearbyText('تحديث', 'Refresh'),
                  onPressed: controller.busy ? null : controller.load,
                  icon: const Icon(Icons.refresh_rounded, color: royalGold),
                ),
              ],
            ),
            Text(label(status), style: const TextStyle(color: royalGold)),
            const SizedBox(height: 8),
            Text(
              nearbyText(
                'اختار حالتك بنفسك. بعد التفعيل، بنجددها كل ٥ دقايق والتطبيق قدامك فقط. الحالة بتحتاج تجديد بعد ١٥ دقيقة من غير تحديث.',
                'Choose your status. After you opt in, it refreshes every 5 minutes only while the app is open. It needs renewal after 15 minutes without an update.',
              ),
              style: const TextStyle(color: royalMuted, fontSize: 12),
            ),
            if (controller.busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (controller.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  controller.error,
                  style: const TextStyle(color: Color(0xffffbe9d)),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in ['available', 'busy', 'offline'])
                  ChoiceChip(
                    label: Text(
                      label(value),
                      style: TextStyle(
                        color: status == value ? royalBackground : royalText,
                      ),
                    ),
                    selected: status == value,
                    onSelected: controller.busy
                        ? null
                        : (_) => controller.update(value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.busy
                  ? null
                  : () => controller.update(
                      '${controller.data?['availabilityStatus'] ?? 'offline'}',
                      shareLocation: true,
                    ),
              icon: const Icon(Icons.my_location_rounded),
              label: Text(
                nearbyText(
                  'شارك منطقتي التقريبية مرة واحدة',
                  'Share my approximate area once',
                ),
              ),
            ),
            Text(
              nearbyText(
                'بنحفظ منطقة تقريبية فقط، مش موقعك الدقيق. مفيش تتبع في الخلفية.',
                'Only a coarse area is stored, not your precise location. No background tracking.',
              ),
              style: const TextStyle(color: royalMuted, fontSize: 12),
            ),
            if (controller.data?['hasCoarseZone'] == true)
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () => controller.update(
                        '${controller.data?['availabilityStatus'] ?? 'offline'}',
                        clearLocation: true,
                      ),
                child: Text(
                  nearbyText('امسح المنطقة المحفوظة', 'Clear saved area'),
                ),
              ),
          ],
        ),
      );
    },
  );
}
