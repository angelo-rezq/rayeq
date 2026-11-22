import 'localization.dart';

import 'package:flutter/material.dart';

import 'royal_theme.dart';

// Owner-requested UI fixtures. Never an API worker identity and never bookable.
// Remove this module before commercial launch. Show only while isDemo is true.
final demoBarbers = <Map<String, dynamic>>[
  {
    'id': 'demo-alex',
    'name': 'Alex Morgan',
    'specialty': 'Classic cuts & styling',
    'image': 'assets/images/barber-alex.webp',
    'rating': '4.8',
    'reviews': '124',
    'years': '8',
    'bio': 'Precision in every cut, with a relaxed, personal approach.',
    'reviewName': 'James Parker',
    'review': 'A sharp cut and great attention to detail. Exactly the style I wanted.',
  },
  {
    'id': 'demo-daniel',
    'name': 'Daniel Reed',
    'specialty': 'Beard care & detail',
    'image': 'assets/images/barber-daniel.webp',
    'rating': '4.7',
    'reviews': '86',
    'years': '6',
    'bio': 'Clean lines, careful detail, and a style that feels like you.',
    'reviewName': 'Oliver Scott',
    'review': 'Professional, on time, and a finish I was really happy with.',
  },
];

// Preview labels are intentionally hidden in the owner-reviewed mockup.
class DemoBadge extends StatelessWidget {
  final String text;
  const DemoBadge({super.key, this.text = ''});
  @override
  Widget build(BuildContext context) => SizedBox.shrink();
}

const fixtureArabic = <String, String>{
  'Alex Morgan': 'أليكس مورغان',
  'Daniel Reed': 'دانيال ريد',
  'James Parker': 'جيمس باركر',
  'Karim Ahmed': 'كريم أحمد',
  'Oliver Scott': 'أوليفر سكوت',
  'Classic cuts & styling': 'قصات كلاسيكية وتصفيف',
  'Beard care & detail': 'عناية بالذقن وتحديد',
  'Precision in every cut, with a relaxed, personal approach.':
      'دقة في كل قصة، وعناية تناسب أسلوبك.',
  'Clean lines, careful detail, and a style that feels like you.':
      'تحديد متقن وتفاصيل مرتبة، لإطلالة تشبهك.',
  'A sharp cut and great attention to detail. Exactly the style I wanted.':
      'قصة متقنة واهتمام بكل التفاصيل. بالضبط الستايل اللي كنت عايزه.',
  'Professional, on time, and a finish I was really happy with.':
      'شغل مرتب والتزام بالميعاد. النتيجة كانت ممتازة.',
};
String fixtureText(dynamic raw) {
  final value = '$raw';
  if (!previewFixturesEnabled) return value;
  if (appLocale.value.languageCode == 'ar')
    return fixtureArabic[value] ?? value;
  for (final entry in fixtureArabic.entries) {
    if (value == entry.value) return entry.key;
  }
  return value;
}

const previewFixturesEnabled = bool.fromEnvironment(
  'PREVIEW_FIXTURES',
  defaultValue: false,
);
bool previewDataEnabled = false;
bool previewAccount(Map? p) =>
    previewFixturesEnabled &&
    const [
      'customer-test@rayeq.invalid',
      'worker-test@rayeq.invalid',
    ].contains(p?['email']);
bool previewWords(dynamic value) =>
    RegExp('تجريب|اختبار|تجربة فقط|لا توجد زيارة|بدون زيارة')
        .hasMatch('$value');
String localizedContent(Map p, String ar, String en) {
  if (appLocale.value.languageCode == 'en' && '${p[en] ?? ''}'.isNotEmpty)
    return '${p[en]}';
  return tr('${p[ar] ?? ''}');
}

String displayProfileName(Map<String, dynamic> p) {
  final name = '${p['name'] ?? ''}';
  if (!previewWords(name)) return previewAccount(p) ? fixtureText(name) : name;
  if (p['email'] == 'customer-test@rayeq.invalid')
    return fixtureText('James Parker');
  if (p['email'] == 'worker-test@rayeq.invalid')
    return fixtureText('Daniel Reed');
  return name;
}

String displayServiceName(Map p) {
  final name = '${p['nameAr'] ?? ''}';
  if (previewDataEnabled && previewWords(name)) return tr('حلاقة وتصفيف');
  return localizedContent(p, 'nameAr', 'nameEn');
}

String displayServiceDescription(Map p) {
  if (previewDataEnabled && previewWords(p['descriptionAr']))
    return tr('حلاقة مرتبة وتصفيف يناسبك، مع عناية بكل التفاصيل.');
  return localizedContent(p, 'descriptionAr', 'descriptionEn');
}

String displayAreaName(Map p) {
  if (previewDataEnabled && previewWords(p['nameAr'])) return tr('الحي الأول');
  return localizedContent(p, 'nameAr', 'nameEn');
}

String displayCategory(Map p) {
  if (previewDataEnabled && previewWords(p['category']))
    return tr('عناية بالشعر');
  return localizedContent(p, 'category', 'categoryEn');
}

