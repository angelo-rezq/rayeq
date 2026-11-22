import 'brand.dart';

import 'dart:async';

import 'localization.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'royal_theme.dart';

class UpdateInfo {
  final int latestBuild, minSupportedBuild;
  final String version, url, sha256, notes, notesEn;
  final DateTime? publishedAt, mandatoryAfter, serverTime;
  const UpdateInfo(
    this.latestBuild,
    this.minSupportedBuild,
    this.version,
    this.url,
    this.sha256,
    this.notes, [
    this.notesEn = '',
    this.publishedAt,
    this.mandatoryAfter,
    this.serverTime,
  ]);

  static DateTime? _timestamp(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
        ).hasMatch(value)) {
      throw const FormatException(
        'Expected an ISO-8601 timestamp with timezone',
      );
    }
    final result = DateTime.tryParse(value);
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    final wallDate = DateTime.utc(year, month, day);
    if (result == null ||
        wallDate.year != year ||
        wallDate.month != month ||
        wallDate.day != day ||
        int.parse(value.substring(11, 13)) > 23 ||
        int.parse(value.substring(14, 16)) > 59 ||
        int.parse(value.substring(17, 19)) > 59) {
      throw const FormatException('Invalid release timestamp');
    }
    return result.toUtc();
  }

  static UpdateInfo parse(Map<String, dynamic> data) {
    if (data['latestBuild'] is! int || data['minSupportedBuild'] is! int) {
      throw const FormatException('Invalid version');
    }
    final latest = data['latestBuild'] as int;
    final min = data['minSupportedBuild'] as int;
    if (latest < 1 || min < 1 || min > latest) {
      throw const FormatException('Invalid version range');
    }
    final published = _timestamp(data['publishedAt']);
    final mandatory = _timestamp(data['mandatoryAfter']);
    if (published != null &&
        mandatory != null &&
        mandatory.difference(published) != const Duration(hours: 48)) {
      throw const FormatException('Release grace must be 48 hours');
    }
    return UpdateInfo(
      latest,
      min,
      '${data['latestVersion'] ?? ''}',
      '${data['apkUrl'] ?? ''}',
      '${data['sha256'] ?? ''}',
      '${data['releaseNotesAr'] ?? ''}',
      '${data['releaseNotesEn'] ?? ''}',
      published,
      mandatory,
      _timestamp(data['serverTime']),
    );
  }

  bool get downloadable {
    final u = Uri.tryParse(url);
    return u?.scheme == 'https' &&
        {
          'rayeq-platform.onrender.com',
          const String.fromEnvironment('UPDATE_DOWNLOAD_HOST'),
        }.contains(u?.host) &&
        (u?.port == 443) &&
        (u?.userInfo.isEmpty ?? false) &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256);
  }

  DateTime? get enforcementAt =>
      mandatoryAfter ?? publishedAt?.add(const Duration(hours: 48));
  Duration? remainingGrace({DateTime? now}) =>
      enforcementAt?.difference(serverTime ?? (now ?? DateTime.now()).toUtc());
  bool isRequiredFor(int installed, {DateTime? now}) =>
      latestBuild > installed &&
      downloadable &&
      enforcementAt != null &&
      !(serverTime ?? (now ?? DateTime.now()).toUtc()).isBefore(enforcementAt!);
}

class AppUpdateGate extends StatefulWidget {
  final Widget child;
  final RayeqApi? api;
  const AppUpdateGate({super.key, required this.child, this.api});
  @override
  AppUpdateGateState createState() => AppUpdateGateState();
}

class AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  static const system = MethodChannel('rayeq/app_updates');
  late final RayeqApi api;
  Timer? policyTimer, startupWaitTimer, retryTimer;
  int automaticRetries = 0;
  bool checking = false, showing = false, initialCheckComplete = false;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? RayeqApi();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    policyTimer?.cancel();
    startupWaitTimer?.cancel();
    retryTimer?.cancel();
    api.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<UpdateInfo> fetchInfo() async => UpdateInfo.parse(
    await api.getMap('app/version').timeout(const Duration(seconds: 125)),
  );

  Future<void> check({bool manual = false}) async {
    if (!supported || checking || showing || !api.configured) return;
    checking = true;
    retryTimer?.cancel();
    if (!initialCheckComplete) {
      startupWaitTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && checking && !showing)
          setState(() => initialCheckComplete = true);
      });
    }
    try {
      final installed =
          (await system
                  .invokeMethod<num>('installedBuild')
                  .timeout(const Duration(seconds: 3)))!
              .toInt();
      final info = await fetchInfo();
      automaticRetries = 0;
      if (!mounted) return;
      policyTimer?.cancel();
      if (info.latestBuild <= installed) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('أنت على أحدث نسخة متاحة.'))),
          );
        }
        return;
      }
      // An unusable or incomplete release must never strand an installed app.
      if (!info.downloadable) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('رابط التحديث مش جاهز حاليًا. جرّب لاحقًا.')),
            ),
          );
        }
        return;
      }
      final remaining = info.remainingGrace();
      if (remaining != null && remaining > Duration.zero) {
        policyTimer = Timer(remaining, () => check());
      }
      setState(() => showing = true);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(
          info: info,
          installedBuild: installed,
          requiredUpdate: info.isRequiredFor(installed),
          graceRemaining: remaining,
          fetchLatest: fetchInfo,
        ),
      );
    } catch (_) {
      // No cached forced gate: a failed live check always lets the app open.
      if (mounted && !manual && automaticRetries < 2) {
        automaticRetries++;
        retryTimer = Timer(const Duration(minutes: 1), () => check());
      }
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('تعذر التحقق من التحديثات. اتأكد من الإنترنت وجرّب تاني.'),
            ),
          ),
        );
      }
    } finally {
      startupWaitTimer?.cancel();
      if (mounted) {
        setState(() {
          checking = false;
          showing = false;
          initialCheckComplete = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (supported && api.configured && !initialCheckComplete) {
      return Scaffold(
        body: Center(
          child: showing
              ? const RayeqBrandLockup()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: royalGold),
                    const SizedBox(height: 20),
                    Text(tr('جاري التحقق من إصدار التطبيق…')),
                  ],
                ),
        ),
      );
    }
    return widget.child;
  }
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final bool requiredUpdate;
  final int? installedBuild;
  final Duration? graceRemaining;
  final Future<UpdateInfo> Function()? fetchLatest;
  const UpdateDialog({
    super.key,
    required this.info,
    required this.requiredUpdate,
    this.installedBuild,
    this.graceRemaining,
    this.fetchLatest,
  });
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool busy = false;
  late bool requiredUpdate;
  Timer? graceTimer;
  String? path;
  String error = '', status = '';
  late UpdateInfo info;
  @override
  void initState() {
    super.initState();
    info = widget.info;
    requiredUpdate = widget.requiredUpdate;
    armGrace(widget.graceRemaining);
  }

  @override
  void dispose() {
    graceTimer?.cancel();
    super.dispose();
  }

  void armGrace(Duration? remaining) {
    graceTimer?.cancel();
    if (!requiredUpdate && remaining != null && remaining > Duration.zero) {
      graceTimer = Timer(remaining, () {
        if (mounted) setState(() => requiredUpdate = true);
      });
    }
  }

  Future<UpdateInfo> fetchInfo() async {
    if (widget.fetchLatest != null) return widget.fetchLatest!();
    final client = RayeqApi();
    try {
      return UpdateInfo.parse(
        await client
            .getMap('app/version')
            .timeout(const Duration(seconds: 125)),
      );
    } finally {
      client.close();
    }
  }

  Future<bool> refreshPolicy() async {
    try {
      final fresh = await fetchInfo();
      if (!mounted) return false;
      if (!fresh.downloadable ||
          (widget.installedBuild != null &&
              fresh.latestBuild <= widget.installedBuild!)) {
        Navigator.pop(context);
        return false;
      }
      if (fresh.latestBuild != info.latestBuild || fresh.sha256 != info.sha256)
        path = null;
      setState(() {
        info = fresh;
        if (widget.installedBuild != null) {
          requiredUpdate = fresh.isRequiredFor(widget.installedBuild!);
        }
      });
      armGrace(fresh.remainingGrace());
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('تعذر التحقق من التحديثات. تقدر تكمل استخدام التطبيق.'),
            ),
          ),
        );
        Navigator.pop(context);
      }
      return false;
    }
  }

  Future<void> recheck() async {
    setState(() {
      busy = true;
      error = '';
    });
    await refreshPolicy();
    if (mounted) setState(() => busy = false);
  }

  Future<void> update() async {
    setState(() {
      busy = true;
      error = '';
      status = 'جاري التحقق من إصدار التطبيق…';
    });
    try {
      // Fresh metadata precedes every download or installer retry.
      if (!await refreshPolicy() || !mounted) return;
      setState(
        () => status = path == null
            ? 'جاري تنزيل التحديث والتحقق من سلامته…'
            : 'جاري فتح مثبت أندرويد…',
      );
      path ??= await AppUpdateGateState.system.invokeMethod<String>(
        'downloadUpdate',
        {'url': info.url, 'sha256': info.sha256, 'build': info.latestBuild},
      );
      if (path == null) throw const FormatException('No package');
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
      if (mounted) {
        setState(() {
          if (e.code == 'UPDATE_VERIFICATION_FAILED' ||
              e.code == 'UPDATE_DOWNLOAD_FAILED')
            path = null;
          error = 'التحديث مكملش أو التحقق من الملف فشل. مفيش ملف غير موثوق اتفتح. جرّب تاني.';
          status = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'تعذر تنزيل التحديث أو فتح المثبت. جرّب تاني.';
          status = '';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !requiredUpdate && !busy,
    child: AlertDialog(
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actionsOverflowButtonSpacing: 8,
      buttonPadding: const EdgeInsetsDirectional.only(start: 8),
      icon: const Icon(Icons.system_update_alt, color: royalGold, size: 42),
      title: Text(tr(requiredUpdate ? 'التحديث مطلوب' : 'نسخة جديدة من رايق')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('الإصدار ${info.version}'),
              style: const TextStyle(
                color: royalGold,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              appLocale.value.languageCode == 'en'
                  ? (info.notesEn.isEmpty
                        ? tr('تحسينات وتحديثات للتطبيق.')
                        : info.notesEn)
                  : (info.notes.isEmpty
                        ? 'تحسينات وتحديثات للتطبيق.'
                        : info.notes),
            ),
            const SizedBox(height: 14),
            Text(
              tr(
                requiredUpdate
                    ? 'انتهت مهلة اليومين. حدّث رايق عشان تكمل.'
                    : 'تقدر تختار مش دلوقتي خلال أول يومين من نزول التحديث.',
              ),
              style: const TextStyle(fontSize: 12, color: royalMuted),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(tr(status), style: const TextStyle(fontSize: 12)),
              ),
            if (busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  tr(error),
                  style: const TextStyle(
                    color: Color(0xffffb4ab),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!requiredUpdate)
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(tr('مش دلوقتي')),
          ),
        if (requiredUpdate && error.isNotEmpty)
          TextButton(
            onPressed: busy ? null : recheck,
            child: Text(tr('إعادة التحقق')),
          ),
        FilledButton(
          onPressed: busy ? null : update,
          child: Text(
            tr(
              busy
                  ? 'جاري التحديث…'
                  : path == null
                  ? 'نزّل دلوقتي'
                  : 'متابعة التثبيت',
            ),
          ),
        ),
      ],
    ),
  );
}
