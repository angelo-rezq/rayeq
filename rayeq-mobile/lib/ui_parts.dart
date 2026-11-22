import 'barber_profiles.dart';
import 'nearby.dart' show nearbyText;
import 'localization.dart';
import 'demo_data.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';

String bookingStatus(dynamic s) =>
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
String cairoDate(dynamic raw) {
  if (raw == null) return 'في أقرب وقت، بعد تأكيد الإدارة';
  try {
    return '${DateFormat('yyyy/MM/dd • HH:mm', appLocale.value.languageCode).format(tz.TZDateTime.from(DateTime.parse('$raw'), tz.getLocation('Africa/Cairo')))} بتوقيت القاهرة';
  } catch (_) {
    return 'الموعد يتأكد مع الإدارة';
  }
}

String egp(dynamic n) => '${((n as num? ?? 0) / 100).toStringAsFixed(2)} ج.م';

class RoyalNotice extends StatelessWidget {
  final String message;
  final bool error;
  const RoyalNotice({super.key, required this.message, this.error = false});
  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xffffb4ab) : const Color(0xffe7c35b);
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              tr(message),
              style: TextStyle(color: color, fontSize: 12, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceArt extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double height;
  const ServiceArt({
    super.key,
    required this.name,
    this.imageUrl,
    this.height = 165,
  });
  @override
  Widget build(BuildContext context) {
    final asset = name.contains('ذقن') || name.toLowerCase().contains('beard')
        ? 'beard'
        : name.contains('كامل') || name.contains('باق')
        ? 'ritual'
        : 'hair';
    final local = Image.asset(
      'assets/images/service-$asset.webp',
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
    final u = Uri.tryParse(imageUrl ?? '');
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: u?.scheme == 'https'
          ? Image.network(
              imageUrl!,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => local,
            )
          : local,
    );
  }
}