String displayCustomerName(Map b) {
  final value = localizedContent(b, 'customerName', 'customerNameEn');
  return previewDataEnabled ? fixtureText(value) : value;
}

String displayAddress(Map a, String field) =>
    localizedContent(a, field, '${field}En');
String paymentStatusLabel(Map p) {
  return tr(
    const {
          'PAID': 'مدفوع',
          'UNPAID': 'لسه ما اتدفعش',
          'PENDING_REVIEW': 'بانتظار المراجعة',
        }[p['status']] ??
        'غير مؤكد التحصيل',
  );
}

// Presentation-only copies. IDs, versions, prices, statuses and stored API data remain unchanged.
Map<String, dynamic> bookingForDisplay(
  Map<String, dynamic> raw, {
  required bool preview,
}) {
  if (!preview) return raw;
  final b = Map<String, dynamic>.from(raw);
  if (previewWords(b['customerName'])) b['customerName'] = 'James Parker';
  if (b['area'] is Map) {
    final area = Map<String, dynamic>.from(b['area']);
    if (previewWords(area['nameAr'])) {
      area['nameAr'] = 'الحي الأول';
      area['nameEn'] = 'District One';
    }
    b['area'] = area;
  }
  if (b['address'] is Map) {
    final address = Map<String, dynamic>.from(b['address']);
    if (previewWords(address['street'])) address['street'] = tr('شارع النخيل');
    if (previewWords(address['directions']))
      address['directions'] = tr('بجوار الحديقة');
    b['address'] = address;
  }
  if (b['assignedWorker'] is Map) {
    final worker = Map<String, dynamic>.from(b['assignedWorker']);
    if (previewWords(worker['name'])) worker['name'] = 'Daniel Reed';
    b['assignedWorker'] = worker;
  }
  return b;
}

class DemoBarberCard extends StatelessWidget {
  final Map<String, dynamic> barber;
  final bool saved;
  final VoidCallback onOpen, onSave;
  const DemoBarberCard({
    super.key,
    required this.barber,
    required this.saved,
    required this.onOpen,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      width: 182,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: royalSurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: royalLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 158,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  barber['image'],
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                Positioned(
                  top: 9,
                  left: 9,
                  child: GestureDetector(
                    onTap: onSave,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: royalBackground.withValues(alpha: .8),
                      child: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        size: 17,
                        color: royalGold,
                      ),
                    ),
                  ),
                ),
                Positioned(bottom: 8, right: 8, child: DemoBadge()),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fixtureText(barber['name']),
                  textDirection: appLocale.value.languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  fixtureText(barber['specialty']),
                  textDirection: appLocale.value.languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(fontSize: 10, color: royalMuted),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 13, color: royalGold),
                    SizedBox(width: 3),
                    Text(
                      tr('${barber['rating']}'),
                      style: TextStyle(fontSize: 9, color: royalGold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class DemoBarberPage extends StatelessWidget {
  final Map<String, dynamic> barber;
  final VoidCallback onServices;
  const DemoBarberPage({
    super.key,
    required this.barber,
    required this.onServices,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('ملف الحلاق'))),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580),
        child: ListView(
          padding: EdgeInsets.all(22),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Image.asset(
                barber['image'],
                height: 310,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            SizedBox(height: 17),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DemoBadge(text: 'ملف تجريبي · الصورة ليست لعامل في رايق'),
            ),
            SizedBox(height: 12),
            Text(
              fixtureText(barber['name']),
              textDirection: appLocale.value.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text(
              fixtureText(barber['specialty']),
              textDirection: appLocale.value.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: TextStyle(color: royalGold),
            ),
            SizedBox(height: 15),
            Row(
              children: [
                for (final item in [
                  ['${barber['rating']}', 'التقييم'],
                  ['${barber['reviews']}', 'مراجعات'],
                  ['${barber['years']}', 'سنوات خبرة'],
                ])
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.all(4),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: royalSurface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: royalLine),
                      ),
                      child: Column(
                        children: [
                          Text(
                            tr(item[0]),
                            style: TextStyle(color: royalGold, fontSize: 19),
                          ),
                          Text(
                            tr(item[1]),
                            style: TextStyle(fontSize: 8, color: royalMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              tr('عن الحلاق'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text(
              fixtureText(barber['bio']),
              textDirection: appLocale.value.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: TextStyle(color: royalMuted),
            ),
            SizedBox(height: 20),
            Text(
              tr('المراجعات'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: royalSurface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fixtureText(barber['reviewName']),
                    textDirection: appLocale.value.languageCode == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                  Text(tr('★★★★★'), style: TextStyle(color: royalGold)),
                  Text(
                    fixtureText(barber['review']),
                    textDirection: appLocale.value.languageCode == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: TextStyle(fontSize: 12, color: royalMuted),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              tr('الإدارة بتختار الحلاق المناسب لخدمتك وموعدك.'),
              style: TextStyle(fontSize: 11, color: royalMuted),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  onServices();
                },
                child: Text(tr('شوف الخدمات')),
              ),
            ),
            SizedBox(height: 25),
          ],
        ),
      ),
    ),
  );
}
