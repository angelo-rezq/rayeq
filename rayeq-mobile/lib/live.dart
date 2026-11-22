import 'dart:convert';

import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

import 'api.dart';

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
  bool busy = false, worker = false;
  int tab = 0;
  List<dynamic> bookings = [], schedule = [];
  bool past = false, showSchedule = false;
  String? nextCursor;
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
        screen = 'home';
        await refresh();
      }
    });
  }

  Future<void> refresh() async {
    if (user == null) return;
    user = await api.getMap('me');
    if (user!['role'] == 'customer') catalog = await api.getMap('catalog');
    if (user!['role'] == 'customer' || user!['role'] == 'worker')
      await loadBookings();
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
        'to': DateFormat('yyyy-MM-dd')
            .format(now.add(const Duration(days: 30))),
      },
    );
    schedule = r['items'] as List? ?? [];
  }

  Widget historyControls() => Wrap(
    spacing: 8,
    children: [
      for (final value in [false, true])
        ChoiceChip(
          label: Text(value ? 'السابقة' : 'الحالية'),
          selected: past == value,
          onSelected: busy
              ? null
              : (_) => run(() async {
                  past = value;
                  await loadBookings();
                }),
        ),
    ],
  );
  Widget moreButton() => nextCursor == null
      ? const SizedBox.shrink()
      : button('تحميل المزيد', () => run(() => loadBookings(append: true)));

  Future<void> session(Map<String, dynamic> data) async {
    if (data['next'] == 'login') {
      screen = 'login';
      return;
    }
    await api.saveSession(data);
    user = await api.getMap('me');
    screen = 'home';
    password.clear();
    code.clear();
    await refresh();
  }

  Future<void> auth() async => run(() async {
    final e = email.text.trim();
    if (!e.contains('@') || password.text.length < 8) {
      throw const ApiFailure(
        'VALIDATION',
        'اكتب إيميل صحيح وكلمة مرور ٨ أحرف على الأقل.',
      );
    }
    if (screen == 'register') {
      if (name.text.trim().isEmpty) {
        throw const ApiFailure('VALIDATION', 'اكتب اسمك الأول.');
      }
      await api.post('auth/register', {
        'name': name.text.trim(),
        'email': e,
        'password': password.text,
        'accountType': worker ? 'worker' : 'customer',
      });
      screen = 'verify';
    } else {
      try {
        await session(
          await api.post('auth/login', {'email': e, 'password': password.text}),
        );
      } on ApiFailure catch (e) {
        if (e.code == 'EMAIL_NOT_VERIFIED') screen = 'verify';
        rethrow;
      }
    }
  });
  Widget button(String text, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: screen == 'splash'
            ? FilledButton.styleFrom(
                backgroundColor: const Color(0xffc79871),
                foregroundColor: const Color(0xff191919),
              )
            : null,
        onPressed: busy ? null : action,
        child: Text(text),
      ),
    ),
  );
  Widget field(
    String label,
    TextEditingController c, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: TextField(
      controller: c,
      obscureText: secret,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget box(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 18),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xfffffcf7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe2d9ce)),
    ),
    child: child,
  );
  Widget heading(String title, String desc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text(desc, style: const TextStyle(color: Color(0xff77736e), height: 1.9)),
    ],
  );
  void go(String target) {
    setState(() {
      screen = target;
      error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (screen == 'splash') {
      return Scaffold(
        backgroundColor: const Color(0xff191919),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  'رايق',
                  style: TextStyle(
                    fontSize: 92,
                    color: Color(0xfff4f0e8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'حلاقك عندك',
                  style: TextStyle(fontSize: 20, color: Color(0xffc2a286)),
                ),
                const Spacer(),
                const Text(
                  'المنيا القديمة والجديدة',
                  style: TextStyle(color: Color(0xffc2a286)),
                ),
                button('خلّينا نبدأ', () => go('login')),
              ],
            ),
          ),
        ),
      );
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
        title: const Text('رايق'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'تحديث',
              onPressed: busy ? null : () => run(refresh),
              icon: const Icon(Icons.refresh),
            ),
          if (user != null)
            IconButton(
              tooltip: 'خروج',
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await api.logout();
                      user = null;
                      catalog = null;
                      bookings = [];
                      screen = 'login';
                    }),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error.isNotEmpty)
                box(Text(error, style: const TextStyle(color: Colors.red))),
              if (authPage)
                authBody()
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
      bottomNavigationBar: authPage || user?['role'] != 'customer'
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.content_cut),
                  label: 'الخدمات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'حجوزاتي',
                ),
              ],
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
            'اكتب كود التفعيل اللي وصلك. حساب العامل ينتظر موافقة الإدارة بعد التفعيل.',
          ),
          box(Text(email.text, textDirection: TextDirection.ltr)),
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
                        const SnackBar(
                          content: Text(
                            'لو الإيميل مسجل ومتاح للإرسال، هتوصلك رسالة.',
                          ),
                        ),
                      );
                    }
                  }),
            child: const Text('إعادة إرسال الكود'),
          ),
          TextButton(
            onPressed: () => go('login'),
            child: const Text('رجوع للدخول'),
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
            child: const Text('رجوع للدخول'),
          ),
        ],
      );
    }
    final register = screen == 'register';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          register ? 'أهلًا بيك في رايق' : 'نورت رايق',
          register
              ? 'حساب خفيف، وزيارات على مزاجك.'
              : 'ادخل حسابك ورتّب وقت لنفسك.',
        ),
        if (register) field('اسمك بالكامل', name),
        field('البريد الإلكتروني', email, keyboard: TextInputType.emailAddress),
        field('كلمة المرور', password, secret: true),
        if (register) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('عميل'),
                selected: !worker,
                onSelected: (_) => setState(() => worker = false),
              ),
              ChoiceChip(
                label: const Text('انضم كعامل'),
                selected: worker,
                onSelected: (_) => setState(() => worker = true),
              ),
            ],
          ),
          if (worker)
            box(
              const Text(
                'حساب العامل يحتاج موافقة الإدارة. التسجيل لا يفتح بيانات العملاء أو الزيارات.',
              ),
            ),
        ],
        button(register ? 'إنشاء حساب' : 'دخول', auth),
        TextButton(
          onPressed: () => go(register ? 'login' : 'register'),
          child: Text(register ? 'عندك حساب؟ سجّل دخول' : 'أول مرة؟ اعمل حساب'),
        ),
        if (!register)
          TextButton(
            onPressed: () => go('forgot'),
            child: const Text('نسيت كلمة المرور؟'),
          ),
      ],
    );
  }

  Widget pendingBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'طلبك عند الإدارة',
        'إيميلك اتفعّل، وحساب العامل في انتظار الموافقة. بيانات الزيارات هتظهر بعد موافقة الإدارة وإسناد مهام ليك.',
      ),
      button('تحديث حالة الحساب', () => run(refresh)),
    ],
  );
  String money(dynamic value) =>
      '${((value as num? ?? 0) / 100).toStringAsFixed(2)} ج.م';
  String cairoTime(dynamic raw) {
    if (raw == null) return 'في أقرب وقت، بعد تأكيد الإدارة';
    try {
      return '${DateFormat('yyyy/MM/dd • HH:mm', 'ar').format(tz.TZDateTime.from(DateTime.parse('$raw'), tz.getLocation('Africa/Cairo')))} بتوقيت القاهرة';
    } catch (_) {
      return 'راجع الإدارة لتأكيد الموعد';
    }
  }

  String status(dynamic s) =>
      const {
        'PENDING': 'قيد المراجعة',
        'UNDER_REVIEW': 'تحت المراجعة',
        'CONFIRMED': 'تم التأكيد',
        'ON_THE_WAY': 'في الطريق',
        'ARRIVED': 'وصل العامل',
        'IN_PROGRESS': 'الخدمة بدأت',
        'COMPLETED': 'مكتملة',
        'CANCELLED': 'ملغاة',
      }[s] ??
      '${s ?? ''}';
  Widget customerBody() {
    if (tab == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('حجوزاتي', 'طلباتك وحالة كل زيارة.'),
          historyControls(),
          if (bookings.isEmpty)
            box(const Text('مفيش حجوزات حالية. اختار خدمة واطلب زيارة.')),
          for (final b in bookings) bookingCard(Map<String, dynamic>.from(b)),
          moreButton(),
        ],
      );
    }
    final services = catalog?['services'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'عنايتك بنفسك.\nفي المكان اللي يريحك.',
          'حلاقك يوصلك للبيت أو الشغل. الطلب يتأكد بعد مراجعة الإدارة.',
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/grooming.webp',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (catalog?['isDemo'] == true)
          box(
            const Text(
              'بيئة اختبار. الخدمات والأسعار تجريبية وليست عرضًا تجاريًا.',
            ),
          ),
        if (catalog?['intakeEnabled'] != true)
          box(const Text('استقبال الطلبات مش متاح حاليًا.')),
        if (services.isEmpty)
          box(const Text('الخدمات هتظهر هنا بعد تجهيزها من الإدارة.')),
        for (final item in services)
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['nameAr']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${item['descriptionAr'] ?? ''}'),
                const SizedBox(height: 12),
                Text(
                  '${item['durationMinutes']} دقيقة · ${money(item['priceMinor'])}',
                ),
                button(
                  'طلب زيارة',
                  () => openBooking(Map<String, dynamic>.from(item)),
                ),
              ],
            ),
          ),
      ],
    );
  }

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
          customerName: '${user?['name'] ?? ''}',
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => tab = 1);
      await run(refresh);
    }
  }

  Widget bookingCard(Map<String, dynamic> b, {bool employee = false}) => box(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${b['service']?['nameAr'] ?? ''}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('${b['reference'] ?? ''} · ${status(b['status'])}'),
        Text('الموعد المطلوب: ${cairoTime(b['requestedAt'])}'),
        Text('${b['area']?['nameAr'] ?? ''}'),
        if (employee) ...[
          Text('${b['customerName'] ?? ''} · ${b['contactPhone'] ?? ''}'),
          Text(
            '${b['address']?['street'] ?? ''}، ${b['address']?['building'] ?? ''}',
          ),
          Text(
            'الدور ${b['address']?['floor'] ?? '-'} · شقة ${b['address']?['apartment'] ?? '-'}',
          ),
          Text('${b['address']?['directions'] ?? ''}'),
        ],
        Text('الإجمالي: ${money(b['price']?['totalMinor'])}'),
        Text(
          'الدفع: ${b['payment']?['status'] == 'PAID' ? 'مدفوع' : 'غير مؤكد التحصيل'}',
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
  String? nextStatus(dynamic s) => const {
    'CONFIRMED': 'ON_THE_WAY',
    'ON_THE_WAY': 'ARRIVED',
    'ARRIVED': 'IN_PROGRESS',
    'IN_PROGRESS': 'COMPLETED',
  }[s];
  Widget workerBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        showSchedule ? 'جدولي' : 'زياراتي',
        'المهام المسندة ليك فقط. إكمال الزيارة لا يعني تحصيل الدفع.',
      ),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('الزيارات'),
            selected: !showSchedule,
            onSelected: busy
                ? null
                : (_) => setState(() => showSchedule = false),
          ),
          ChoiceChip(
            label: const Text('الجدول'),
            selected: showSchedule,
            onSelected: busy
                ? null
                : (_) => run(() async {
                    showSchedule = true;
                    await loadSchedule();
                  }),
          ),
        ],
      ),
      if (showSchedule) ...[
        const Text('المواعيد المسندة خلال ٣٠ يومًا بتوقيت القاهرة.'),
        if (schedule.isEmpty)
          box(const Text('مفيش مواعيد مسندة في الفترة دي.')),
        for (final item in schedule)
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['serviceNameAr'] ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(cairoTime(item['startAt'])),
                Text(
                  '${item['reference'] ?? ''} · ${item['areaNameAr'] ?? ''}',
                ),
                Text(status(item['status'])),
              ],
            ),
          ),
      ] else ...[
        historyControls(),
        if (bookings.isEmpty) box(const Text('مفيش زيارات في القائمة دي.')),
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
    padding: const EdgeInsets.only(top: 16),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: (s) =>
          required && (s?.trim().isEmpty ?? true) ? 'مطلوب' : null,
      decoration: InputDecoration(labelText: label),
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
          title: const Text('راجع طلب الزيارة'),
          content: Text(
            '${widget.service['nameAr']}\nالإجمالي: ${((q['totalMinor'] as num) / 100).toStringAsFixed(2)} ج.م\nالدفع: ${payment == 'cash' ? 'كاش' : 'إنستا باي للشركة'}\n${kind == 'scheduled' ? '$dateString الساعة $timeString بتوقيت القاهرة' : 'في أقرب وقت بعد المراجعة'}\nده طلب موعد، مش تأكيد توفر. الإدارة تراجع وتتواصل معاك.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال الطلب'),
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
      appBar: AppBar(title: const Text('طلب زيارة')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: AbsorbPointer(
            absorbing: busy,
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '${widget.service['nameAr']}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Text(
                    'الطلب يتأكد بعد مراجعة الإدارة. كل الأوقات بتوقيت القاهرة.',
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),
                  input('اسم العميل', name),
                  input(
                    'موبايل للتواصل فقط',
                    contact,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: areaId,
                    decoration: const InputDecoration(
                      labelText: 'منطقة الخدمة',
                    ),
                    items: areas
                        .map(
                          (a) => DropdownMenuItem<String>(
                            value: '${a['id']}',
                            child: Text('${a['nameAr']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => areaId = v),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'home', label: Text('في البيت')),
                      ButtonSegment(value: 'work', label: Text('في الشغل')),
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'نوع الزيارة'),
                    items: const [
                      DropdownMenuItem(
                        value: 'scheduled',
                        child: Text('معاد مطلوب'),
                      ),
                      DropdownMenuItem(
                        value: 'immediate',
                        child: Text('في أقرب وقت، بعد المراجعة'),
                      ),
                    ],
                    onChanged: (v) => setState(() => kind = v!),
                  ),
                  if (kind == 'scheduled') ...[
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 90)),
                        );
                        if (d != null && mounted) setState(() => date = d);
                      },
                      child: Text(date == null ? 'اختار اليوم' : dateString),
                    ),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null && mounted) setState(() => time = t);
                      },
                      child: Text(time == null ? 'اختار الساعة' : timeString),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: [
                      const DropdownMenuItem(value: 'cash', child: Text('كاش')),
                      if (widget.catalog['instapayAvailable'] == true)
                        const DropdownMenuItem(
                          value: 'instapay',
                          child: Text('إنستا باي لحساب الشركة'),
                        ),
                    ],
                    onChanged: (v) => setState(() => payment = v!),
                  ),
                  if (payment == 'instapay')
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'لا تحول أي مبلغ قبل استلام بيانات الشركة المؤكدة من الإدارة. اختيار الطريقة لا يعني الدفع.',
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: (v) => setState(() => consent = v ?? false),
                    title: const Text(
                      'فاهم إن ده طلب زيارة، والتأكيد بعد مراجعة الإدارة.',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: const Text('مراجعة السعر وإرسال الطلب'),
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
