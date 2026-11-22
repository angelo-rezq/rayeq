import 'about.dart';

import 'package:flutter/services.dart';

import 'localization.dart';

import 'dart:convert';

import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

import 'api.dart';
import 'royal_theme.dart';
import 'ui_parts.dart';
import 'demo_data.dart';
import 'profile.dart';
import 'service_details.dart';
import 'bottom_bar.dart';

import 'package:shared_preferences/shared_preferences.dart';

class LiveShell extends StatefulWidget {
  final RayeqApi? api;
  const LiveShell({super.key, this.api});
  @override
  State<LiveShell> createState() => _LiveShellState();
}

class _LiveShellState extends State<LiveShell> {
  late final RayeqApi api;
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  Map<String, dynamic>? user, catalog;
  String screen = 'splash', error = '';
  bool busy = false, worker = false, showPassword = false;
  int tab = 0;
  List<dynamic> bookings = [], schedule = [];
  bool past = false, showSchedule = false;
  String? nextCursor;
  String serviceQuery = '', serviceCategory = 'الكل';
  Set<String> savedIds = {};
  @override
  void initState() {
    super.initState();
    api = widget.api ?? RayeqApi();
    tzdata.initializeTimeZones();
    restore();
  }

  @override
  void dispose() {
    api.close();
    for (final c in [name, email, password, code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() fn) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await fn();
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          if (e.status == 401) {
            user = null;
            bookings = [];
            catalog = null;
            screen = 'login';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'حصلت مشكلة، جرّب مرة تانية.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    if (!api.configured) return;
    await run(() async {
      await api.restore();
      if (api.signedIn) {
        user = await api.getMap('me');
        await loadSaved();
        screen = 'home';
        await refresh();
      }
    });
  }

  Future<void> refresh() async {
    if (user == null) return;
    user = await api.getMap('me');
    if (user!['role'] == 'customer') catalog = await api.getMap('catalog');
    previewDataEnabled =
        previewFixturesEnabled &&
        (catalog?['isDemo'] == true || previewAccount(user));
    if (user!['role'] == 'customer' || user!['role'] == 'worker') {
      await loadBookings();
    }
    if (user!['role'] == 'worker' && showSchedule) await loadSchedule();
  }

  Future<void> loadBookings({bool append = false}) async {
    final prefix = user!['role'] == 'worker' ? 'worker/' : '';
    final r = await api.getMap(
      '${prefix}bookings',
      query: {
        'scope': past ? 'past' : 'current',
        'limit': '20',
        if (append && nextCursor != null) 'cursor': nextCursor!,
      },
    );
    final items = r['items'] as List? ?? [];
    bookings = append ? [...bookings, ...items] : items;
    nextCursor = r['nextCursor'] as String?;
  }

  Future<void> loadSchedule() async {
    final now = tz.TZDateTime.now(tz.getLocation('Africa/Cairo'));
    final r = await api.getMap(
      'worker/schedule',
      query: {
        'from': DateFormat('yyyy-MM-dd').format(now),
        'to': DateFormat('yyyy-MM-dd').format(now.add(Duration(days: 30))),
      },
    );
    schedule = r['items'] as List? ?? [];
  }

  Widget historyControls() => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 4),
    child: Wrap(
      spacing: 8,
      children: [
        for (final value in [false, true])
          ChoiceChip(
            label: Text(tr(value ? 'السابقة' : 'الحالية')),
            selected: past == value,
            onSelected: busy
                ? null
                : (_) => run(() async {
                    past = value;
                    await loadBookings();
                  }),
          ),
      ],
    ),
  );
  Widget moreButton() => nextCursor == null
      ? SizedBox.shrink()
      : button('تحميل المزيد', () => run(() => loadBookings(append: true)));

  Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      savedIds = (prefs.getStringList('saved_${user?['id']}') ?? []).toSet();
    } catch (_) {
      savedIds = {};
    }
  }

  Future<void> toggleSaved(String id) async {
    setState(() {
      savedIds.contains(id) ? savedIds.remove(id) : savedIds.add(id);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_${user?['id']}', savedIds.toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('تعذر حفظ المفضلة على الجهاز.'))),
        );
      }
    }
  }

  void demoProfile(Map<String, dynamic> b) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DemoBarberPage(
        barber: b,
        onServices: () {
          setState(() => tab = 1);
        },
      ),
    ),
  );
  Widget savedBody() {
    final services = (catalog?['services'] as List? ?? [])
        .where((s) => savedIds.contains(s['id']))
        .toList();
    final barbers = previewFixturesEnabled && catalog?['isDemo'] == true
        ? demoBarbers.where((b) => savedIds.contains(b['id'])).toList()
        : <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'المحفوظات',
          'محفوظة على الجهاز ده فقط، ومش بتحدد العامل المسند ليك.',
        ),
        if (services.isEmpty && barbers.isEmpty)
          box(Text(tr('احفظ خدماتك وحلاقينك المفضلين بعلامة القلب.'))),
        for (final s in services)
          box(
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(displayServiceName(Map<String, dynamic>.from(s)))),
              subtitle: Text(tr(money(s['priceMinor']))),
              trailing: IconButton(
                onPressed: () => toggleSaved('${s['id']}'),
                icon: Icon(Icons.favorite, color: royalGold),
              ),
              onTap: () => openBooking(Map<String, dynamic>.from(s)),
            ),
          ),
        for (final b in barbers)
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: DemoBarberCard(
              barber: b,
              saved: true,
              onOpen: () => demoProfile(b),
              onSave: () => toggleSaved(b['id']),
            ),
          ),
      ],
    );
  }

  void clearAuthInputs({bool identity = false}) {
    password.clear();
    code.clear();
    if (identity) {
      name.clear();
      email.clear();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext(shouldSave: false);
  }

  Future<void> session(Map<String, dynamic> data) async {
    if (data['next'] == 'login') {
      clearAuthInputs();
      screen = 'login';
      return;
    }
    await api.saveSession(data);
    user = await api.getMap('me');
    await loadSaved();
    clearAuthInputs(identity: true);
    screen = 'home';
    await refresh();
  }

  Future<void> auth() async => run(() async {
    final e = email.text.trim();
    if (!e.contains('@') || password.text.length < 10) {
      throw ApiFailure(
        'VALIDATION',
        'اكتب إيميل صحيح وكلمة مرور ١٠ أحرف على الأقل.',
      );
    }
    if (screen == 'register') {
      if (name.text.trim().isEmpty) {
        throw ApiFailure('VALIDATION', 'اكتب اسمك الأول.');
      }
      await api.post('auth/register', {
        'name': name.text.trim(),
        'email': e,
        'password': password.text,
        'accountType': worker ? 'worker' : 'customer',
      });
      clearAuthInputs();
      screen = 'verify';
    } else {
      try {
        await session(
          await api.post('auth/login', {'email': e, 'password': password.text}),
        );
      } on ApiFailure catch (e) {
        if (e.code == 'EMAIL_NOT_VERIFIED') {
          clearAuthInputs();
          screen = 'verify';
        }
        rethrow;
      }
    }
  });
  Widget button(String text, VoidCallback action) => Padding(
    padding: EdgeInsets.only(top: 16),
    child: SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : action,
        child: Text(tr(text)),
      ),
    ),
  );
  Widget field(
    String label,
    TextEditingController c, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: EdgeInsets.only(top: 18),
    child: TextField(
      controller: c,
      obscureText: secret && !showPassword,
      textDirection: secret || keyboard == TextInputType.emailAddress
          ? TextDirection.ltr
          : null,
      autofillHints: secret
          ? (screen == 'register'
                ? [AutofillHints.newPassword]
                : [AutofillHints.password])
          : keyboard == TextInputType.emailAddress
          ? [AutofillHints.username, AutofillHints.email]
          : label == 'اسمك بالكامل'
          ? [AutofillHints.name]
          : null,
      autocorrect: !secret,
      enableSuggestions: !secret,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: tr(label),
        helperText: secret && screen == 'register'
            ? tr('١٠ أحرف على الأقل')
            : null,
        prefixIcon: Icon(
          secret
              ? Icons.lock_outline_rounded
              : keyboard == TextInputType.emailAddress
              ? Icons.mail_outline_rounded
              : Icons.person_outline_rounded,
          size: 19,
        ),
        suffixIcon: secret
            ? IconButton(
                tooltip: tr(
                  showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                ),
                onPressed: () => setState(() => showPassword = !showPassword),
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                ),
              )
            : null,
      ),
    ),
  );
  Widget box(Widget child) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 18),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Color(0xff211a35),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Color(0xff3b304f)),
    ),
    child: child,
  );
  Widget heading(String title, String desc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(title), style: Theme.of(context).textTheme.headlineLarge),
      SizedBox(height: 8),
      Text(tr(desc), style: TextStyle(color: Color(0xffb4aac8), height: 1.9)),
    ],
  );
  void go(String target) {
    clearAuthInputs();
    setState(() {
      screen = target;
      showPassword = false;
      error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (['splash', 'onboard1', 'onboard2'].contains(screen)) {
      return introScreen();
    }
    final authPage = [
      'login',
      'register',
      'verify',
      'forgot',
      'reset',
    ].contains(screen);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 82,
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: royalGold.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: royalGold.withValues(alpha: .35)),
              ),
              child: Icon(
                Icons.content_cut_rounded,
                color: royalGold,
                size: 20,
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('رايق'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: royalGold,
                    ),
                  ),
                  Text(
                    tr('حلاقك عندك'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: royalMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('تغيير اللغة'),
            onPressed: () => setAppLanguage(
              appLocale.value.languageCode == 'ar' ? 'en' : 'ar',
            ),
            icon: const Icon(
              Icons.language_rounded,
              size: 21,
              color: royalGold,
            ),
          ),
          if (user != null)
            PopupMenuButton<String>(
              tooltip: tr('خيارات الحساب'),
              icon: Icon(Icons.more_horiz_rounded, color: royalMuted),
              onSelected: (v) {
                if (v == 'refresh')
                  run(refresh);
                else if (v == 'profile')
                  setState(() => tab = user?['role'] == 'customer' ? 4 : 2);
                else if (v == 'about')
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AboutRayeq()));
                else if (v == 'privacy')
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicy()),
                  );
                else
                  run(signOut);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Text(tr('الملف الشخصي')),
                ),
                PopupMenuItem(value: 'refresh', child: Text(tr('تحديث'))),
                PopupMenuItem(value: 'about', child: Text(tr('عن رايق'))),
                PopupMenuItem(
                  value: 'privacy',
                  child: Text(tr('سياسة الخصوصية')),
                ),
                PopupMenuItem(value: 'logout', child: Text(tr('تسجيل الخروج'))),
              ],
            ),
          SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 18, 24, 56),
            children: [
              if (busy) LinearProgressIndicator(),
              if (error.isNotEmpty) RoyalNotice(message: error, error: true),
              if (authPage)
                Column(
                  children: [
                    if (screen != 'register') ...[
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: royalGold.withValues(alpha: .10),
                          border: Border.all(
                            color: royalGold.withValues(alpha: .4),
                          ),
                        ),
                        child: const Icon(
                          Icons.content_cut_rounded,
                          color: royalGold,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('حلاقك عندك'),
                        style: const TextStyle(color: royalGold, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: royalSurface.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: royalLine),
                      ),
                      child: AutofillGroup(
                        onDisposeAction: AutofillContextAction.cancel,
                        child: authBody(),
                      ),
                    ),
                  ],
                )
              else if ((user?['role'] == 'customer' && tab == 4) ||
                  (['worker', 'worker_pending'].contains(user?['role']) &&
                      tab == 2))
                profileBody()
              else if (user?['role'] == 'customer' && tab == 3)
                savedBody()
              else if (user?['role'] == 'worker_pending')
                pendingBody()
              else if (user?['role'] == 'worker')
                workerBody()
              else if (user?['role'] == 'admin')
                heading(
                  'حساب إدارة',
                  'لوحة الإدارة متاحة على الويب. استخدم حساب عميل للحجز.',
                )
              else
                customerBody(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: authPage || user == null
          ? null
          : RoyalNavigationBar(
              selectedIndex: tab,
              onDestinationSelected: busy
                  ? null
                  : (i) {
                      setState(() => tab = i);
                      if ([
                            'worker',
                            'worker_pending',
                          ].contains(user?['role']) &&
                          i == 1 &&
                          user?['role'] == 'worker') {
                        run(() async {
                          showSchedule = true;
                          await loadSchedule();
                        });
                      } else if (user?['role'] == 'worker' && i == 0) {
                        setState(() => showSchedule = false);
                      }
                    },
              destinations: user?['role'] == 'customer'
                  ? [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: tr('الرئيسية'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.content_cut),
                        label: tr('الخدمات'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        label: tr('حجوزاتي'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.favorite_border),
                        label: tr('المحفوظات'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        label: tr('حسابي'),
                      ),
                    ]
                  : [
                      NavigationDestination(
                        icon: Icon(Icons.assignment_outlined),
                        label: tr('زياراتي'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.schedule),
                        label: tr('جدولي'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        label: tr('حسابي'),
                      ),
                    ],
            ),
    );
  }

  Widget introScreen() {
    final splash = screen == 'splash', first = screen == 'onboard1';
    return Scaffold(
      body: RoyalBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 580),
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: tr('تغيير اللغة'),
                          onPressed: () => setAppLanguage(
                            appLocale.value.languageCode == 'ar' ? 'en' : 'ar',
                          ),
                          icon: const Icon(
                            Icons.language_rounded,
                            color: royalGold,
                            size: 21,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => go('login'),
                          child: Text(
                            tr(splash ? 'تسجيل الدخول' : 'تخطي'),
                            style: const TextStyle(
                              color: royalMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Center(
                      child: Container(
                        width: splash ? 104 : 166,
                        height: splash ? 104 : 166,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: royalGold.withValues(alpha: .08),
                          border: Border.all(
                            color: royalGold.withValues(alpha: .4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (first ? royalGold : royalPurple)
                                  .withValues(alpha: .15),
                              blurRadius: 70,
                              spreadRadius: 25,
                            ),
                          ],
                        ),
                        child: Icon(
                          splash || first
                              ? Icons.content_cut
                              : Icons.calendar_month_outlined,
                          size: splash ? 46 : 65,
                          color: first || splash ? royalGold : royalPurple,
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    if (splash) ...[
                      Center(
                        child: Text(
                          tr('رايق'),
                          style: TextStyle(
                            fontSize: 58,
                            color: royalGold,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          tr('حلاقك عندك'),
                          style: TextStyle(color: royalMuted, fontSize: 14),
                        ),
                      ),
                    ] else ...[
                      SizedBox(height: 50),
                      Text(
                        tr(first ? '1 / 2' : '2 / 2'),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: royalGold, fontSize: 12),
                      ),
                      SizedBox(height: 14),
                      Text(
                        tr(
                          first
                              ? 'إطلالتك.\nعلى مزاجك.'
                              : 'رتّب زيارتك.\nفي خطوات بسيطة.',
                        ),
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        tr(
                          first
                              ? 'عناية مرتبة وتفاصيل تفرق. اختار خدمتك وسيب المشوار علينا.'
                              : 'اختار خدمة ومكان ومعاد تطلبه. الإدارة تراجع وتأكد الزيارة معاك.',
                        ),
                        style: TextStyle(
                          color: royalMuted,
                          fontSize: 13,
                          height: 1.9,
                        ),
                      ),
                    ],
                    Spacer(),
                    if (!splash)
                      Row(
                        children: [
                          for (final active in [first, !first])
                            Container(
                              width: active ? 23 : 6,
                              height: 5,
                              margin: EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: active ? royalGold : royalLine,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                        ],
                      ),
                    button(
                      splash
                          ? 'خلّينا نبدأ'
                          : first
                          ? 'التالي'
                          : 'ابدأ مع رايق',
                      () => go(
                        splash
                            ? 'onboard1'
                            : first
                            ? 'onboard2'
                            : 'login',
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget accountTypeSelector() {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: royalBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: royalLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AnimatedPositionedDirectional(
              duration: duration,
              curve: Curves.easeOutCubic,
              start: worker ? constraints.maxWidth / 2 : 0,
              top: 0,
              bottom: 0,
              width: constraints.maxWidth / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: royalGold,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: royalGold.withValues(alpha: .14),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final isWorker in [false, true])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: worker == isWorker,
                      label: tr(isWorker ? 'حلاق' : 'عميل'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: busy
                            ? null
                            : () => setState(() => worker = isWorker),
                        child: ExcludeSemantics(
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedSwitcher(
                                  duration: duration,
                                  child: Icon(
                                    isWorker
                                        ? Icons.content_cut_rounded
                                        : Icons.person_outline_rounded,
                                    key: ValueKey(worker == isWorker),
                                    color: worker == isWorker
                                        ? royalBackground
                                        : royalMuted,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedDefaultTextStyle(
                                  duration: duration,
                                  style: TextStyle(
                                    fontFamily: 'PlexArabic',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: worker == isWorker
                                        ? royalBackground
                                        : royalMuted,
                                  ),
                                  child: Text(tr(isWorker ? 'حلاق' : 'عميل')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget authBody() {
    if (screen == 'verify') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            'بص على إيميلك',
            worker
                ? 'بعد تفعيل الإيميل، الإدارة بتراجع طلبك قبل أول زيارة.'
                : 'اكتب الكود اللي وصلك على إيميلك.',
          ),
          box(Text(tr(email.text), textDirection: TextDirection.ltr)),
          field('كود التفعيل', code, keyboard: TextInputType.number),
          button(
            'تأكيد الإيميل',
            () => run(() async {
              await session(
                await api.post('auth/verify-email', {
                  'email': email.text.trim(),
                  'code': code.text.trim(),
                }),
              );
            }),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    await api.post('auth/resend-verification', {
                      'email': email.text.trim(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr('لو الإيميل مسجل ومتاح للإرسال، هتوصلك رسالة.'),
                          ),
                        ),
                      );
                    }
                  }),
            child: Text(tr('إعادة إرسال الكود')),
          ),
          TextButton(
            onPressed: () => go('login'),
            child: Text(tr('رجوع للدخول')),
          ),
        ],
      );
    }
    if (screen == 'forgot' || screen == 'reset') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('استعادة الحساب', 'هنبعت كود على بريدك لو الحساب مسجل.'),
          field(
            'البريد الإلكتروني',
            email,
            keyboard: TextInputType.emailAddress,
          ),
          if (screen == 'reset') ...[
            field('الكود', code, keyboard: TextInputType.number),
            field('كلمة المرور الجديدة', password, secret: true),
          ],
          button(
            screen == 'forgot' ? 'إرسال كود الاستعادة' : 'تغيير كلمة المرور',
            () => run(() async {
              if (screen == 'forgot') {
                await api.post('auth/forgot-password', {
                  'email': email.text.trim(),
                });
                screen = 'reset';
              } else {
                await api.post('auth/reset-password', {
                  'email': email.text.trim(),
                  'code': code.text.trim(),
                  'newPassword': password.text,
                });
                password.clear();
                screen = 'login';
              }
            }),
          ),
          TextButton(
            onPressed: () => go('login'),
            child: Text(tr('رجوع للدخول')),
          ),
        ],
      );
    }
    final register = screen == 'register';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          register
              ? (worker ? 'انضم لفريق رايق' : 'حسابك الجديد')
              : 'نورت رايق',
          register
              ? (worker
                    ? 'خلّي خبرتك توصل لعملاء أكتر.'
                    : 'اختار خدمتك واحجز زيارتك في خطوات بسيطة.')
              : 'ادخل حسابك ورتّب وقت لنفسك.',
        ),
        if (register) ...[
          const SizedBox(height: 22),
          accountTypeSelector(),
          field('اسمك بالكامل', name),
        ],
        field('البريد الإلكتروني', email, keyboard: TextInputType.emailAddress),
        field('كلمة المرور', password, secret: true),
        if (register)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: royalGold,
                  size: 17,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    tr(
                      worker
                          ? 'بعد تفعيل الإيميل، الإدارة بتراجع طلبك قبل أول زيارة.'
                          : 'هنبعت كود تفعيل على إيميلك بعد التسجيل.',
                    ),
                    style: const TextStyle(
                      color: royalMuted,
                      fontSize: 11,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        button(
          register ? (worker ? 'إنشاء حساب حلاق' : 'إنشاء حساب عميل') : 'دخول',
          auth,
        ),
        Center(
          child: TextButton(
            onPressed: busy ? null : () => go(register ? 'login' : 'register'),
            child: Text(
              tr(register ? 'عندك حساب؟ سجّل دخول' : 'أول مرة؟ اعمل حساب'),
            ),
          ),
        ),
        if (register)
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicy())),
              child: Text(
                tr('سياسة الخصوصية'),
                style: const TextStyle(color: royalMuted, fontSize: 11),
              ),
            ),
          ),
        if (!register)
          Center(
            child: TextButton(
              onPressed: busy ? null : () => go('forgot'),
              child: Text(tr('نسيت كلمة المرور؟')),
            ),
          ),
      ],
    );
  }

  Widget pendingBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'طلبك عند الإدارة',
        'إيميلك اتفعّل، وحساب الحلاق في انتظار الموافقة. بيانات الزيارات هتظهر بعد موافقة الإدارة وإسناد مهام ليك.',
      ),
      button('تحديث حالة الحساب', () => run(refresh)),
    ],
  );
  String money(dynamic value) =>
      '${((value as num? ?? 0) / 100).toStringAsFixed(2)} ج.م';
  String cairoTime(dynamic raw) {
    if (raw == null) return 'في أقرب وقت، بعد تأكيد الإدارة';
    try {
      return '${DateFormat('yyyy/MM/dd • HH:mm', appLocale.value.languageCode).format(tz.TZDateTime.from(DateTime.parse('$raw'), tz.getLocation('Africa/Cairo')))} بتوقيت القاهرة';
    } catch (_) {
      return 'راجع الإدارة لتأكيد الموعد';
    }
  }

  String status(dynamic s) =>
      {
        'PENDING': 'قيد المراجعة',
        'UNDER_REVIEW': 'تحت المراجعة',
        'CONFIRMED': 'تم التأكيد',
        'ON_THE_WAY': 'في الطريق',
        'ARRIVED': 'وصل الحلاق',
        'IN_PROGRESS': 'الخدمة بدأت',
        'COMPLETED': 'مكتملة',
        'CANCELLED': 'ملغاة',
      }[s] ??
      '${s ?? ''}';
  Future<void> signOut() async {
    try {
      await api.logout();
    } finally {
      if (mounted) {
        setState(() {
          user = null;
          catalog = null;
          bookings = [];
          tab = 0;
          screen = 'login';
        });
      }
    }
  }

  Widget profileBody() => ProfilePanel(
    api: api,
    initialUser: user!,
    onPassword: () {
      email.text = '${user?['email'] ?? ''}';
      go('forgot');
    },
    onLogout: () => run(signOut),
    onChanged: (v) {
      user = {...user!, ...v};
    },
  );
  Widget customerBody() {
    if (tab == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('حجوزاتي', 'طلباتك وحالة كل زيارة.'),
          historyControls(),
          if (bookings.isEmpty)
            box(
              Text(
                tr(
                  past
                      ? 'مفيش زيارات سابقة.'
                      : 'مفيش حجوزات حالية. اختار خدمة واطلب زيارة.',
                ),
              ),
            ),
          for (final b in bookings) bookingCard(Map<String, dynamic>.from(b)),
          moreButton(),
        ],
      );
    }
    final all = (catalog?['services'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final categories = [
      'الكل',
      ...all
          .map((s) => '${s['category'] ?? ''}')
          .where((c) => c.isNotEmpty)
          .toSet(),
    ];
    final list = all
        .where(
          (s) =>
              (serviceCategory == 'الكل' || s['category'] == serviceCategory) &&
              '${s['nameAr']} ${s['nameEn']} ${s['descriptionAr']} ${s['descriptionEn']} ${displayServiceName(s)}'
                  .toLowerCase()
                  .contains(serviceQuery.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tab == 0) ...[
          heading(
            'أهلًا ${displayProfileName(user!)}',
            'عنايتك بنفسك، في المكان اللي يريحك.',
          ),
          SizedBox(height: 20),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.asset(
                  'assets/images/grooming.webp',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: LinearGradient(
                      colors: [Color(0xe6191919), Color(0x33191919)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('من غير مشوار'),
                        style: TextStyle(
                          color: Color(0xffe7c35b),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        tr('حلاقك عندك.\nعلى راحتك.'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      TextButton(
                        onPressed: () => setState(() => tab = 1),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(tr('شوف الخدمات ←')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('وقت لنفسك'),
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                child: Text(tr('كل الخدمات')),
              ),
            ],
          ),
        ] else ...[
          heading('الخدمات', 'اختار العناية اللي تناسبك.'),
          SizedBox(height: 18),
          TextField(
            onChanged: (v) => setState(() => serviceQuery = v.trim()),
            decoration: InputDecoration(
              hintText: tr('دوّر على خدمة'),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (c) => ChoiceChip(
                    label: Text(displayCategory({'category': c})),
                    selected: serviceCategory == c,
                    onSelected: (_) => setState(() => serviceCategory = c),
                  ),
                )
                .toList(),
          ),
        ],
        if (previewFixturesEnabled &&
            tab == 0 &&
            catalog?['isDemo'] == true) ...[
          SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('حلاقين مميزين'),
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              DemoBadge(),
            ],
          ),
          SizedBox(height: 7),
          Text(
            tr('عناية بالتفاصيل، من أول الزيارة لآخر لمسة.'),
            style: TextStyle(color: royalMuted, fontSize: 10),
          ),
          SizedBox(height: 14),
          SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: demoBarbers.length,
              separatorBuilder: (_, _) => SizedBox(width: 13),
              itemBuilder: (_, i) => DemoBarberCard(
                barber: demoBarbers[i],
                saved: savedIds.contains(demoBarbers[i]['id']),
                onOpen: () => demoProfile(demoBarbers[i]),
                onSave: () => toggleSaved(demoBarbers[i]['id']),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            tr('اختر خدمة'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ],

        if (catalog?['intakeEnabled'] != true)
          box(Text(tr('استقبال الطلبات مش متاح حاليًا.'))),
        if (all.isEmpty)
          box(Text(tr('الخدمات هتظهر هنا بعد تجهيزها من الإدارة.'))),
        if (all.isNotEmpty && list.isEmpty)
          box(Text(tr('مفيش خدمات مطابقة للبحث ده.'))),
        for (final item in (tab == 0 ? list.take(3) : list))
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceArt(
                  name: displayServiceName(item),
                  imageUrl: item['imageUrl'] as String?,
                ),
                SizedBox(height: 16),
                Text(
                  tr(displayServiceName(item)),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(displayServiceDescription(item)),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr(money(item['priceMinor'])),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tr('${item['durationMinutes']} دقيقة'),
                      style: TextStyle(color: Color(0xffb4aac8), fontSize: 12),
                    ),
                  ],
                ),
                button('اختار الخدمة', () => openService(item)),
              ],
            ),
          ),
        if (all.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 15),
            child: Text(
              tr(''),
              style: TextStyle(fontSize: 10, color: Color(0xffb4aac8)),
            ),
          ),
      ],
    );
  }

  void openService(Map<String, dynamic> service) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ServiceDetails(
        service: service,
        demo: catalog?['isDemo'] == true,
        onBook: () {
          Navigator.pop(context);
          openBooking(service);
        },
      ),
    ),
  );
  Future<void> openBooking(Map<String, dynamic> service) async {
    if (catalog?['intakeEnabled'] != true) {
      setState(() => error = 'استقبال الطلبات غير متاح حاليًا.');
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingForm(
          api: api,
          service: service,
          catalog: catalog!,
          customerName: displayProfileName(user!),
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => tab = 2);
      await run(refresh);
    }
  }

  Widget bookingCard(Map<String, dynamic> raw, {bool employee = false}) {
    final b = bookingForDisplay(raw, preview: previewAccount(user));
    final address = b['address'] as Map? ?? {};
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: royalMuted, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayServiceName(Map<String, dynamic>.from(b['service'] ?? {})),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: royalGold.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  tr(status(b['status'])),
                  style: const TextStyle(fontSize: 11, color: royalGold),
                ),
              ),
              const Spacer(),
              Text(
                '${b['reference'] ?? ''}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: royalMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          line(Icons.calendar_month_outlined, tr(cairoTime(b['requestedAt']))),
          line(
            Icons.location_on_outlined,
            displayAreaName(b['area'] as Map? ?? {}),
          ),
          if (employee) ...[
            line(Icons.person_outline_rounded, displayCustomerName(b)),
            line(
              Icons.home_outlined,
              '${displayAddress(address, 'street')}${'${address['building'] ?? ''}'.isEmpty ? '' : ', ${address['building']}'}',
            ),
          ],
          const SizedBox(height: 17),
          const Divider(),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                tr('الإجمالي'),
                style: const TextStyle(color: royalMuted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                tr(money(b['price']?['totalMinor'])),
                style: const TextStyle(
                  color: royalGold,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                tr('حالة الدفع'),
                style: const TextStyle(color: royalMuted, fontSize: 11),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  paymentStatusLabel(b['payment'] as Map? ?? {}),
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: BorderSide(color: royalGold.withValues(alpha: .55)),
                foregroundColor: royalGold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookingDetails(
                    api: api,
                    id: '${b['id']}',
                    employee: employee,
                    preview: previewAccount(user),
                  ),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined, size: 17),
              label: Text(tr('تفاصيل الزيارة')),
            ),
          ),
          if (employee && nextStatus(b['status']) != null)
            button(
              status(nextStatus(b['status'])),
              () => run(() async {
                await api.patch('worker/bookings/${b['id']}/status', {
                  'status': nextStatus(b['status']),
                  'version': b['version'],
                });
                await refresh();
              }),
            ),
        ],
      ),
    );
  }

  String? nextStatus(dynamic s) => {
    'CONFIRMED': 'ON_THE_WAY',
    'ON_THE_WAY': 'ARRIVED',
    'ARRIVED': 'IN_PROGRESS',
    'IN_PROGRESS': 'COMPLETED',
  }[s];
  Widget workerBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(showSchedule ? 'جدولي' : 'زياراتي', 'تابع زياراتك وحدّث حالتها.'),
      const SizedBox(height: 18),
      if (showSchedule) ...[
        Text(tr('المواعيد المسندة خلال ٣٠ يومًا بتوقيت القاهرة.')),
        if (schedule.isEmpty) box(Text(tr('مفيش مواعيد مسندة في الفترة دي.'))),
        for (final item in schedule)
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayServiceName({
                    'nameAr': item['serviceNameAr'],
                    'nameEn': item['serviceNameEn'],
                  }),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(tr(cairoTime(item['startAt']))),
                Text(
                  tr(
                    '${item['reference'] ?? ''} · ${displayAreaName({'nameAr': item['areaNameAr'], 'nameEn': item['areaNameEn']})}',
                  ),
                ),
                Text(tr(status(item['status']))),
              ],
            ),
          ),
      ] else ...[
        historyControls(),
        if (bookings.isEmpty) box(Text(tr('مفيش زيارات في القائمة دي.'))),
        for (final b in bookings)
          bookingCard(Map<String, dynamic>.from(b), employee: true),
        moreButton(),
      ],
    ],
  );
}

