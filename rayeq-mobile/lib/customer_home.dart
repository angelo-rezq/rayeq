import 'dart:typed_data';

import 'brand.dart';
import 'barber_profiles.dart';

import 'package:flutter/material.dart';

import 'api.dart';
import 'demo_data.dart';
import 'localization.dart';
import 'nearby.dart';
import 'royal_theme.dart';

class CustomerHome extends StatefulWidget {
  final RayeqApi api;
  final Map<String, dynamic> user, catalog;
  final Set<String> savedIds;
  final VoidCallback onAccount, onServices;
  final VoidCallback? onLanguage;
  final ValueChanged<Map<String, dynamic>> onDemo;
  final ValueChanged<String> onSave;
  final void Function(Map<String, dynamic>, NearbySelection) onBook;
  final ValueChanged<Map<String, dynamic>> onService;
  final LocationReader? locationReader;
  const CustomerHome({
    super.key,
    required this.api,
    required this.user,
    required this.catalog,
    required this.savedIds,
    required this.onAccount,
    required this.onServices,
    required this.onDemo,
    required this.onSave,
    required this.onBook,
    required this.onService,
    this.locationReader,
    this.onLanguage,
  });
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  Uint8List? avatar;
  int avatarGeneration = 0;
  List<Map<String, dynamic>> liveFeatured = [];
  bool featuredLoading = true, featuredFailed = false;
  @override
  void initState() {
    super.initState();
    loadFeatured();
    loadAvatar();
  }