class AccountProfile extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool employee;
  final VoidCallback onPassword, onLogout;
  final VoidCallback? onEdit;
  const AccountProfile({
    super.key,
    required this.user,
    required this.employee,
    required this.onPassword,
    required this.onLogout,
    this.onEdit,
  });
  Widget section(Widget child) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 18),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Color(0xff1e1e24),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Color(0xff3c3c44)),
    ),
    child: child,
  );
  Widget row(IconData icon, String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Color(0xffe7c35b)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(label),
                style: TextStyle(fontSize: 12, color: Color(0xffb8b8bf)),
              ),
              Text(tr(value), style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final displayName = '${user['name'] ?? ''}';
    final image = user['avatarUrl'] as String?;
    final imageUri = Uri.tryParse(image ?? '');
    final role = '${user['role']}';
    final pending = role == 'worker_pending';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('الملف الشخصي'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        SizedBox(height: 6),
        Text(
          tr(
            employee
                ? 'حسابك ومساحة شغلك في مكان واحد.'
                : 'تفاصيلك، على راحتك.',
          ),
          style: TextStyle(color: Color(0xffb8b8bf)),
        ),
        section(
          Column(
            children: [
              CircleAvatar(
                radius: 43,
                backgroundColor: Color(0xff403927),
                backgroundImage: imageUri?.scheme == 'https'
                    ? NetworkImage(image!)
                    : null,
                child: imageUri?.scheme == 'https'
                    ? null
                    : Text(
                        tr(
                          displayName.isEmpty
                              ? 'ر'
                              : displayName.characters.first,
                        ),
                        style: TextStyle(
                          fontSize: 35,
                          color: Color(0xffe7c35b),
                        ),
                      ),
              ),
              SizedBox(height: 13),
              Text(
                tr(displayName),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 5),
              Text(
                tr(employee ? 'فريق رايق' : 'عميل رايق'),
                style: TextStyle(color: Color(0xffe7c35b)),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 17),
                  label: Text(tr('تعديل الملف الشخصي')),
                ),
            ],
          ),
        ),
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('بيانات الحساب'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              row(Icons.person_outline, 'الاسم', displayName),
              Divider(),
              row(
                Icons.mail_outline,
                'البريد الإلكتروني',
                '${user['email'] ?? ''}',
              ),
              Divider(),
              row(
                Icons.verified_user_outlined,
                'حالة البريد',
                user['emailVerified'] == true
                    ? 'مفعّل'
                    : user['isDemo'] == true
                    ? 'حساب تجربة'
                    : 'غير مفعّل',
              ),
              if (employee) ...[
                Divider(),
                row(
                  Icons.badge_outlined,
                  'حالة الانضمام',
                  pending
                      ? 'في انتظار موافقة الإدارة'
                      : role == 'worker'
                      ? 'حلاق معتمد'
                      : 'غير معتمد',
                ),
              ],
            ],
          ),
        ),
        if (employee)
          section(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('مساحة العمل'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 10),
                Text(
                  tr(
                    'الزيارات بتتسند ليك من الإدارة. بيانات العملاء متاحة للزيارات المسندة ليك فقط.',
                  ),
                ),
                if (user['skills'] is List)
                  row(
                    Icons.content_cut,
                    'المهارات',
                    (user['skills'] as List).join('، '),
                  ),
                if (user['areas'] is List)
                  row(
                    Icons.location_on_outlined,
                    'مناطق العمل',
                    (user['areas'] as List).join('، '),
                  ),
              ],
            ),
          ),
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('الأمان'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: onPassword,
                icon: Icon(Icons.lock_reset_outlined),
                label: Text(tr('استعادة أو تغيير كلمة المرور')),
              ),
              Text(
                tr(
                  'رقم الموبايل بيتطلب وقت الحجز للتواصل فقط، ومش بديل لتفعيل الإيميل.',
                ),
                style: TextStyle(fontSize: 12, color: Color(0xffb8b8bf)),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: Icon(Icons.logout),
            label: Text(tr('تسجيل الخروج')),
          ),
        ),
        SizedBox(height: 18),
        Center(
          child: Text(
            tr('رايق · حلاقك عندك'),
            style: TextStyle(color: Color(0xffb8b8bf), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class BookingDetails extends StatefulWidget {
  final RayeqApi api;
  final String id;
  final bool employee, preview;
  const BookingDetails({
    super.key,
    required this.api,
    required this.id,
    this.employee = false,
    this.preview = false,
  });
  @override
  State<BookingDetails> createState() => _BookingDetailsState();
}

class _BookingDetailsState extends State<BookingDetails> {
  late Future<Map<String, dynamic>> detail;
  @override
  void initState() {
    super.initState();
    detail = widget.api.getMap('bookings/${Uri.encodeComponent(widget.id)}');
  }

  Widget card(Widget child) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20),
    margin: EdgeInsets.only(top: 16),
    decoration: BoxDecoration(
      color: Color(0xff1e1e24),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Color(0xff3c3c44)),
    ),
    child: child,
  );
  Widget item(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            tr(label),
            style: TextStyle(color: Color(0xffb8b8bf), fontSize: 12),
          ),
        ),
        SizedBox(width: 14),
        Flexible(
          flex: 2,
          child: Text(
            tr(value),
            textAlign: TextAlign.end,
            textDirection: value.startsWith('+') ? TextDirection.ltr : null,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('تفاصيل الزيارة'))),
    body: FutureBuilder<Map<String, dynamic>>(
      future: detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(
                      snapshot.error is ApiFailure
                          ? (snapshot.error as ApiFailure).message
                          : 'تعذر تحميل تفاصيل الزيارة.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => detail = widget.api.getMap(
                        'bookings/${Uri.encodeComponent(widget.id)}',
                      ),
                    ),
                    child: Text(tr('جرّب تاني')),
                  ),
                ],
              ),
            ),
          );
        }
        final b = bookingForDisplay(snapshot.data!, preview: widget.preview),
            service = b['service'] as Map? ?? {},
            address = b['address'] as Map? ?? {},
            price = b['price'] as Map? ?? {},
            payment = b['payment'] as Map? ?? {};
        final history = b['history'] as List? ?? [];
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 580),
            child: ListView(
              padding: EdgeInsets.all(24),
              children: [
                Text(
                  tr(displayServiceName(service)),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 14),
                ServiceArt(
                  name: displayServiceName(service),
                  imageUrl: service['imageUrl'] as String?,
                ),

                card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(bookingStatus(b['status'])),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      item('رقم الطلب', '${b['reference'] ?? ''}'),
                      item('الموعد المطلوب', cairoDate(b['requestedAt'])),
                      item(
                        'المدة',
                        '${service['durationMinutes'] ?? '-'} دقيقة',
                      ),
                      if (b['assignedWorker'] != null)
                        item(
                          'الحلاق',
                          localizedContent(
                            b['assignedWorker'] as Map,
                            'name',
                            'nameEn',
                          ),
                        ),
                    ],
                  ),
                ),
                if (!widget.employee &&
                    b['status'] == 'COMPLETED' &&
                    b['canReview'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.star_outline_rounded),
                      label: Text(nearbyText('قيّم زيارتك', 'Rate your visit')),
                      onPressed: () async {
                        final done = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewComposer(
                              maxCommentLength: 1000,
                              onSubmit: (stars, text) async {
                                await widget.api.post(
                                  'bookings/${Uri.encodeComponent(widget.id)}/review',
                                  {
                                    'rating': stars,
                                    if (text.isNotEmpty) 'text': text,
                                  },
                                );
                              },
                            ),
                          ),
                        );
                        if (done == true && mounted)
                          setState(
                            () => detail = widget.api.getMap(
                              'bookings/${Uri.encodeComponent(widget.id)}',
                            ),
                          );
                      },
                    ),
                  ),
                card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('تفاصيل المكان والتواصل'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      item('العميل', displayCustomerName(b)),
                      item('الموبايل', '${b['contactPhone'] ?? ''}'),
                      item(
                        'المكان',
                        b['locationType'] == 'work' ? 'في الشغل' : 'في البيت',
                      ),
                      item('المنطقة', displayAreaName(b['area'] as Map? ?? {})),
                      item(
                        'العنوان',
                        '${displayAddress(address, 'street')}, ${address['building'] ?? ''}',
                      ),
                      item(
                        'الدور / الشقة',
                        '${address['floor'] ?? '-'} / ${address['apartment'] ?? '-'}',
                      ),
                      if ('${address['workplaceName'] ?? ''}'.isNotEmpty)
                        item('جهة العمل', '${address['workplaceName']}'),
                      if ('${address['directions'] ?? ''}'.isNotEmpty)
                        item(
                          'علامة مميزة',
                          displayAddress(address, 'directions'),
                        ),
                    ],
                  ),
                ),
                card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('تفاصيل الحساب'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      item('الخدمة', egp(price['serviceMinor'])),
                      item('الانتقال', egp(price['travelMinor'])),
                      if ((price['discountMinor'] as num? ?? 0) > 0)
                        item('خصم', egp(price['discountMinor'])),
                      Divider(),
                      item('الإجمالي', egp(price['totalMinor'])),
                      item(
                        'طريقة الدفع',
                        payment['method'] == 'instapay'
                            ? 'إنستا باي للشركة'
                            : 'كاش',
                      ),
                      item('حالة الدفع', paymentStatusLabel(payment)),
                      Text(
                        tr('حالة الزيارة منفصلة عن حالة تحصيل الدفع.'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xffb8b8bf),
                        ),
                      ),
                    ],
                  ),
                ),
                card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('متابعة الطلب'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      if (history.isEmpty) Text(tr('مفيش تحديثات إضافية.')),
                      for (final h in history)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Color(0xffe7c35b),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr(bookingStatus(h['status']))),
                                    Text(
                                      tr(cairoDate(h['at'])),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xffb8b8bf),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    ),
  );
}