class BookingForm extends StatefulWidget {
  final RayeqApi api;
  final Map<String, dynamic> service, catalog;
  final String customerName;
  const BookingForm({
    super.key,
    required this.api,
    required this.service,
    required this.catalog,
    required this.customerName,
  });
  @override
  State<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<BookingForm> {
  final form = GlobalKey<FormState>();
  final contact = TextEditingController(),
      street = TextEditingController(),
      building = TextEditingController(),
      floor = TextEditingController(),
      apartment = TextEditingController(),
      workplace = TextEditingController(),
      directions = TextEditingController();
  late final TextEditingController name;
  String? areaId;
  String location = 'home', payment = 'cash', kind = 'scheduled', error = '';
  bool busy = false, consent = false;
  DateTime? date;
  TimeOfDay? time;
  Map<String, dynamic>? quote;
  String? key;
  Map<String, dynamic>? pendingPayload;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.customerName);
  }

  @override
  void dispose() {
    for (final c in [
      name,
      contact,
      street,
      building,
      floor,
      apartment,
      workplace,
      directions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    String label,
    TextEditingController c, {
    bool required = true,
    TextInputType? keyboard,
  }) => Padding(
    padding: EdgeInsets.only(top: 16),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: (s) =>
          required && (s?.trim().isEmpty ?? true) ? tr('مطلوب') : null,
      decoration: InputDecoration(labelText: tr(label)),
    ),
  );
  String get dateString => date == null
      ? ''
      : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}';
  String get timeString => time == null
      ? ''
      : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (areaId == null ||
        !consent ||
        (kind == 'scheduled' && (date == null || time == null))) {
      setState(() => error = 'اختار المنطقة والمعاد ووافق على مراجعة الطلب.');
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final q = await widget.api.post('quotes', {
        'serviceId': widget.service['id'],
        'areaId': areaId,
      });
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          actionsAlignment: MainAxisAlignment.end,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actionsOverflowButtonSpacing: 8,
          buttonPadding: const EdgeInsetsDirectional.only(start: 8),
          title: Text(tr('راجع طلب الزيارة')),
          content: Text(
            tr(
              '${tr(displayServiceName(widget.service))}\n${tr('الإجمالي')}: ${tr(egp(q['totalMinor']))}\n${tr('طريقة الدفع')}: ${tr(payment == 'cash' ? 'كاش' : 'إنستا باي للشركة')}\n${kind == 'scheduled' ? '$dateString • $timeString ${appLocale.value.languageCode == 'en' ? 'Cairo time' : 'بتوقيت القاهرة'}' : tr('في أقرب وقت، بعد المراجعة')}\n${tr('الطلب يتأكد بعد مراجعة الإدارة. كل الأوقات بتوقيت القاهرة.')}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('رجوع')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('إرسال الطلب')),
            ),
          ],
        ),
      );
      if (yes != true) return;
      final payload = <String, dynamic>{
        'serviceId': widget.service['id'],
        'areaId': areaId,
        'serviceVersion': q['serviceVersion'],
        'areaVersion': q['areaVersion'],
        'customerName': name.text.trim(),
        'contactPhone': contact.text.trim(),
        'locationType': location,
        'address': {
          'street': street.text.trim(),
          'building': building.text.trim(),
          'floor': floor.text.trim(),
          'apartment': apartment.text.trim(),
          'workplaceName': workplace.text.trim(),
          'directions': directions.text.trim(),
        },
        'bookingType': kind,
        'timezone': 'Africa/Cairo',
        'paymentMethod': payment,
        'consent': true,
        if (kind == 'scheduled') 'localDate': dateString,
        if (kind == 'scheduled') 'localTime': timeString,
      };
      // Keep a retry identity only while the full payload remains identical.
      if (jsonEncode(pendingPayload) != jsonEncode(payload)) {
        key = RayeqApi.idempotencyKey();
        pendingPayload = payload;
      }
      await widget.api.post('bookings', payload, idempotencyKey: key);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          actionsAlignment: MainAxisAlignment.end,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actionsOverflowButtonSpacing: 8,
          buttonPadding: const EdgeInsetsDirectional.only(start: 8),
          icon: Icon(Icons.check_circle_outline, color: royalGold, size: 52),
          title: Text(tr('طلبك اتسجل')),
          content: Text(
            tr(
              'الإدارة هتراجع التفاصيل وتأكد الزيارة معاك. ده مش تأكيد توفر أو تحصيل دفع.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('شوف حجوزاتي')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر إرسال الطلب. جرّب تاني.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.catalog['areas'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(tr('طلب زيارة'))),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 580),
          child: AbsorbPointer(
            absorbing: busy,
            child: Form(
              key: form,
              child: ListView(
                padding: EdgeInsets.all(24),
                children: [
                  Text(
                    tr(displayServiceName(widget.service)),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Text(
                    tr(
                      'الطلب يتأكد بعد مراجعة الإدارة. كل الأوقات بتوقيت القاهرة.',
                    ),
                  ),
                  if (busy) LinearProgressIndicator(),
                  if (error.isNotEmpty)
                    RoyalNotice(message: error, error: true),
                  input('اسم العميل', name),
                  input(
                    'موبايل للتواصل فقط',
                    contact,
                    keyboard: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: areaId,
                    decoration: InputDecoration(labelText: tr('منطقة الخدمة')),
                    items: areas
                        .map(
                          (a) => DropdownMenuItem<String>(
                            value: '${a['id']}',
                            child: Text(displayAreaName(Map.from(a))),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => areaId = v),
                  ),
                  SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'home', label: Text(tr('في البيت'))),
                      ButtonSegment(value: 'work', label: Text(tr('في الشغل'))),
                    ],
                    selected: {location},
                    onSelectionChanged: (s) =>
                        setState(() => location = s.first),
                  ),
                  input('الشارع', street),
                  input('رقم العمارة', building),
                  input('الدور', floor, required: false),
                  input('الشقة', apartment, required: false),
                  if (location == 'work') input('جهة العمل', workplace),
                  input('علامة مميزة', directions, required: false),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: InputDecoration(labelText: tr('نوع الزيارة')),
                    items: [
                      DropdownMenuItem(
                        value: 'scheduled',
                        child: Text(tr('معاد مطلوب')),
                      ),
                      DropdownMenuItem(
                        value: 'immediate',
                        child: Text(tr('في أقرب وقت، بعد المراجعة')),
                      ),
                    ],
                    onChanged: (v) => setState(() => kind = v!),
                  ),
                  if (kind == 'scheduled') ...[
                    SizedBox(height: 20),
                    Text(
                      tr('اختار يوم تطلبه'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: royalSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: royalLine),
                      ),
                      child: CalendarDatePicker(
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 90)),
                        onDateChanged: (d) => setState(() => date = d),
                      ),
                    ),
                    Text(
                      tr(
                        'الأيام الظاهرة لا تعني توفر مواعيد. التأكيد بعد مراجعة الإدارة.',
                      ),
                      style: TextStyle(color: royalMuted, fontSize: 10),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(Duration(days: 90)),
                        );
                        if (d != null && mounted) setState(() => date = d);
                      },
                      child: Text(
                        tr(date == null ? 'اختار اليوم' : dateString),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null && mounted) setState(() => time = t);
                      },
                      child: Text(
                        tr(time == null ? 'اختار الساعة' : timeString),
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    decoration: InputDecoration(labelText: tr('طريقة الدفع')),
                    items: [
                      DropdownMenuItem(value: 'cash', child: Text(tr('كاش'))),
                      if (widget.catalog['instapayAvailable'] == true)
                        DropdownMenuItem(
                          value: 'instapay',
                          child: Text(tr('إنستا باي لحساب الشركة')),
                        ),
                    ],
                    onChanged: (v) => setState(() => payment = v!),
                  ),
                  if (payment == 'instapay')
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        tr(
                          'لا تحول أي مبلغ قبل استلام بيانات الشركة المؤكدة من الإدارة. اختيار الطريقة لا يعني الدفع.',
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: (v) => setState(() => consent = v ?? false),
                    title: Text(
                      tr('فاهم إن ده طلب زيارة، والتأكيد بعد مراجعة الإدارة.'),
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(tr('مراجعة السعر وإرسال الطلب')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