  @override
  void didUpdateWidget(covariant CustomerHome old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api ||
        old.user['id'] != widget.user['id'] ||
        old.user['avatarUrl'] != widget.user['avatarUrl'] ||
        old.user['hasAvatar'] != widget.user['hasAvatar'])
      loadAvatar();
  }

  Future<void> loadAvatar() async {
    final generation = ++avatarGeneration;
    if (widget.user['hasAvatar'] != true && widget.user['avatarUrl'] == null) {
      if (mounted) setState(() => avatar = null);
      return;
    }
    try {
      final bytes = await widget.api.getAvatar();
      if (mounted && generation == avatarGeneration)
        setState(() => avatar = bytes);
    } catch (_) {
      if (mounted && generation == avatarGeneration)
        setState(() => avatar = null);
    }
  }

  Widget accountAvatar() {
    final name = displayProfileName(widget.user).trim();
    final initial = name.isEmpty ? nearbyText('ر', 'R') : name.characters.first;
    Widget fallback() => Center(
      child: Text(
        initial,
        style: const TextStyle(color: royalGold, fontSize: 20),
      ),
    );
    return CircleAvatar(
      radius: 20,
      backgroundColor: royalRaised,
      child: avatar == null
          ? fallback()
          : ClipOval(
              child: Image.memory(
                avatar!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => fallback(),
              ),
            ),
    );
  }

  Future<void> loadFeatured() async {
    if (mounted)
      setState(() {
        featuredLoading = true;
        featuredFailed = false;
      });
    try {
      final result = await widget.api.getMap(
        'barbers/featured',
        query: {'limit': '10'},
      );
      if (mounted)
        setState(
          () => liveFeatured = (result['items'] as List? ?? [])
              .map((b) => Map<String, dynamic>.from(b))
              .where((b) => b['demoOnly'] != true || previewDataEnabled)
              .toList(),
        );
    } catch (_) {
      if (mounted) setState(() => featuredFailed = true);
    } finally {
      if (mounted) setState(() => featuredLoading = false);
    }
  }

  Widget liveFeaturedCard(Map<String, dynamic> barber) => SizedBox(
    width: 190,
    child: Material(
      color: royalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: royalGold.withValues(alpha: .35), width: .7),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveBarberProfile(
              api: widget.api,
              barber: barber,
              initialFavorite: widget.savedIds.contains('${barber['id']}'),
              onFavorite: () => widget.onSave('${barber['id']}'),
              onService: (service) {
                Navigator.pop(context);
                final current = services
                    .where((s) => s['id'] == service['id'])
                    .firstOrNull;
                if (current != null)
                  widget.onBook(current, NearbySelection(barber: barber));
                else
                  widget.onServices();
              },
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: BarberCoverImage(api: widget.api, barber: barber),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (barber['demoOnly'] == true)
                    Text(
                      nearbyText('نموذج', 'Preview'),
                      style: const TextStyle(color: royalGold, fontSize: 12),
                    ),
                  Text(
                    appLocale.value.languageCode == 'en'
                        ? '${barber['nameEn'] ?? ''}'
                        : '${barber['nameAr'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RatingSummary(rating: ratingFromMap(barber), compact: true),
                  const SizedBox(height: 8),
                  Text(
                    nearbyText('عرض الملف والأعمال', 'View profile and work'),
                    style: const TextStyle(fontSize: 12, color: royalMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  String category = 'all', query = '', error = '';
  String? serviceId, areaId;
  bool busy = false, searched = false;
  List<Map<String, dynamic>> barbers = [];
  Map<String, double>? coordinates;
  Map<String, dynamic>? checkedService;
  String? checkedArea, checkedAt;
  bool preview = false;
  List<Map<String, dynamic>> get services =>
      (widget.catalog['services'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s))
          .where(catalogEnglishReady)
          .toList();
  List<Map<String, dynamic>> get areas =>
      (widget.catalog['areas'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s))
          .where(catalogEnglishReady)
          .toList();
  String kind(Map s) {
    final name = '${s['category']} ${s['nameAr']} ${s['nameEn']}'.toLowerCase();
    if (RegExp('vip|ritual|كامل|مميز').hasMatch(name)) return 'vip';
    if (RegExp('beard|ذقن|لحي').hasMatch(name)) return 'beard';
    return 'hair';
  }

  String get categoryLabel => switch (category) {
    'hair' => nearbyText('حلاقة', 'Haircut'),
    'beard' => nearbyText('الذقن', 'Beard'),
    'vip' => 'VIP',
    _ => nearbyText('الكل', 'All'),
  };
  List<Map<String, dynamic>> get categoryServices =>
      services.where((s) => category == 'all' || kind(s) == category).toList();
  Future<void> search(bool useLocation) async {
    if (busy) return;
    final available = services.where((s) => s['id'] == serviceId).toList();
    if (available.isEmpty || (!useLocation && areaId == null)) return;
    setState(() {
      busy = true;
      error = '';
      barbers = [];
      searched = false;
    });
    try {
      final loc = useLocation
          ? await (widget.locationReader ?? readApproximateLocation)()
          : null;
      final response = await widget.api.post('barbers/nearby', {
        'serviceId': serviceId,
        if (loc != null) ...loc,
        if (areaId != null) 'areaId': areaId,
      });
      if (!mounted) return;
      setState(() {
        barbers = (response['barbers'] as List? ?? [])
            .map((b) => Map<String, dynamic>.from(b))
            .where((b) => b['availabilityStatus'] == 'available')
            .toList();
        coordinates = loc;
        checkedService = available.first;
        checkedArea = areaId;
        checkedAt = response['checkedAt'];
        searched = true;
        preview =
            response['demoOnly'] == true ||
            response['availabilityIsPreview'] == true;
      });
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = tr(e.message));
    } catch (_) {
      if (mounted)
        setState(
          () => error = nearbyText(
            'تعذر البحث. جرّب المنطقة يدويًا.',
            'Search is unavailable. Try the area option.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void searchOptions() {
    final options = categoryServices;
    if (options.isEmpty) {
      setState(
        () => error = nearbyText(
          'مفيش خدمات متاحة في القسم ده دلوقتي.',
          'No services are available in this category yet.',
        ),
      );
      return;
    }
    if (!options.any((s) => s['id'] == serviceId))
      serviceId = '${options.first['id']}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: royalSurface,
      builder: (context) => StatefulBuilder(
        builder: (context, sheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nearbyText('دوّر على حلاقك', 'Find your barber'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: serviceId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: nearbyText('الخدمة', 'Service'),
                    ),
                    items: options
                        .map(
                          (s) => DropdownMenuItem(
                            value: '${s['id']}',
                            child: Text(
                              displayServiceName(s),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => sheetState(() => serviceId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: areaId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: nearbyText(
                        'المنطقة للبحث اليدوي',
                        'Area for manual search',
                      ),
                    ),
                    items: areas
                        .map(
                          (a) => DropdownMenuItem(
                            value: '${a['id']}',
                            child: Text(
                              displayAreaName(a),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => sheetState(() => areaId = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        search(true);
                      },
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(
                        nearbyText(
                          'استخدم موقعي مرة واحدة',
                          'Use my location once',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: areaId == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              search(false);
                            },
                      icon: const Icon(Icons.search_rounded),
                      label: Text(
                        nearbyText('ابحث في المنطقة', 'Search this area'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nearbyText(
                      'الموقع اختياري. بنستخدم منطقة تقريبية، من غير تتبع. التوفر بيتراجع تاني وقت الحجز.',
                      'Location is optional. Only an approximate area is used, with no tracking. Availability is checked again when booking.',
                    ),
                    style: const TextStyle(color: royalMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void allFeatured(List<Map<String, dynamic>> featured) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: royalSurface,
        builder: (_) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  nearbyText('حلاقين مميزين', 'Featured barbers'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                for (final b in featured)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: liveFeatured.isNotEmpty
                        ? SizedBox(height: 248, child: liveFeaturedCard(b))
                        : DemoBarberCard(
                            showPreviewLabel: true,
                            barber: b,
                            saved: widget.savedIds.contains(b['id']),
                            onOpen: () {
                              Navigator.pop(context);
                              widget.onDemo(b);
                            },
                            onSave: () => widget.onSave('${b['id']}'),
                          ),
                  ),
              ],
            ),
          ),
        ),
      );
  Widget heading(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final featured =
        (liveFeatured.isNotEmpty
                ? liveFeatured
                : previewFixturesEnabled && widget.catalog['isDemo'] == true
                ? demoBarbers
                : <Map<String, dynamic>>[])
            .where(
              (b) =>
                  (liveFeatured.isNotEmpty ||
                      category == 'all' ||
                      category == 'hair' && b['id'] == 'demo-alex' ||
                      category == 'beard' && b['id'] == 'demo-daniel') &&
                  '${fixtureText(b['name'] ?? b['nameAr'])} ${b['nameEn'] ?? ''} ${fixtureText(b['specialty'] ?? '')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList();
    final visible = barbers
        .where(
          (b) =>
              (appLocale.value.languageCode != 'en' ||
                  '${b['nameEn'] ?? ''}'.trim().isNotEmpty &&
                      !RegExp(r'[\u0600-\u06ff]').hasMatch('${b['nameEn']}')) &&
              '${b['nameAr']} ${b['nameEn']}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final matchingServices = query.isEmpty
        ? <Map<String, dynamic>>[]
        : services
              .where(
                (s) =>
                    displayServiceName(s)
                        .toLowerCase()
                        .contains(query.toLowerCase()),
              )
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: royalGold.withValues(alpha: .27),
                      width: .7,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        royalGold.withValues(alpha: .07),
                        royalSurface.withValues(alpha: .3),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nearbyText('وقت لنفسك', 'Time for yourself'),
                              style: const TextStyle(
                                color: royalMuted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${nearbyText('أهلًا،', 'Hi,')} ${displayProfileName(widget.user).trim().split(RegExp(r'\s+')).first}',
                              style: const TextStyle(
                                fontSize: 25,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const BrandTagline(compact: true),
                          ],
                        ),
                      ),
                      if (widget.onLanguage != null)
                        IconButton(
                          tooltip: tr('تغيير اللغة'),
                          onPressed: widget.onLanguage,
                          icon: const Icon(
                            Icons.language_rounded,
                            color: royalGold,
                            size: 22,
                          ),
                        ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: nearbyText('حسابي', 'My account'),
                        onPressed: widget.onAccount,
                        style: IconButton.styleFrom(
                          backgroundColor: royalSurface,
                          foregroundColor: royalGold,
                          side: const BorderSide(color: royalGold, width: .7),
                        ),
                        icon: accountAvatar(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  onChanged: (v) => setState(() => query = v.trim()),
                  decoration: InputDecoration(
                    hintText: nearbyText(
                      'ابحث عن حلاق أو خدمة',
                      'Search barbers or services',
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: IconButton(
                      tooltip: nearbyText(
                        'اختيارات البحث القريب',
                        'Nearby search options',
                      ),
                      onPressed: busy ? null : searchOptions,
                      icon: const Icon(Icons.tune_rounded, color: royalGold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _HomeFullBleed(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in [
                          [
                            'all',
                            nearbyText('الكل', 'All'),
                            Icons.apps_rounded,
                          ],
                          [
                            'hair',
                            nearbyText('حلاقة', 'Haircut'),
                            Icons.content_cut_rounded,
                          ],
                          [
                            'beard',
                            nearbyText('الذقن', 'Beard'),
                            Icons.face_retouching_natural_rounded,
                          ],
                          ['vip', 'VIP', Icons.diamond_outlined],
                        ])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              avatar: Icon(
                                item[2] as IconData,
                                size: 16,
                                color: category == item[0]
                                    ? royalBackground
                                    : royalMuted,
                              ),
                              label: Text(
                                '${item[1]}',
                                style: TextStyle(
                                  color: category == item[0]
                                      ? royalBackground
                                      : royalText,
                                ),
                              ),
                              selected: category == item[0],
                              showCheckmark: false,
                              onSelected: (_) => setState(() {
                                category = '${item[0]}';
                                searched = false;
                                barbers = [];
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      tr('الخدمات هتظهر هنا بعد تجهيزها من الإدارة.'),
                      style: const TextStyle(color: royalMuted),
                    ),
                  ),
                for (final s in matchingServices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(displayServiceName(s)),
                    trailing: const Icon(
                      Icons.arrow_forward_rounded,
                      color: royalGold,
                    ),
                    onTap: () => widget.onService(s),
                  ),
                heading(
                  nearbyText('حلاقين مميزين', 'Featured barbers'),
                  action: TextButton(
                    onPressed: featuredFailed
                        ? loadFeatured
                        : featured.isEmpty
                        ? null
                        : () => allFeatured(featured),
                    child: Text(
                      featuredFailed
                          ? nearbyText('جرّب تاني', 'Try again')
                          : nearbyText('عرض الكل', 'See all'),
                    ),
                  ),
                ),
                if (featuredLoading && featured.isEmpty)
                  const LinearProgressIndicator(),
                if (featured.isNotEmpty)
                  _HomeFullBleed(
                    child: SizedBox(
                      height: 248,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: featured.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => liveFeatured.isNotEmpty
                            ? liveFeaturedCard(featured[i])
                            : DemoBarberCard(
                                showPreviewLabel: true,
                                barber: featured[i],
                                saved: widget.savedIds.contains(
                                  featured[i]['id'],
                                ),
                                onOpen: () => widget.onDemo(featured[i]),
                                onSave: () =>
                                    widget.onSave('${featured[i]['id']}'),
                              ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: royalSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: royalLine),
                    ),
                    child: Text(
                      featuredFailed
                          ? nearbyText(
                              'تعذر تحميل الحلاقين المميزين.',
                              'Could not load featured barbers.',
                            )
                          : nearbyText(
                              'الحلاقين المميزين هيظهروا هنا لما يكونوا متاحين.',
                              'Featured barbers will appear here when available.',
                            ),
                      style: const TextStyle(color: royalMuted, fontSize: 13),
                    ),
                  ),
                heading(
                  nearbyText('حلاقين قريبين منك', 'Nearby barbers'),
                  action: searched
                      ? Text(
                          '${visible.length} ${nearbyText('متاح', 'found')}',
                          style: const TextStyle(
                            color: royalMuted,
                            fontSize: 12,
                          ),
                        )
                      : IconButton(
                          tooltip: nearbyText('ابحث عن حلاقين', 'Find barbers'),
                          onPressed: busy ? null : searchOptions,
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: royalGold,
                          ),
                        ),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error,
                      style: const TextStyle(color: Color(0xffffb4ab)),
                    ),
                  ),
                if (!searched) ...[
                  Text(
                    nearbyText(
                      'اختار الخدمة والمنطقة، أو استخدم موقعك مرة واحدة.',
                      'Choose a service and area, or use your location once.',
                    ),
                    style: const TextStyle(color: royalMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : searchOptions,
                      icon: const Icon(Icons.near_me_outlined),
                      label: Text(
                        nearbyText('دوّر على حلاقي', 'Find my barber'),
                      ),
                    ),
                  ),
                ],
                if (preview && searched)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      nearbyText(
                        'معاينة للتوفر، مش حجز فعلي.',
                        'Availability preview, not an actual booking.',
                      ),
                      style: const TextStyle(color: royalGold, fontSize: 12),
                    ),
                  ),
                if (searched && visible.isEmpty)
                  Text(
                    nearbyText(
                      'مفيش حلاقين مطابقين متاحين دلوقتي. جرّب منطقة تانية.',
                      'No matching barbers are available now. Try another area.',
                    ),
                    style: const TextStyle(color: royalMuted, fontSize: 13),
                  ),
                for (final b in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: royalSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: royalGold.withValues(alpha: .35),
                          width: .7,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveBarberProfile(
                              api: widget.api,
                              barber: b,
                              initialFavorite: widget.savedIds.contains(
                                '${b['id']}',
                              ),
                              onFavorite: () => widget.onSave('${b['id']}'),
                              onBook: () {
                                Navigator.pop(context);
                                widget.onBook(
                                  checkedService!,
                                  NearbySelection(
                                    barber: b,
                                    location: coordinates,
                                    areaId: checkedArea,
                                    checkedAt: checkedAt,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: royalRaised,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BarberCoverImage(
                                    api: widget.api,
                                    barber: b,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appLocale.value.languageCode == 'en'
                                          ? '${b['nameEn']}'
                                          : '${b['nameAr']}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    RatingSummary(
                                      rating: ratingFromMap(b),
                                      compact: true,
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 5,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: royalGold.withValues(
                                              alpha: .14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                          ),
                                          child: Text(
                                            nearbyText('متاح', 'Available'),
                                            style: const TextStyle(
                                              color: royalGold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (b['approximateDistance'] is Map)
                                          Text(
                                            '${b['approximateDistance']['minKm']} - ${b['approximateDistance']['maxKm']} ${nearbyText('كم تقريبًا', 'km approx.')}',
                                            style: const TextStyle(
                                              color: royalMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 36,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: royalGold.withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  appLocale.value.languageCode == 'ar'
                                      ? Icons.chevron_left_rounded
                                      : Icons.chevron_right_rounded,
                                  color: royalGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: widget.onServices,
                    child: Text(nearbyText('كل الخدمات', 'All services')),
                  ),
                ),
              ]
              .map(
                (child) => child is _HomeFullBleed
                    ? child
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: child,
                      ),
              )
              .toList(),
    );
  }
}

class _HomeFullBleed extends StatelessWidget {
  final Widget child;
  const _HomeFullBleed({required this.child});
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: double.infinity, child: child);
}
