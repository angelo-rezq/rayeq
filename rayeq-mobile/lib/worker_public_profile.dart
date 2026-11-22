import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'barber_profiles.dart';
import 'localization.dart';
import 'nearby.dart';
import 'royal_theme.dart';

class WorkerPublicProfileCard extends StatelessWidget {
  final RayeqApi api;
  const WorkerPublicProfileCard({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        nearbyText('ملفك عند العملاء', 'Your customer-facing profile'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        nearbyText(
          'اكتب نبذة عنك وأضف صورتك وخبرتك وتخصصاتك اللي تظهر للعملاء.',
          'Write a bio and add the portrait, experience and specialties customers can see.',
        ),
        style: const TextStyle(color: royalMuted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerPublicProfileEditor(api: api),
          ),
        ),
        icon: const Icon(Icons.badge_outlined),
        label: Text(nearbyText('تعديل الملف العام', 'Edit public profile')),
      ),
    ],
  );
}

class WorkerPublicProfileEditor extends StatefulWidget {
  final RayeqApi api;
  const WorkerPublicProfileEditor({super.key, required this.api});
  @override
  State<WorkerPublicProfileEditor> createState() =>
      _WorkerPublicProfileEditorState();
}

class _WorkerPublicProfileEditorState extends State<WorkerPublicProfileEditor> {
  final form = GlobalKey<FormState>();
  final titleAr = TextEditingController(),
      titleEn = TextEditingController(),
      bioAr = TextEditingController(),
      bioEn = TextEditingController(),
      specialtiesAr = TextEditingController(),
      specialtiesEn = TextEditingController(),
      years = TextEditingController();
  Map<String, dynamic>? data;
  bool busy = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [
      titleAr,
      titleEn,
      bioAr,
      bioEn,
      specialtiesAr,
      specialtiesEn,
      years,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final value = await widget.api.getMap('worker/public-profile');
      if (!mounted) return;
      setState(() {
        data = value;
        titleAr.text = '${value['titleAr'] ?? ''}';
        titleEn.text = '${value['titleEn'] ?? ''}';
        bioAr.text = '${value['bioAr'] ?? ''}';
        bioEn.text = '${value['bioEn'] ?? ''}';
        specialtiesAr.text = (value['specialtiesAr'] as List? ?? []).join('\n');
        specialtiesEn.text = (value['specialtiesEn'] as List? ?? []).join('\n');
        years.text = '${value['yearsExperience'] ?? ''}';
      });
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is ApiFailure
              ? tr(e.message)
              : nearbyText('تعذر تحميل الملف.', 'Could not load your profile.'),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> lines(TextEditingController c) => c.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is ApiFailure
              ? tr(e.message)
              : nearbyText(
                  'الخطوة مكملتش. جرّب تاني.',
                  'Could not complete this action. Try again.',
                ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    await action(() async {
      final saved = await widget.api.patch('worker/public-profile', {
        'titleAr': titleAr.text.trim(),
        'titleEn': titleEn.text.trim(),
        'bioAr': bioAr.text.trim(),
        'bioEn': bioEn.text.trim(),
        'specialtiesAr': lines(specialtiesAr),
        'specialtiesEn': lines(specialtiesEn),
        'yearsExperience': int.tryParse(years.text.trim()),
      });
      if (!mounted) return;
      setState(() => data = {...?data, ...saved});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nearbyText('اتحفظ ملفك العام.', 'Public profile saved.'),
          ),
        ),
      );
    });
  }

  String mime(Uint8List b) {
    if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255)
      return 'image/jpeg';
    if (b.length >= 4 && b[0] == 137 && b[1] == 80 && b[2] == 78 && b[3] == 71)
      return 'image/png';
    if (b.length >= 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP')
      return 'image/webp';
    throw ApiFailure(
      'PHOTO_FORMAT',
      nearbyText(
        'اختار صورة JPEG أو PNG أو WebP.',
        'Choose a JPEG, PNG or WebP photo.',
      ),
    );
  }

  Future<void> portrait() async {
    await action(() async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024)
        throw ApiFailure(
          'PHOTO_TOO_LARGE',
          nearbyText('أقصى حجم ٥ ميجا.', 'Maximum size is 5 MB.'),
        );
      final bytes = await file.readAsBytes();
      final result = await widget.api.uploadPublicPortrait(bytes, mime(bytes));
      final old = '${data?['portraitUrl'] ?? ''}';
      if (old.isNotEmpty) await NetworkImage(old).evict();
      if (mounted) setState(() => data = {...?data, ...result});
    });
  }

  Future<void> removePortrait() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          nearbyText('تحذف صورتك العامة؟', 'Delete your public portrait?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(nearbyText('رجوع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nearbyText('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await action(() async {
      await widget.api.request('DELETE', 'worker/public-profile/portrait');
      final old = '${data?['portraitUrl'] ?? ''}';
      if (old.isNotEmpty) await NetworkImage(old).evict();
      if (mounted) setState(() => data = {...?data, 'portraitUrl': null});
    });
  }

  Widget input(
    TextEditingController c,
    String ar,
    String en, {
    bool arabic = false,
    int max = 80,
    int rows = 1,
    bool list = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      minLines: rows,
      maxLines: rows,
      maxLength: list ? null : max,
      decoration: InputDecoration(
        labelText: nearbyText(ar, en),
        alignLabelWithHint: true,
      ),
      validator: list
          ? (_) => lines(c).length > 12 || lines(c).any((s) => s.length > 80)
                ? nearbyText(
                    'حد أقصى ١٢ تخصص، وكل تخصص ٨٠ حرف.',
                    'At most 12 specialties, 80 characters each.',
                  )
                : null
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(nearbyText('ملفك العام', 'Your public profile')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                nearbyText(
                  'المعلومات دي بتظهر للعملاء. متكتبش عنوانك الخاص أو بيانات تواصل شخصية.',
                  'Customers can see these details. Do not add a private address or personal contact information.',
                ),
                style: const TextStyle(color: royalMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Color(0xffffb4ab)),
                  ),
                ),
              if (data == null && !loading)
                OutlinedButton(
                  onPressed: load,
                  child: Text(nearbyText('جرّب تاني', 'Try again')),
                ),
              if (data != null)
                AbsorbPointer(
                  absorbing: busy,
                  child: Form(
                    key: form,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: 230,
                            width: double.infinity,
                            child: BarberCoverImage(barber: data!),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: portrait,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: Text(
                                nearbyText(
                                  'اختار صورة عامة',
                                  'Choose a public portrait',
                                ),
                              ),
                            ),
                            if ('${data?['portraitUrl'] ?? ''}'.isNotEmpty)
                              TextButton(
                                onPressed: removePortrait,
                                child: Text(
                                  nearbyText('حذف الصورة', 'Delete portrait'),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            nearbyText(
                              'عرّف العملاء بنفسك',
                              'Tell customers about yourself',
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 16),
                        input(
                          bioAr,
                          'نبذة بالعربي',
                          'Bio in Arabic',
                          arabic: true,
                          max: 1500,
                          rows: 4,
                        ),
                        input(
                          bioEn,
                          'نبذة بالإنجليزي',
                          'Bio in English',
                          max: 1500,
                          rows: 4,
                        ),
                        input(
                          titleAr,
                          'المسمى بالعربي',
                          'Title in Arabic',
                          arabic: true,
                        ),
                        input(titleEn, 'المسمى بالإنجليزي', 'Title in English'),
                        TextFormField(
                          controller: years,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: nearbyText(
                              'سنوات الخبرة، اختياري',
                              'Years of experience, optional',
                            ),
                          ),
                          validator: (s) {
                            if (s == null || s.trim().isEmpty) return null;
                            final n = int.tryParse(s);
                            return n == null || n < 0 || n > 80
                                ? nearbyText(
                                    'من صفر لـ٨٠ سنة.',
                                    'Use a number from 0 to 80.',
                                  )
                                : null;
                          },
                        ),
                        const SizedBox(height: 20),
                        input(
                          specialtiesAr,
                          'التخصصات بالعربي، كل تخصص في سطر',
                          'Arabic specialties, one per line',
                          arabic: true,
                          rows: 3,
                          list: true,
                        ),
                        input(
                          specialtiesEn,
                          'التخصصات بالإنجليزي، كل تخصص في سطر',
                          'English specialties, one per line',
                          rows: 3,
                          list: true,
                        ),
                        Text(
                          nearbyText(
                            'الخدمات والأسعار ومناطق التغطية بتحددها الإدارة.',
                            'The team manages services, prices and service coverage.',
                          ),
                          style: const TextStyle(
                            color: royalMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (busy) const LinearProgressIndicator(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: busy ? null : save,
                            child: Text(
                              nearbyText(
                                'حفظ الملف العام',
                                'Save public profile',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
