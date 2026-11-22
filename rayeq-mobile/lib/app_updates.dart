import 'localization.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'royal_theme.dart';

class UpdateInfo {
  final int latestBuild, minSupportedBuild;
  final String version, url, sha256, notes;
  final String notesEn;
  const UpdateInfo(
    this.latestBuild,
    this.minSupportedBuild,
    this.version,
    this.url,
    this.sha256,
    this.notes, [
    this.notesEn = '',
  ]);
  static UpdateInfo parse(Map<String, dynamic> data) {
    if (data['latestBuild'] is! int || data['minSupportedBuild'] is! int)
      throw FormatException('Invalid version');
    final latest = data['latestBuild'] as int,
        min = data['minSupportedBuild'] as int;
    if (latest < 1 || min < 1 || min > latest)
      throw FormatException('Invalid version range');
    return UpdateInfo(
      latest,
      min,
      '${data['latestVersion'] ?? ''}',
      '${data['apkUrl'] ?? ''}',
      '${data['sha256'] ?? ''}',
      '${data['releaseNotesAr'] ?? ''}',
      '${data['releaseNotesEn'] ?? ''}',
    );
  }

  bool get downloadable {
    final u = Uri.tryParse(url);
    return u?.scheme == 'https' &&
        u?.host == 'rayeq-platform.onrender.com' &&
        (u?.port == 443) &&
        (u?.userInfo.isEmpty ?? false) &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256);
  }
}

class AppUpdateGate extends StatefulWidget {
  final Widget child;
  const AppUpdateGate({super.key, required this.child});
  @override
  AppUpdateGateState createState() => AppUpdateGateState();
}

class AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  static final system = MethodChannel('rayeq/app_updates');
  final api = RayeqApi();
  bool checking = false, showing = false;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    api.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> check({bool manual = false}) async {
    if (!supported || checking || showing || !api.configured) return;
    checking = true;
    try {
      final installed = (await system.invokeMethod<num>('installedBuild'))!
          .toInt();
      final info = UpdateInfo.parse(await api.getMap('app/version'));
      if (!mounted) return;
      if (info.latestBuild <= installed) {
        if (manual)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('أنت على أحدث نسخة متاحة.'))),
          );
        return;
      }
      if (!info.downloadable && installed >= info.minSupportedBuild) {
        if (manual)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('رابط التحديث مش جاهز حاليًا. جرّب لاحقًا.')),
            ),
          );
        return;
      }
      showing = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: installed >= info.minSupportedBuild,
        builder: (_) => UpdateDialog(
          info: info,
          requiredUpdate: installed < info.minSupportedBuild,
        ),
      );
    } catch (_) {
      if (manual && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('تعذر التحقق من التحديثات. اتأكد من الإنترنت وجرّب تاني.'),
            ),
          ),
        );
    } finally {
      checking = false;
      showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final bool requiredUpdate;
  const UpdateDialog({
    super.key,
    required this.info,
    required this.requiredUpdate,
  });
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool busy = false;
  String? path;
  String error = '', status = '';
  late UpdateInfo info;
  @override
  void initState() {
    super.initState();
    info = widget.info;
  }

  Future<void> update() async {
    setState(() {
      busy = true;
      error = '';
      status = path == null
          ? 'جاري تنزيل التحديث والتحقق من سلامته…'
          : 'جاري فتح مثبت أندرويد…';
    });
    try {
      if (!info.downloadable) {
        final client = RayeqApi();
        try {
          info = UpdateInfo.parse(await client.getMap('app/version'));
        } finally {
          client.close();
        }
        if (!info.downloadable) throw FormatException('Update not ready');
      }
      path ??= await AppUpdateGateState.system.invokeMethod<String>(
        'downloadUpdate',
        {'url': info.url, 'sha256': info.sha256, 'build': info.latestBuild},
      );
      if (path == null) throw FormatException('No package');
      final result = await AppUpdateGateState.system.invokeMethod<String>(
        'installUpdate',
        {'path': path, 'sha256': info.sha256, 'build': info.latestBuild},
      );
      if (!mounted) return;
      setState(
        () => status = result == 'permission_required'
            ? 'فعّل السماح بالتثبيت من رايق في إعدادات أندرويد، وارجع اضغط متابعة التثبيت.'
            : 'كمّل التأكيد من شاشة أندرويد. بيانات حسابك هتفضل موجودة بعد التحديث.',
      );
    } on PlatformException catch (e) {
      if (mounted)
        setState(() {
          if (e.code == 'UPDATE_VERIFICATION_FAILED' ||
              e.code == 'UPDATE_DOWNLOAD_FAILED')
            path = null;
          error = 'التحديث مكملش أو التحقق من الملف فشل. مفيش ملف غير موثوق اتفتح. جرّب تاني.';
          status = '';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'تعذر تنزيل التحديث أو فتح المثبت. جرّب تاني.';
          status = '';
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.requiredUpdate && !busy,
    child: AlertDialog(
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actionsOverflowButtonSpacing: 8,
      buttonPadding: const EdgeInsetsDirectional.only(start: 8),
      icon: Icon(Icons.system_update_alt, color: royalGold, size: 42),
      title: Text(
        tr(widget.requiredUpdate ? 'التحديث مطلوب' : 'نسخة جديدة من رايق'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('الإصدار ${info.version}'),
              style: TextStyle(color: royalGold, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              appLocale.value.languageCode == 'en'
                  ? (info.notesEn.isEmpty
                        ? tr('تحسينات وتحديثات للتطبيق.')
                        : info.notesEn)
                  : (info.notes.isEmpty
                        ? 'تحسينات وتحديثات للتطبيق.'
                        : info.notes),
            ),
            SizedBox(height: 14),
            Text(
              tr(
                widget.requiredUpdate
                    ? 'لازم تحدّث النسخة عشان تكمل استخدام التطبيق.'
                    : 'نزّل التحديث من داخل التطبيق. أندرويد هيطلب منك تأكيد التثبيت.',
              ),
              style: TextStyle(fontSize: 12, color: royalMuted),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(tr(status), style: TextStyle(fontSize: 12)),
              ),
            if (busy) ...[SizedBox(height: 16), LinearProgressIndicator()],
            if (error.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  tr(error),
                  style: TextStyle(color: Color(0xffffb4ab), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!widget.requiredUpdate)
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(tr('مش دلوقتي')),
          ),
        FilledButton(
          onPressed: busy ? null : update,
          child: Text(
            tr(
              busy
                  ? 'جاري التحديث…'
                  : path == null
                  ? 'تنزيل وتثبيت التحديث'
                  : 'متابعة التثبيت',
            ),
          ),
        ),
      ],
    ),
  );
}
