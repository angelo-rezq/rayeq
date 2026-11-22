import 'package:flutter/material.dart';

import 'about.dart';
import 'app_updates.dart';
import 'barber_profiles.dart';
import 'demo_data.dart';
import 'live.dart';
import 'localization.dart';
import 'nearby.dart';
import 'review_fixtures.dart';
import 'royal_theme.dart';
import 'service_details.dart';
import 'ui_parts.dart';

class ReviewHub extends StatelessWidget {
  const ReviewHub({super.key});
  void open(
    BuildContext context,
    String ar,
    String en,
    Widget Function() page, {
    bool connected = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReviewFrame(ar: ar, en: en, connected: connected, child: page()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget entry(
      String ar,
      String en,
      Widget Function() page, {
      IconData icon = Icons.phone_android,
    }) => Card(
      child: ListTile(
        leading: Icon(icon, color: royalGold),
        title: Text(nearbyText(ar, en)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(context, ar, en, page),
      ),
    );
    Widget shell(String role, int tab, {bool schedule = false}) => LiveShell(
      api: ReviewApi(role: role),
      initialTab: tab,
      initialSchedule: schedule,
    );
    Widget auth(String screen, {bool worker = false}) => LiveShell(
      api: ReviewApi(authenticated: false),
      initialScreen: screen,
      initialWorker: worker,
      initialEmail: screen == 'verify' ? 'preview@example.invalid' : '',
    );
    Widget booking() => BookingForm(
      api: ReviewApi(),
      service: reviewService,
      catalog: reviewCatalog,
      customerName: nearbyText('كريم أحمد', 'Karim Ahmed'),
    );
    Widget nearby() => NearbyBarbersPage(
      api: ReviewApi(),
      service: reviewService,
      catalog: reviewCatalog,
      areaId: 'preview-area',
      locationReader: () async => {'lat': 30.05, 'lng': 31.24},
    );
    Widget section(String ar, String en, List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(
            nearbyText(ar, en),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ...items,
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(nearbyText('رايق | فهرس الشاشات', 'Rayeq | Screen index')),
        actions: [
          TextButton(
            onPressed: () =>
                appLocale.value = appLocale.value.languageCode == 'ar'
                ? const Locale('en')
                : const Locale('ar', 'EG'),
            child: Text(
              appLocale.value.languageCode == 'ar' ? 'English' : 'العربية',
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: royalSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: royalGold.withValues(alpha: .35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nearbyText(
                        'كل الواجهات في مكان واحد',
                        'Every screen in one place',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nearbyText(
                        'دي معاينة للتصميم ببيانات نموذجية. مفيش حجوزات أو مدفوعات أو رفع صور فعلية. تقدر تتنقل داخل كل شاشة وترجع للفهرس من الشريط فوق.',
                        'This is a UI preview with sample data. No real bookings, payments or photo uploads are made. You can use each screen and return to the index from the bar above.',
                      ),
                    ),
                  ],
                ),
              ),
              section('العميل', 'Customer', [
                entry(
                  'الرئيسية والبحث',
                  'Home and search',
                  () => shell('customer', 0),
                ),
                entry('الخدمات', 'Services', () => shell('customer', 1)),
                entry(
                  'تفاصيل الخدمة',
                  'Service details',
                  () => ServiceDetails(
                    service: reviewService,
                    demo: true,
                    onBook: () => open(context, 'الحجز', 'Booking', booking),
                    onNearby: () => open(
                      context,
                      'الحلاقون القريبون',
                      'Nearby barbers',
                      nearby,
                    ),
                  ),
                ),
                entry(
                  'الحجز ومراجعة السعر والتأكيد',
                  'Booking, quote and confirmation',
                  booking,
                ),
                entry('اختيار حلاق قريب', 'Choose a nearby barber', nearby),
                entry(
                  'ملف الحلاق والأعمال والتقييمات',
                  'Barber profile, photos and reviews',
                  () => LiveBarberProfile(
                    api: ReviewApi(),
                    barber: reviewBarber,
                    onBook: () => open(context, 'الحجز', 'Booking', booking),
                  ),
                ),
                entry(
                  'ملف تجريبي بتقييمات نموذجية',
                  'Sample profile with example reviews',
                  () => DemoBarberPage(
                    barber: demoBarbers.first,
                    onServices: () => open(
                      context,
                      'الخدمات',
                      'Services',
                      () => shell('customer', 1),
                    ),
                  ),
                ),
                entry(
                  'حجوزاتي الحالية والسابقة',
                  'Current and past bookings',
                  () => shell('customer', 2),
                ),
                entry(
                  'تفاصيل الزيارة المكتملة والتقييم',
                  'Completed visit details and rating',
                  () => BookingDetails(api: ReviewApi(), id: 'preview-booking'),
                ),
                entry(
                  'كتابة تقييم للزيارة',
                  'Write a visit review',
                  () => ReviewComposer(onSubmit: (_, __) async {}),
                ),
                entry('المحفوظات', 'Saved', () => shell('customer', 3)),
                entry(
                  'الحساب وتعديل البيانات والصورة',
                  'Account, profile and photo',
                  () => shell('customer', 4),
                ),
              ]),
              section('الحلاق', 'Worker', [
                entry(
                  'الزيارات وحالات التنفيذ',
                  'Visits and progress',
                  () => shell('worker', 0),
                ),
                entry(
                  'تفاصيل الزيارة المسندة',
                  'Assigned visit details',
                  () => BookingDetails(
                    api: ReviewApi(role: 'worker'),
                    id: 'preview-booking',
                    employee: true,
                  ),
                ),
                entry(
                  'الجدول والتوفر',
                  'Schedule and availability',
                  () => shell('worker', 1, schedule: true),
                ),
                entry(
                  'الحساب والتقييم وصور الأعمال',
                  'Account, rating and portfolio',
                  () => shell('worker', 2),
                ),
                entry(
                  'إدارة صور الأعمال والرفع',
                  'Work photo management and upload',
                  () => Scaffold(
                    appBar: AppBar(
                      title: Text(nearbyText('معرض الأعمال', 'Portfolio')),
                    ),
                    body: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        WorkerPortfolioCard(api: ReviewApi(role: 'worker')),
                      ],
                    ),
                  ),
                ),
                entry(
                  'حساب حلاق في انتظار الموافقة',
                  'Worker awaiting approval',
                  () => shell('worker_pending', 0),
                ),
                entry(
                  'إنشاء حساب حلاق',
                  'Create a worker account',
                  () => auth('register', worker: true),
                ),
              ]),
              section('الدخول والبداية', 'Welcome and authentication', [
                entry('البداية', 'Welcome', () => auth('splash')),
                entry('مقدمة ١', 'Introduction 1', () => auth('onboard1')),
                entry('مقدمة ٢', 'Introduction 2', () => auth('onboard2')),
                entry('تسجيل الدخول', 'Sign in', () => auth('login')),
                entry(
                  'إنشاء حساب عميل',
                  'Create a customer account',
                  () => auth('register'),
                ),
                entry('تفعيل البريد', 'Verify email', () => auth('verify')),
                entry(
                  'استعادة الحساب',
                  'Account recovery',
                  () => auth('forgot'),
                ),
                entry(
                  'تغيير كلمة المرور',
                  'Reset password',
                  () => auth('reset'),
                ),
              ]),
              section('عن التطبيق والتحديثات', 'App information and updates', [
                entry('عن رايق', 'About Rayeq', () => const AboutRayeq()),
                entry(
                  'سياسة الخصوصية',
                  'Privacy policy',
                  () => const PrivacyPolicy(),
                ),
                for (final required in [false, true])
                  entry(
                    required ? 'التحديث المطلوب' : 'التحديث الاختياري',
                    required ? 'Required update' : 'Optional update',
                    () => ReviewUpdate(requiredUpdate: required),
                  ),
              ]),
              const SizedBox(height: 24),
              const Divider(),
              Text(
                nearbyText(
                  'التطبيق المتصل منفصل عن المعاينة. يستخدم الخادم والحسابات والبيانات الفعلية.',
                  'The connected app is separate from this preview. It uses the live server, accounts and records.',
                ),
                style: const TextStyle(color: royalMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => open(
                  context,
                  'التطبيق المتصل',
                  'Connected app',
                  () => const LiveShell(),
                  connected: true,
                ),
                icon: const Icon(Icons.public),
                label: Text(
                  nearbyText('فتح التطبيق المتصل', 'Open connected app'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewFrame extends StatelessWidget {
  final String ar, en;
  final Widget child;
  final bool connected;
  const ReviewFrame({
    super.key,
    required this.ar,
    required this.en,
    required this.child,
    this.connected = false,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Container(
            color: royalSurface,
            child: Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.grid_view, size: 17),
                  label: Text(nearbyText('الفهرس', 'Index')),
                ),
                Expanded(
                  child: Text(
                    connected
                        ? nearbyText(
                            'متصل بالخادم الفعلي',
                            'Connected to live server',
                          )
                        : nearbyText(
                            'معاينة فقط · بيانات نموذجية',
                            'UI preview · Sample data',
                          ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: connected ? royalGold : royalMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
            ),
          ),
        ],
      ),
    ),
  );
}

class ReviewUpdate extends StatelessWidget {
  final bool requiredUpdate;
  const ReviewUpdate({super.key, required this.requiredUpdate});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(nearbyText('معاينة التحديث', 'Update preview'))),
    body: UpdateDialog(
      info: const UpdateInfo(
        2,
        1,
        '1.1.0',
        '',
        '',
        'تحسينات في الواجهة وتجربة الحجز.',
        'Interface and booking improvements.',
      ),
      requiredUpdate: requiredUpdate,
      installedBuild: 1,
      graceRemaining: requiredUpdate
          ? Duration.zero
          : const Duration(hours: 47),
    ),
  );
}
