import 'about.dart';
import 'localization.dart';
import 'demo_data.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'app_updates.dart';

import 'package:flutter/foundation.dart';

import 'royal_theme.dart';

class ProfilePanel extends StatefulWidget {
  final RayeqApi api;
  final Map<String, dynamic> initialUser;
  final VoidCallback onPassword, onLogout;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const ProfilePanel({
    super.key,
    required this.api,
    required this.initialUser,
    required this.onPassword,
    required this.onLogout,
    required this.onChanged,
  });
  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  late Map<String, dynamic> profile;
  Uint8List? avatar;
  bool busy = false, ready = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    profile = Map.from(widget.initialUser);
    load();
  }

  Map<String, dynamic> normalize(Map<String, dynamic> d) =>
      d['user'] is Map ? Map<String, dynamic>.from(d['user']) : d;
  Future<void> load() async {
    setState(() => busy = true);
    try {
      final p = normalize(await widget.api.getMap('profile'));
      Uint8List? image;
      if (p['avatarUrl'] != null || p['hasAvatar'] == true) {
        image = await widget.api.getAvatar();
      }
      if (!mounted) return;
      setState(() {
        profile = {...profile, ...p};
        avatar = image;
        ready = true;
        error = '';
      });
      widget.onChanged(profile);
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(
          () => error = e.status == 404
              ? 'تعديل الحساب قيد التجهيز. بيانات حسابك الحالية ظاهرة هنا.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل كل بيانات الحساب.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    final name = TextEditingController(text: displayProfileName(profile)),
        phone = TextEditingController(text: '${profile['phone'] ?? ''}');
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsAlignment: MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsOverflowButtonSpacing: 8,
        buttonPadding: const EdgeInsetsDirectional.only(start: 8),
        title: Text(tr('تعديل بياناتك')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 100,
                decoration: InputDecoration(labelText: tr('الاسم')),
              ),
              SizedBox(height: 16),
              TextField(
                controller: phone,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: tr('موبايل للتواصل (اختياري)'),
                ),
              ),
              SizedBox(height: 12),
              Text(
                tr('الإيميل ونوع الحساب مش قابلين للتغيير هنا.'),
                style: TextStyle(fontSize: 11, color: royalMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('رجوع')),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'name': name.text.trim(),
                  'phone': phone.text.trim(),
                });
              }
            },
            child: Text(tr('حفظ')),
          ),
        ],
      ),
    );
    // Text controllers stay alive until the dialog transition has finished.
    if (payload == null || !mounted) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.api.patch('profile', payload);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('اتحفظت بياناتك.'))));
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ التغييرات.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? mime(Uint8List b) {
    if (b.length > 3 && b[0] == 255 && b[1] == 216) return 'image/jpeg';
    if (b.length > 8 && b[0] == 137 && b[1] == 80 && b[2] == 78 && b[3] == 71) {
      return 'image/png';
    }
    if (b.length > 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Future<void> changePhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes(), type = mime(bytes);
      if (type == null) {
        throw ApiFailure('INVALID_IMAGE', 'اختار صورة JPEG أو PNG أو WebP.');
      }
      setState(() {
        busy = true;
        error = '';
      });
      await widget.api.uploadAvatar(bytes, type);
      await load();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر فتح أو حفظ الصورة. جرّب صورة تانية.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removePhoto() async {
    setState(() => busy = true);
    try {
      await widget.api.deleteAvatar();
      await load();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget card(Widget child) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 17),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: royalSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: royalLine),
    ),
    child: child,
  );
  Widget info(IconData icon, String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: royalGold),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(label),
                style: TextStyle(color: royalMuted, fontSize: 11),
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
    final role = profile['role'],
        employee = role == 'worker' || role == 'worker_pending';
    final name = displayProfileName(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('الملف الشخصي'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        Text(
          tr('حسابك وتفاصيلك، في مكان واحد.'),
          style: TextStyle(color: royalMuted),
        ),
        if (busy) LinearProgressIndicator(),
        if (error.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(tr(error), style: TextStyle(color: Color(0xffffbe9d))),
          ),
        card(
          Column(
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: royalGold.withValues(alpha: .6)),
                ),
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: royalRaised,
                  backgroundImage: avatar == null ? null : MemoryImage(avatar!),
                  child: avatar != null
                      ? null
                      : Text(
                          tr(name.isEmpty ? 'ر' : name.characters.first),
                          style: TextStyle(fontSize: 35, color: royalGold),
                        ),
                ),
              ),
              SizedBox(height: 13),
              Text(tr(name), style: Theme.of(context).textTheme.titleLarge),
              Text(
                tr(employee ? 'فريق رايق' : 'عميل رايق'),
                style: TextStyle(color: royalGold, fontSize: 12),
              ),
              if (ready)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : changePhoto,
                      icon: Icon(Icons.add_a_photo_outlined, size: 17),
                      label: Text(tr('تغيير الصورة')),
                    ),
                    if (avatar != null)
                      TextButton(
                        onPressed: busy ? null : removePhoto,
                        child: Text(tr('حذف الصورة')),
                      ),
                  ],
                ),
            ],
          ),
        ),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('بيانات الحساب'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (ready)
                    IconButton(
                      tooltip: tr('تعديل بياناتك'),
                      onPressed: busy ? null : edit,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 19,
                        color: royalGold,
                      ),
                    ),
                ],
              ),
              info(Icons.person_outline, 'الاسم', name),
              Divider(),
              info(
                Icons.mail_outline,
                'البريد الإلكتروني',
                '${profile['email'] ?? ''}',
              ),
              Divider(),
              info(
                Icons.phone_outlined,
                'موبايل التواصل',
                '${profile['phone'] ?? ''}'.isEmpty
                    ? 'غير مضاف'
                    : profile['phone'].toString(),
              ),
              Divider(),
              info(
                Icons.verified_user_outlined,
                'حالة البريد',
                profile['emailVerified'] == true ? 'مفعّل' : 'غير مفعّل',
              ),
              if (employee) ...[
                Divider(),
                info(
                  Icons.badge_outlined,
                  'حالة الانضمام',
                  role == 'worker' ? 'حلاق معتمد' : 'في انتظار موافقة الإدارة',
                ),
              ],
            ],
          ),
        ),
        if (employee)
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('مساحة العمل'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                Text(
                  tr(
                    'الإدارة بتسند الزيارات ليك. بيانات العملاء متاحة لمهامك فقط، وإكمال الزيارة مش تأكيد لتحصيل الدفع.',
                  ),
                  style: TextStyle(color: royalMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('الأمان'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                TextButton.icon(
                  onPressed: () => context
                      .findAncestorStateOfType<AppUpdateGateState>()
                      ?.check(manual: true),
                  icon: Icon(Icons.system_update_outlined),
                  label: Text(tr('التحقق من التحديثات')),
                ),
              TextButton.icon(
                onPressed: widget.onPassword,
                icon: Icon(Icons.lock_reset_outlined),
                label: Text(tr('استعادة أو تغيير كلمة المرور')),
              ),
              Text(
                tr('رقم الموبايل للتواصل فقط، ومش بديل لتفعيل الإيميل.'),
                style: TextStyle(color: royalMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        card(
          Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: royalGold,
                ),
                title: Text(tr('عن رايق')),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutRayeq())),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined, color: royalGold),
                title: Text(tr('سياسة الخصوصية')),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicy()),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : widget.onLogout,
            icon: Icon(Icons.logout),
            label: Text(tr('تسجيل الخروج')),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
