import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'live.dart';

const ink = Color(0xff191919),
    ivory = Color(0xffF4F0E8),
    copper = Color(0xffB77A52),
    stone = Color(0xff77736E),
    line = Color(0xffE2D9CE),
    paper = Color(0xffFFFCF7);
void main() => runApp(const RayeqApp());

class RayeqApp extends StatelessWidget {
  final RayeqApi? api;
  const RayeqApp({super.key, this.api});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'رايق | حلاقك عندك',
    locale: const Locale('ar', 'EG'),
    supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'PlexArabic',
      scaffoldBackgroundColor: ivory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: copper,
        surface: ivory,
        primary: ink,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, height: 1.8, color: ink),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.6,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.6,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xffA79B8B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: copper, width: 1.5),
        ),
      ),
    ),
    home: RayeqApi.designPreview ? const RayeqShell() : LiveShell(api: api),
  );
}

class RayeqShell extends StatefulWidget {
  const RayeqShell({super.key});
  @override
  State<RayeqShell> createState() => _RayeqShellState();
}

class _RayeqShellState extends State<RayeqShell> {
  String screen = Uri.base.queryParameters['screen'] ?? 'splash';
  bool obscure = true, workerAccount = false;
  int nav = 0, bookingStep = 0;
  String place = 'home';
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  void go(String value) {
    setState(() => screen = value);
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7, top: 19),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Color(0xff61574B)),
    ),
  );
  Widget small(String text) => Text(
    text,
    style: const TextStyle(color: stone, fontSize: 12, height: 1.9),
  );
  Widget title(String eyebrow, String heading, String desc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(fontSize: 11, color: Color(0xff94603B)),
      ),
      const SizedBox(height: 9),
      Text(heading, style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 7),
      small(desc),
    ],
  );
  Widget brand({bool large = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'رايق',
        style: TextStyle(
          fontSize: large ? 92 : 33,
          height: 1.15,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.5,
          color: screen == 'splash' ? ivory : ink,
        ),
      ),
      Text(
        'حلاقك عندك',
        style: TextStyle(
          fontSize: large ? 18 : 10,
          color: screen == 'splash' ? const Color(0xffC2A286) : stone,
        ),
      ),
    ],
  );
  Widget action(
    String text,
    VoidCallback onTap, {
    bool light = false,
  }) => SizedBox(
    width: double.infinity,
    height: 53,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: light ? const Color(0xffC79871) : ink,
        foregroundColor: light ? ink : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 22),
          const Icon(Icons.arrow_back, size: 19),
        ],
      ),
    ),
  );
  Widget panel(Widget child, {Color color = paper}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(21),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: child,
  );
  Widget note(String text, {IconData icon = Icons.lock_outline}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xffEAE3D8),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xff957456)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.9,
              color: Color(0xff7A6C5A),
            ),
          ),
        ),
      ],
    ),
  );
  PreferredSizeWidget appbar({String? subtitle}) => AppBar(
    backgroundColor: ivory,
    surfaceTintColor: ivory,
    toolbarHeight: 87,
    automaticallyImplyLeading: false,
    title: brand(),
    actions: [
      if (subtitle != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 22),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: stone),
          ),
        )
      else
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 22),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: copper),
              const SizedBox(width: 5),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المنيا', style: TextStyle(fontSize: 12)),
                  Text(
                    'القديمة والجديدة',
                    style: const TextStyle(fontSize: 10, color: stone),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: line),
    ),
  );
  Widget content(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: child,
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (screen == 'splash') {
      return Scaffold(
        backgroundColor: ink,
        body: SafeArea(
          child: content(
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  brand(large: true),
                  const Spacer(flex: 3),
                  const Text(
                    'اهتمام يوصلك.',
                    style: TextStyle(color: Color(0xffA59887), fontSize: 13),
                  ),
                  const SizedBox(height: 25),
                  action('خلّينا نبدأ', () => go('login'), light: true),
                  const SizedBox(height: 24),
                  const Text(
                    'المنيا القديمة والجديدة',
                    style: TextStyle(fontSize: 10, color: Color(0xff8F8171)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (['login', 'register', 'verify'].contains(screen)) return authScreen();
    if (screen == 'worker') return workerScreen();
    if (screen == 'booking') return bookingScreen();
    return Scaffold(
      appBar: appbar(),
      body: content(
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(23, 27, 23, 30),
          child: screen == 'bookings'
              ? bookingsScreen()
              : screen == 'services'
              ? servicesScreen()
              : homeScreen(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: paper,
        surfaceTintColor: paper,
        indicatorColor: const Color(0xffEEDFCF),
        selectedIndex: screen == 'services'
            ? 1
            : screen == 'bookings'
            ? 2
            : nav,
        onDestinationSelected: (i) {
          setState(() => nav = i);
          go(['home', 'services', 'bookings', 'login'][i]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.content_cut_outlined),
            label: 'الخدمات',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'حجوزاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }

  Widget authScreen() {
    final register = screen == 'register', verify = screen == 'verify';
    return Scaffold(
      body: SafeArea(
        child: content(
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 25, 25, 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    brand(),
                    TextButton(
                      onPressed: () => go('splash'),
                      child: const Row(
                        children: [
                          Text(
                            'رجوع',
                            style: TextStyle(color: stone, fontSize: 11),
                          ),
                          SizedBox(width: 7),
                          Icon(Icons.arrow_forward, size: 16, color: stone),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xffD6C1AC)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    verify
                        ? Icons.mark_email_read_outlined
                        : Icons.mail_outline,
                    color: copper,
                    size: 25,
                  ),
                ),
                const SizedBox(height: 25),
                title(
                  verify ? 'خطوة واحدة ونبقى جاهزين' : 'على راحتك، من أول خطوة',
                  verify
                      ? 'بص على إيميلك'
                      : register
                      ? 'أهلًا بيك في رايق'
                      : 'نورت رايق',
                  verify
                      ? 'افتح رسالة التفعيل وأكد حسابك عشان تقدر تحجز.'
                      : register
                      ? 'حساب خفيف، وزيارات على مزاجك.'
                      : 'ادخل حسابك، ورتّب وقت لنفسك.',
                ),
                const SizedBox(height: 12),
                if (verify) ...[
                  const SizedBox(height: 18),
                  panel(
                    Center(
                      child: Text(
                        email.text.isEmpty ? 'you@example.com' : email.text,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  note(
                    'ده تصميم شاشة التفعيل. الإرسال الحقيقي يتفعل بعد تجهيز مزود البريد واختباره.',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 30),
                  action('رجوع للدخول', () => go('login')),
                ] else ...[
                  if (register) ...[
                    label('اسمك'),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        hintText: 'الاسم بالكامل',
                      ),
                      autofillHints: const [AutofillHints.name],
                    ),
                  ],
                  label('البريد الإلكتروني'),
                  TextField(
                    controller: email,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.mail_outline, size: 18),
                    ),
                  ),
                  label('كلمة المرور'),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: '٨ أحرف على الأقل',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  if (!register)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => go('verify'),
                        child: const Text(
                          'نسيت كلمة المرور؟',
                          style: TextStyle(fontSize: 11, color: copper),
                        ),
                      ),
                    ),
                  if (register) ...[
                    const SizedBox(height: 19),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('حساب عميل'),
                          selected: !workerAccount,
                          onSelected: (_) =>
                              setState(() => workerAccount = false),
                        ),
                        ChoiceChip(
                          label: const Text('انضم كعامل'),
                          selected: workerAccount,
                          onSelected: (_) =>
                              setState(() => workerAccount = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    small(
                      workerAccount
                          ? 'حساب العامل يحتاج موافقة الإدارة قبل ظهور الحجوزات.'
                          : 'رقم موبايلك بنطلبه في الحجز للتواصل فقط، مش لتفعيل الحساب.',
                    ),
                  ],
                  const SizedBox(height: 22),
                  action(register ? 'إنشاء حساب' : 'دخول', () => go('verify')),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      small(
                        register ? 'عندك حساب بالفعل؟' : 'أول مرة مع رايق؟',
                      ),
                      TextButton(
                        onPressed: () => go(register ? 'login' : 'register'),
                        child: Text(
                          register ? 'سجّل دخول' : 'اعمل حساب جديد',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff925D37),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: line, height: 35),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: stone),
                      SizedBox(width: 7),
                      Text(
                        'حسابك بيتفعّل بالإيميل، من غير رسائل موبايل.',
                        style: TextStyle(fontSize: 10, color: stone),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 37),
                Center(child: small('رايق · حلاقك عندك')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget homeScreen() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title(
        'وقتك يستاهل',
        'عنايتك بنفسك.\nفي المكان اللي يريحك.',
        'حلاقك يوصلك للبيت أو الشغل.\nاختار خدمتك، وسيب الباقي علينا.',
      ),
      const SizedBox(height: 25),
      ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          height: 245,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/grooming.webp', fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0xE6191919), Color(0x15191919)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(23),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'من غير مشوار',
                      style: TextStyle(fontSize: 11, color: Color(0xffDEC1A8)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إطلالة جديدة.\nعلى راحتك.',
                      style: TextStyle(
                        fontSize: 27,
                        height: 1.6,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 160,
                      child: action(
                        'اختار خدمتك',
                        () => go('services'),
                        light: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.verified_user_outlined, size: 16, color: copper),
          Text(
            'فريق تابع للشركة',
            style: TextStyle(fontSize: 10, color: stone),
          ),
          Icon(Icons.home_outlined, size: 17, color: copper),
          Text(
            'في البيت أو الشغل',
            style: TextStyle(fontSize: 10, color: stone),
          ),
        ],
      ),
      const SizedBox(height: 25),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'وقت لنفسك',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
          ),
          TextButton(
            onPressed: () => go('services'),
            child: const Text(
              'كل الخدمات',
              style: TextStyle(color: copper, fontSize: 12),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      serviceCard(
        'قص وتصفيف الشعر',
        'قصة تناسبك، وتشطيب على مزاجك.',
        '٤٥ دقيقة',
        '١٨٠',
      ),
      const SizedBox(height: 15),
      note(
        'الخدمات والأسعار في معاينة التصميم أمثلة فقط، ولم تُعتمد بعد.',
        icon: Icons.info_outline,
      ),
    ],
  );
  Widget serviceCard(String name, String desc, String duration, String price) =>
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xffEFE3D5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.content_cut, size: 22, color: copper),
                ),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: stone),
                    const SizedBox(width: 5),
                    small(duration),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            small(desc),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$price ج.م',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => go('booking'),
                  icon: const Icon(Icons.arrow_back, size: 19, color: copper),
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Color(0xffDAC0A8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  Widget servicesScreen() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('العناية تبدأ من هنا', 'إيه اللي يناسبك؟', 'خدمات عندك، في وقتك.'),
      const SizedBox(height: 22),
      Wrap(
        spacing: 8,
        children: ['الكل', 'الشعر', 'الذقن', 'باقات']
            .map(
              (s) => ChoiceChip(
                label: Text(s),
                selected: s == 'الكل',
                onSelected: (_) {},
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 22),
      serviceCard(
        'قص وتصفيف الشعر',
        'قصة تناسبك، وتشطيب على مزاجك.',
        '٤٥ دقيقة',
        '١٨٠',
      ),
      const SizedBox(height: 15),
      serviceCard(
        'تهذيب وتحديد الذقن',
        'تفاصيل مرتبة، وإطلالة متجددة.',
        '٢٥ دقيقة',
        '١٠٠',
      ),
      const SizedBox(height: 15),
      serviceCard(
        'العناية الكاملة',
        'قص شعر وتحديد ذقن في زيارة واحدة.',
        '٧٠ دقيقة',
        '٢٥٠',
      ),
      const SizedBox(height: 20),
      note('أسعار توضيحية للتصميم فقط.', icon: Icons.info_outline),
    ],
  );
  Widget bookingsScreen() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title('كل زيارة وراها حكاية', 'حجوزاتي', 'تفاصيل زياراتك، أول بأول.'),
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        children: [
          ChoiceChip(
            label: const Text('الحالية'),
            selected: true,
            onSelected: (_) {},
          ),
          ChoiceChip(
            label: const Text('السابقة'),
            selected: false,
            onSelected: (_) {},
          ),
        ],
      ),
      const SizedBox(height: 22),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF1E3CD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'قيد المراجعة',
                    style: TextStyle(fontSize: 10, color: Color(0xff88633E)),
                  ),
                ),
                const Text(
                  'طلب توضيحي',
                  style: TextStyle(fontSize: 10, color: stone),
                ),
              ],
            ),
            const SizedBox(height: 23),
            const Text(
              'قص وتصفيف الشعر',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            small('الإدارة بتراجع طلبك وترتب الزيارة.'),
            const SizedBox(height: 23),
            rowIcon(Icons.calendar_month_outlined, 'المعاد المطلوب يظهر هنا'),
            const SizedBox(height: 12),
            rowIcon(Icons.home_outlined, 'المنيا القديمة · في البيت'),
            const Divider(color: line, height: 40),
            timeline('الطلب وصل', 'إحنا سجلنا كل التفاصيل', true),
            timeline(
              'مراجعة وتأكيد',
              'الإدارة تتواصل معاك لتأكيد الزيارة',
              true,
            ),
            timeline('حلاقك في الطريق', 'بعد تأكيد الموعد والإسناد', false),
            const SizedBox(height: 7),
            const Divider(color: line),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'تفاصيل الطلب',
                    style: TextStyle(color: copper, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'التواصل مع الإدارة',
                    style: TextStyle(color: stone, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      note(
        'الشاشة تعرض مثالًا لتتبع الحجز، وليست زيارة حقيقية.',
        icon: Icons.info_outline,
      ),
    ],
  );
  Widget rowIcon(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xffA48565)),
      const SizedBox(width: 9),
      Expanded(child: small(text)),
    ],
  );
  Widget timeline(String heading, String detail, bool active) => Padding(
    padding: const EdgeInsets.only(bottom: 25),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? copper : Colors.transparent,
            border: Border.all(color: active ? copper : line),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: TextStyle(fontSize: 13, color: active ? ink : stone),
              ),
              Text(detail, style: const TextStyle(fontSize: 10, color: stone)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget bookingScreen() => Scaffold(
    appBar: appbar(),
    body: content(
      SingleChildScrollView(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              onPressed: () => go('services'),
              child: const Text('رجوع للخدمات', style: TextStyle(color: stone)),
            ),
            title(
              'زيارة على مزاجك',
              'خلّينا نرتب التفاصيل',
              'الطلب يتأكد بعد مراجعة الإدارة والتوفر.',
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['١ المكان', '٢ المعاد', '٣ المراجعة']
                  .map(
                    (s) => Text(
                      s,
                      style: const TextStyle(color: copper, fontSize: 12),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 25),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'نوصلك فين؟',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => place = 'home'),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('في البيت'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            backgroundColor: place == 'home'
                                ? const Color(0xffF1E4D5)
                                : paper,
                            foregroundColor: copper,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => place = 'work'),
                          icon: const Icon(Icons.business_center_outlined),
                          label: const Text('في الشغل'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            backgroundColor: place == 'work'
                                ? const Color(0xffF1E4D5)
                                : paper,
                            foregroundColor: copper,
                          ),
                        ),
                      ),
                    ],
                  ),
                  label('منطقة الخدمة'),
                  DropdownButtonFormField<String>(
                    initialValue: 'المنيا القديمة',
                    items: ['المنيا القديمة', 'المنيا الجديدة']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (_) {},
                  ),
                  label('الشارع ورقم العمارة'),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'مثال: شارع طه حسين، عمارة ١٢',
                    ),
                  ),
                  if (place == 'work') ...[
                    label('اسم جهة العمل'),
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'اسم الشركة أو المكتب',
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            label('الدور'),
                            const TextField(
                              decoration: InputDecoration(hintText: 'الدور'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            label('الشقة'),
                            const TextField(
                              decoration: InputDecoration(
                                hintText: 'رقم الشقة',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  label('علامة مميزة (اختياري)'),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'تفاصيل تساعدنا نوصل لك',
                    ),
                  ),
                  const SizedBox(height: 27),
                  action('اختار المعاد', () => go('login')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget workerScreen() => Scaffold(
    appBar: appbar(subtitle: 'مساحة العامل'),
    body: content(
      SingleChildScrollView(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title('يومك مرتب', 'زياراتي', 'المهام المسندة ليك من الإدارة.'),
            const SizedBox(height: 23),
            Row(
              children: [
                Expanded(
                  child: panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        small('زيارات اليوم'),
                        const Text('٠', style: TextStyle(fontSize: 30)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        small('مكتملة'),
                        const Text('٠', style: TextStyle(fontSize: 30)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'جدول الزيارات',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('اليوم', style: TextStyle(color: copper)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            panel(
              Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 42,
                    color: copper,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'جاهز لأول مهمة؟',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  small(
                    'الإدارة هتسند الزيارات هنا.\nهتشوف المعاد والعنوان والخدمة المطلوبة.',
                  ),
                  const SizedBox(height: 25),
                  note(
                    'طلباتك المسندة ليك فقط هي اللي بتظهر هنا. تفعيل الحساب من الإدارة أولًا.',
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'تحديث الحالة أثناء الزيارة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 15),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  small('معاينة تسلسل الحالات، لا توجد زيارة فعلية.'),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 9,
                    children: ['في الطريق', 'وصلت', 'بدأت الخدمة', 'اكتملت']
                        .map(
                          (s) => Chip(
                            label: Text(
                              s,
                              style: const TextStyle(fontSize: 11),
                            ),
                            side: const BorderSide(color: line),
                            backgroundColor: ivory,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      backgroundColor: paper,
      indicatorColor: const Color(0xffEEDFCF),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'زياراتي',
        ),
        NavigationDestination(icon: Icon(Icons.schedule), label: 'جدولي'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
      ],
      onDestinationSelected: (_) {},
    ),
  );
}
