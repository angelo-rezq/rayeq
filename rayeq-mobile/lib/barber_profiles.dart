import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'demo_data.dart' show previewFixturesEnabled, fixtureText;
import 'localization.dart';
import 'nearby.dart';
import 'royal_theme.dart';

class BarberRating {
  final double? average;
  final int? count;
  const BarberRating({this.average, this.count});
}

class BarberReview {
  final String author, comment;
  final int stars;
  final String? dateLabel;
  const BarberReview({
    required this.author,
    required this.stars,
    this.comment = '',
    this.dateLabel,
  });
}

class WorkPhoto {
  final String id, url;
  final String? caption;
  const WorkPhoto({required this.id, required this.url, this.caption});
}

class RatingSummary extends StatelessWidget {
  final BarberRating rating;
  final bool compact;
  const RatingSummary({super.key, required this.rating, this.compact = false});
  @override
  Widget build(BuildContext context) {
    if (rating.count == 0)
      return Text(
        nearbyText('لسه مفيش تقييمات', 'No reviews yet'),
        style: const TextStyle(color: royalMuted, fontSize: 12),
      );
    if (rating.average == null || rating.count == null)
      return Text(
        nearbyText('التقييمات غير متاحة بعد', 'Ratings are not available yet'),
        style: const TextStyle(color: royalMuted, fontSize: 12),
      );
    if (rating.count == 0)
      return Text(
        nearbyText('لسه مفيش تقييمات', 'No reviews yet'),
        style: const TextStyle(color: royalMuted, fontSize: 12),
      );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 3,
      children: [
        const Icon(Icons.star_rounded, color: royalGold, size: 18),
        Text(
          rating.average!.toStringAsFixed(1),
          style: TextStyle(
            color: royalGold,
            fontSize: compact ? 12 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${rating.count} ${nearbyText('مراجعة', rating.count == 1 ? 'review' : 'reviews')}',
          style: const TextStyle(color: royalMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class WorkPhotoGrid extends StatelessWidget {
  final List<WorkPhoto> photos;
  final void Function(WorkPhoto)? onDelete;
  const WorkPhotoGrid({super.key, required this.photos, this.onDelete});
  @override
  Widget build(BuildContext context) => photos.isEmpty
      ? Text(
          nearbyText(
            'مفيش صور أعمال مرفوعة لسه.',
            'No work photos have been uploaded yet.',
          ),
          style: const TextStyle(color: royalMuted),
        )
      : GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Material(
                  color: royalRaised,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkPhotoViewer(
                          photos: photos,
                          initialIndex: index,
                        ),
                      ),
                    ),
                    child: Image.network(
                      photos[index].url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: royalMuted,
                        ),
                      ),
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
                if (onDelete != null)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: IconButton.filled(
                      tooltip: nearbyText('حذف الصورة', 'Delete photo'),
                      style: IconButton.styleFrom(
                        backgroundColor: royalBackground.withValues(alpha: .85),
                        foregroundColor: royalGold,
                      ),
                      onPressed: () => onDelete!(photos[index]),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
              ],
            ),
          ),
        );
}

class WorkPhotoViewer extends StatefulWidget {
  final List<WorkPhoto> photos;
  final int initialIndex;
  const WorkPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });
  @override
  State<WorkPhotoViewer> createState() => _WorkPhotoViewerState();
}

class _WorkPhotoViewerState extends State<WorkPhotoViewer> {
  late final PageController controller;
  late int index;
  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    controller = PageController(initialPage: index);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${index + 1} / ${widget.photos.length}')),
    body: Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: widget.photos.length,
            onPageChanged: (value) => setState(() => index = value),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.photos[i].url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    nearbyText(
                      'تعذر تحميل الصورة.',
                      'Could not load the photo.',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.photos[index].caption?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.photos[index].caption!,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}

class BarberPublicProfile extends StatelessWidget {
  final String name;
  final BarberRating rating;
  final List<BarberReview> reviews;
  final List<WorkPhoto> photos;
  final Map<String, dynamic> profile;
  final bool loading, loadingMore;
  final String? error;
  final VoidCallback? onBook, onMoreReviews, onRetry, onFavorite, onShare;
  final bool isFavorite;
  final ValueChanged<Map<String, dynamic>>? onService;
  const BarberPublicProfile({
    super.key,
    required this.name,
    this.rating = const BarberRating(),
    this.reviews = const [],
    this.photos = const [],
    this.profile = const {},
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.onBook,
    this.onMoreReviews,
    this.onRetry,
    this.onService,
    this.onFavorite,
    this.onShare,
    this.isFavorite = false,
  });
  String local(String key) =>
      '${profile['${key}${appLocale.value.languageCode == 'en' ? 'En' : 'Ar'}'] ?? ''}'
          .trim();
  String price(num amount) =>
      '${(amount / 100).toStringAsFixed(amount % 100 == 0 ? 0 : 2)} ${nearbyText('ج.م', 'EGP')}';
  Widget stat(String value, String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: royalSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: royalLine),
      ),
      child: Column(
        children: [
          Icon(icon, color: royalGold, size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: royalGold,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: royalMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final services = (profile['services'] as List? ?? [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final language = appLocale.value.languageCode == 'en' ? 'En' : 'Ar';
    final specialties = (profile['specialties$language'] as List? ?? [])
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final areas = (profile['serviceAreas'] as List? ?? [])
        .whereType<Map>()
        .map((p) => '${p['name$language'] ?? ''}')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final startPrice = profile['startingPriceMinor'] as num?;
    void book() {
      if (onBook != null) {
        onBook!();
        return;
      }
      if (onService == null || services.isEmpty) return;
      showModalBottomSheet(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                nearbyText('اختار خدمتك', 'Choose your service'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final service in services)
                ListTile(
                  title: Text('${service['name$language'] ?? ''}'),
                  subtitle: Text(
                    '${service['durationMinutes'] ?? '-'} ${nearbyText('دقيقة', 'min')}',
                  ),
                  trailing: service['priceMinor'] is num
                      ? Text(price(service['priceMinor']))
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onService!(service);
                  },
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        title: Text(nearbyText('ملف الحلاق', 'Full profile')),
        actions: [
          if (onFavorite != null)
            IconButton(
              tooltip: nearbyText(
                isFavorite ? 'إزالة من المحفوظات' : 'حفظ الحلاق',
                isFavorite ? 'Remove from saved' : 'Save barber',
              ),
              onPressed: onFavorite,
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: royalGold,
              ),
            ),
          if (onShare != null)
            IconButton(
              tooltip: nearbyText('مشاركة الملف', 'Share profile'),
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined, color: royalGold),
            ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar:
          onBook == null && (onService == null || services.isEmpty)
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  color: royalSurface,
                  border: Border(top: BorderSide(color: royalLine)),
                ),
                child: Row(
                  children: [
                    if (startPrice != null)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nearbyText('يبدأ من', 'Starting from'),
                              style: const TextStyle(
                                color: royalMuted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              price(startPrice),
                              style: const TextStyle(
                                color: royalGold,
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              nearbyText('بدون انتقال', 'Travel extra'),
                              style: const TextStyle(
                                color: royalMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (startPrice != null) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: book,
                        child: Text(
                          nearbyText('احجز زيارة', 'Book appointment'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              cacheExtent: 1800,
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: (MediaQuery.sizeOf(context).width * .82).clamp(
                    280.0,
                    360.0,
                  ),
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, .48, 1],
                        ).createShader(rect),
                        child: BarberCoverImage(
                          barber: {
                            ...profile,
                            'gallery': {
                              'items': photos
                                  .map((p) => {'id': p.id, 'url': p.url})
                                  .toList(),
                            },
                          },
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xb3000000),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: [0, .36, 1],
                          ),
                        ),
                      ),
                      if (profile['demoOnly'] == true)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 10,
                          child: Text(
                            nearbyText(
                              'ملف تجريبي، البيانات للمعاينة',
                              'Demo profile, preview data',
                            ),
                            style: const TextStyle(
                              color: royalGold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      if (local('title').isNotEmpty)
                        Text(
                          local('title'),
                          style: const TextStyle(
                            color: royalGold,
                            fontSize: 14,
                          ),
                        ),
                      if (areas.isNotEmpty || local('areaName').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '${nearbyText('نطاق الخدمة', 'Service coverage')}: ${areas.isEmpty ? local('areaName') : areas.join(' / ')}',
                            style: const TextStyle(
                              color: royalMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          stat(
                            rating.average?.toStringAsFixed(1) ?? '-',
                            nearbyText('التقييم', 'Rating'),
                            Icons.star_rounded,
                          ),
                          const SizedBox(width: 8),
                          stat(
                            rating.count?.toString() ?? '-',
                            nearbyText('مراجعة', 'Reviews'),
                            Icons.chat_bubble_outline_rounded,
                          ),
                          const SizedBox(width: 8),
                          stat(
                            profile['yearsExperience']?.toString() ?? '-',
                            nearbyText('سنوات خبرة', 'Years experience'),
                            Icons.content_cut_rounded,
                          ),
                        ],
                      ),
                      if (rating.count == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            nearbyText('لسه مفيش تقييمات', 'No reviews yet'),
                            style: const TextStyle(
                              color: royalMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: LinearProgressIndicator(),
                        ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(color: Color(0xffffb4ab)),
                        ),
                        if (onRetry != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: loading ? null : onRetry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(nearbyText('جرّب تاني', 'Try again')),
                            ),
                          ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        nearbyText('الخدمات', 'Services'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (services.isEmpty && !loading)
                        Text(
                          nearbyText(
                            'الخدمات هتظهر لما الإدارة تضيفها للحلاق.',
                            'Services will appear when assigned by the team.',
                          ),
                          style: const TextStyle(
                            color: royalMuted,
                            fontSize: 13,
                          ),
                        ),
                      for (final service in services)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: royalSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: royalLine),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              leading: const Icon(
                                Icons.content_cut_rounded,
                                color: royalGold,
                              ),
                              title: Text(
                                '${service['name$language'] ?? ''}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                '${service['durationMinutes'] ?? '-'} ${nearbyText('دقيقة', 'min')}',
                                style: const TextStyle(
                                  color: royalMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: service['priceMinor'] is num
                                  ? Text(
                                      price(service['priceMinor']),
                                      style: const TextStyle(color: royalGold),
                                    )
                                  : null,
                              onTap: onService == null
                                  ? null
                                  : () => onService!(service),
                            ),
                          ),
                        ),
                      if (services.isNotEmpty)
                        Text(
                          nearbyText(
                            'الأسعار بدون انتقال. الإجمالي بيتأكد بعد اختيار المنطقة.',
                            'Prices exclude travel. The total is confirmed after choosing your area.',
                          ),
                          style: const TextStyle(
                            color: royalMuted,
                            fontSize: 11,
                          ),
                        ),
                      if (specialties.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: specialties
                                .map((s) => Chip(label: Text(s)))
                                .toList(),
                          ),
                        ),
                      if (local('bio').isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text(
                          nearbyText('عن الحلاق', 'About the barber'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          local('bio'),
                          style: const TextStyle(color: royalMuted),
                        ),
                      ],
                      const SizedBox(height: 26),
                      Text(
                        nearbyText('صور الأعمال', 'Work photos'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      WorkPhotoGrid(photos: photos),
                      const SizedBox(height: 26),
                      Text(
                        nearbyText(
                          'التقييمات والمراجعات',
                          'Ratings and reviews',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      if (reviews.isEmpty && !loading)
                        Text(
                          nearbyText(
                            'مفيش مراجعات معروضة بعد.',
                            'No reviews are displayed yet.',
                          ),
                          style: const TextStyle(color: royalMuted),
                        ),
                      for (final review in reviews)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: royalSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: royalLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.author.isEmpty
                                    ? nearbyText('عميل', 'Customer')
                                    : review.author,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                children: [
                                  for (var star = 1; star <= 5; star++)
                                    Icon(
                                      star <= review.stars
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: royalGold,
                                      size: 19,
                                    ),
                                ],
                              ),
                              if (review.comment.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(review.comment),
                                ),
                              if (review.dateLabel != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    review.dateLabel!,
                                    style: const TextStyle(
                                      color: royalMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      if (loadingMore) const LinearProgressIndicator(),
                      if (onMoreReviews != null)
                        OutlinedButton(
                          onPressed: onMoreReviews,
                          child: Text(
                            nearbyText('مراجعات أكتر', 'More reviews'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReviewComposer extends StatefulWidget {
  final Future<void> Function(int stars, String comment) onSubmit;
  final int? maxCommentLength;
  const ReviewComposer({
    super.key,
    required this.onSubmit,
    this.maxCommentLength,
  });
  @override
  State<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<ReviewComposer> {
  final comment = TextEditingController();
  int stars = 0;
  bool busy = false;
  String error = '';
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (stars < 1 || busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.onSubmit(stars, comment.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = tr(e.message));
    } catch (_) {
      if (mounted)
        setState(
          () => error = nearbyText(
            'تعذر إرسال التقييم. جرّب تاني.',
            'Could not send your review. Try again.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(nearbyText('قيّم زيارتك', 'Rate your visit'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  nearbyText('كانت الزيارة عاملة إزاي؟', 'How was your visit?'),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  nearbyText(
                    'اختار من نجمة لخمس نجوم. تعليقك اختياري.',
                    'Choose 1 to 5 stars. Your comment is optional.',
                  ),
                  style: const TextStyle(color: royalMuted),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        tooltip: '$i / 5',
                        onPressed: () => setState(() => stars = i),
                        icon: Icon(
                          i <= stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: royalGold,
                          size: 32,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: comment,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: widget.maxCommentLength,
                  decoration: InputDecoration(
                    labelText: nearbyText(
                      'تعليقك، اختياري',
                      'Comment, optional',
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error,
                      style: const TextStyle(color: Color(0xffffb4ab)),
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: stars < 1 || busy ? null : submit,
                  child: Text(nearbyText('إرسال التقييم', 'Submit review')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WorkerPortfolioPanel extends StatefulWidget {
  final List<WorkPhoto> photos;
  final int? maxPhotos, maxBytes;
  final Future<WorkPhoto> Function(XFile file)? onUpload;
  final Future<void> Function(WorkPhoto photo)? onDelete;
  const WorkerPortfolioPanel({
    super.key,
    required this.photos,
    this.maxPhotos,
    this.maxBytes,
    this.onUpload,
    this.onDelete,
  });
  @override
  State<WorkerPortfolioPanel> createState() => _WorkerPortfolioPanelState();
}

class _WorkerPortfolioPanelState extends State<WorkerPortfolioPanel> {
  late List<WorkPhoto> photos;
  bool busy = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    photos = [...widget.photos];
  }

  Future<void> choose() async {
    if (busy || widget.onUpload == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: royalGold,
              ),
              title: Text(nearbyText('اختار من الصور', 'Choose from gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: royalGold),
              title: Text(nearbyText('التقط صورة', 'Take a photo')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (file == null || !mounted) return;
      if (widget.maxBytes != null && await file.length() > widget.maxBytes!)
        throw ApiFailure(
          'PHOTO_TOO_LARGE',
          nearbyText(
            'حجم الصورة أكبر من الحد المسموح.',
            'The photo exceeds the upload size limit.',
          ),
        );
      final photo = await widget.onUpload!(file);
      if (mounted) setState(() => photos.add(photo));
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = tr(e.message));
    } catch (_) {
      if (mounted)
        setState(
          () => error = nearbyText(
            'تعذر رفع الصورة. راجع إذن الكاميرا أو الصور وجرّب تاني.',
            'Could not upload the photo. Check camera or photo access and try again.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(WorkPhoto photo) async {
    if (busy || widget.onDelete == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(nearbyText('تحذف الصورة؟', 'Delete this photo?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(nearbyText('رجوع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nearbyText('حذف الصورة', 'Delete photo')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.onDelete!(photo);
      if (mounted) setState(() => photos.removeWhere((p) => p.id == photo.id));
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = tr(e.message));
    } catch (_) {
      if (mounted)
        setState(
          () => error = nearbyText(
            'تعذر حذف الصورة.',
            'Could not delete the photo.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        nearbyText('صور شغلك', 'Your work photos'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        widget.maxPhotos == null
            ? '${photos.length} ${nearbyText('صور', 'photos')}'
            : nearbyText(
                'الصور: ${photos.length} من ${widget.maxPhotos}',
                '${photos.length} / ${widget.maxPhotos} photos',
              ),
        style: const TextStyle(color: royalMuted, fontSize: 12),
      ),
      if (widget.maxBytes != null)
        Text(
          nearbyText(
            'أقصى حجم للصورة: ${(widget.maxBytes! / 1048576).toStringAsFixed(1)} ميجابايت',
            'Maximum photo size: ${(widget.maxBytes! / 1048576).toStringAsFixed(1)} MB',
          ),
          style: const TextStyle(color: royalMuted, fontSize: 12),
        ),
      const SizedBox(height: 16),
      if (busy)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: LinearProgressIndicator(),
        ),
      if (error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(error, style: const TextStyle(color: Color(0xffffb4ab))),
        ),
      WorkPhotoGrid(
        photos: photos,
        onDelete: busy || widget.onDelete == null ? null : remove,
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed:
              busy ||
                  widget.onUpload == null ||
                  widget.maxPhotos != null && photos.length >= widget.maxPhotos!
              ? null
              : choose,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(nearbyText('أضف صورة من شغلك', 'Add a work photo')),
        ),
      ),
      if (widget.onUpload == null)
        Text(
          nearbyText(
            'رفع الصور قيد التجهيز.',
            'Photo uploads are being prepared.',
          ),
          style: const TextStyle(color: royalMuted, fontSize: 12),
        ),
    ],
  );
}

WorkPhoto workPhotoFromMap(Map p) =>
    WorkPhoto(id: '${p['id']}', url: '${p['url']}');
BarberRating ratingFromMap(Map p) => BarberRating(
  average: (p['ratingAverage'] as num?)?.toDouble(),
  count: (p['reviewCount'] as num?)?.toInt(),
);

class WorkerPortfolioCard extends StatefulWidget {
  final RayeqApi api;
  const WorkerPortfolioCard({super.key, required this.api});
  @override
  State<WorkerPortfolioCard> createState() => _WorkerPortfolioCardState();
}

class _WorkerPortfolioCardState extends State<WorkerPortfolioCard> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    future = Future.wait([
      widget.api.getMap('worker/gallery'),
      widget.api.getMap('worker/rating'),
    ]);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const LinearProgressIndicator();
          if (snapshot.hasError)
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nearbyText(
                    'تعذر تحميل صور الشغل والتقييمات.',
                    'Could not load your work photos and ratings.',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(reload),
                  child: Text(nearbyText('جرّب تاني', 'Try again')),
                ),
              ],
            );
          final gallery = snapshot.data![0], rating = snapshot.data![1];
          final photos = (gallery['items'] as List? ?? [])
              .map((p) => workPhotoFromMap(p))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatingSummary(rating: ratingFromMap(rating)),
              const SizedBox(height: 24),
              WorkerPortfolioPanel(
                key: ValueKey(photos.map((p) => p.id).join(',')),
                photos: photos,
                maxPhotos: (gallery['maxPhotos'] as num?)?.toInt() ?? 6,
                maxBytes: 5 * 1024 * 1024,
                onUpload: (file) async {
                  final bytes = await file.readAsBytes();
                  final String mime;
                  if (bytes.length >= 3 &&
                      bytes[0] == 255 &&
                      bytes[1] == 216 &&
                      bytes[2] == 255) {
                    mime = 'image/jpeg';
                  } else if (bytes.length >= 4 &&
                      bytes[0] == 137 &&
                      bytes[1] == 80 &&
                      bytes[2] == 78 &&
                      bytes[3] == 71) {
                    mime = 'image/png';
                  } else if (bytes.length >= 12 &&
                      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
                      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
                    mime = 'image/webp';
                  } else {
                    throw ApiFailure(
                      'PHOTO_FORMAT',
                      nearbyText(
                        'اختار صورة JPEG أو PNG أو WebP ثابتة.',
                        'Choose a static JPEG, PNG or WebP photo.',
                      ),
                    );
                  }
                  return workPhotoFromMap(
                    await widget.api.uploadWorkPhoto(bytes, mime),
                  );
                },
                onDelete: (photo) async {
                  await widget.api.request(
                    'DELETE',
                    'worker/gallery/${Uri.encodeComponent(photo.id)}',
                  );
                },
              ),
            ],
          );
        },
      );
}

class LiveBarberProfile extends StatefulWidget {
  final RayeqApi api;
  final Map<String, dynamic> barber;
  final VoidCallback? onBook;
  final ValueChanged<Map<String, dynamic>>? onService;
  final bool initialFavorite;
  final VoidCallback? onFavorite;
  const LiveBarberProfile({
    super.key,
    required this.api,
    required this.barber,
    this.onBook,
    this.onService,
    this.initialFavorite = false,
    this.onFavorite,
  });
  @override
  State<LiveBarberProfile> createState() => _LiveBarberProfileState();
}

class _LiveBarberProfileState extends State<LiveBarberProfile> {
  Map<String, dynamic>? detail;
  BarberRating rating = const BarberRating();
  List<Map<String, dynamic>> rawReviews = [];
  List<WorkPhoto> photos = [];
  String? nextCursor, error;
  bool busy = true, more = false;
  late bool favorite;
  String get path => 'barbers/${Uri.encodeComponent('${widget.barber['id']}')}';
  @override
  void initState() {
    super.initState();
    favorite = widget.initialFavorite;
    load();
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        busy = true;
        error = null;
      });
    final failures = <String, String>{};
    bool embeddedGallery = false;
    void failed(String section, Object e) {
      failures[section] = e is ApiFailure
          ? tr(e.message)
          : nearbyText(
              'تعذر تحميل الجزء ده. جرّب تاني.',
              'Could not load this section. Try again.',
            );
      if (mounted)
        setState(
          () => error = failures.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('\n'),
        );
    }

    Future<void> loadDetail() async {
      try {
        final data = await widget.api.getMap(path);
        if (!mounted) return;
        setState(() {
          detail = data;
          if (rating.count == null) rating = ratingFromMap(data);
          final gallery = data['gallery'];
          if (gallery is Map && gallery['items'] is List) {
            embeddedGallery = true;
            photos = (gallery['items'] as List)
                .whereType<Map>()
                .map(workPhotoFromMap)
                .toList();
            failures.remove(nearbyText('صور الأعمال', 'Work photos'));
            error = failures.isEmpty
                ? null
                : failures.entries
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join('\n');
          }
        });
      } catch (e) {
        failed(nearbyText('بيانات الحلاق', 'Barber details'), e);
      }
    }

    Future<void> loadReviews() async {
      try {
        final data = await widget.api.getMap(
          '$path/reviews',
          query: {'limit': '20'},
        );
        if (!mounted) return;
        setState(() {
          if (data.containsKey('reviewCount')) rating = ratingFromMap(data);
          rawReviews = (data['items'] as List? ?? [])
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          nextCursor = data['nextCursor'] as String?;
        });
      } catch (e) {
        failed(nearbyText('المراجعات', 'Reviews'), e);
      }
    }

    Future<void> loadPhotos() async {
      try {
        final data = await widget.api.getMap('$path/gallery');
        if (!mounted) return;
        setState(
          () => photos = (data['items'] as List? ?? [])
              .whereType<Map>()
              .map(workPhotoFromMap)
              .toList(),
        );
      } catch (e) {
        if (!embeddedGallery)
          failed(nearbyText('صور الأعمال', 'Work photos'), e);
      }
    }

    // Each section commits independently. A failed optional request must not
    // discard a successful profile, rating summary or embedded gallery.
    await Future.wait([loadDetail(), loadReviews(), loadPhotos()]);
    if (mounted) setState(() => busy = false);
  }

  Future<void> loadMore() async {
    if (nextCursor == null || more) return;
    setState(() => more = true);
    try {
      final data = await widget.api.getMap(
        '$path/reviews',
        query: {'limit': '20', 'cursor': nextCursor!},
      );
      if (mounted)
        setState(() {
          for (final r in data['items'] as List? ?? []) {
            if (!rawReviews.any((old) => old['id'] == r['id']))
              rawReviews.add(Map<String, dynamic>.from(r));
          }
          nextCursor = data['nextCursor'];
        });
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = tr(e.message));
    } finally {
      if (mounted) setState(() => more = false);
    }
  }

  Future<void> toggleFavorite() async {
    if (widget.onFavorite != null) {
      setState(() => favorite = !favorite);
      widget.onFavorite!();
      return;
    }
    try {
      final me = await widget.api.getMap('me');
      final prefs = await SharedPreferences.getInstance();
      final key = 'saved_${me['id']}';
      final ids = (prefs.getStringList(key) ?? []).toSet();
      final id = '${widget.barber['id']}';
      ids.contains(id) ? ids.remove(id) : ids.add(id);
      await prefs.setStringList(key, ids.toList());
      if (mounted) setState(() => favorite = ids.contains(id));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nearbyText(
                'تعذر حفظ الاختيار. جرّب تاني.',
                'Could not save this choice. Try again.',
              ),
            ),
          ),
        );
    }
  }

  Future<void> shareProfile() async {
    final b = detail ?? widget.barber;
    final en = appLocale.value.languageCode == 'en';
    final name = '${b[en ? 'nameEn' : 'nameAr'] ?? ''}';
    final title = '${b[en ? 'titleEn' : 'titleAr'] ?? ''}';
    final lines = <String>[
      name,
      if (title.isNotEmpty) title,
      en ? 'RAYEQ | Your barber, at your door' : 'رايق | حلاقك لحد باب بيتك',
      if (b['demoOnly'] == true)
        nearbyText(
          'ملف تجريبي للمعاينة، مش بيانات حلاق حقيقي.',
          'Demonstration profile, not a real worker biography.',
        ),
    ];
    final text = lines.join('\n');
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel('rayeq/app_updates')
            .invokeMethod('shareProfile', {
              'text': text,
              'title': nearbyText('مشاركة ملف الحلاق', 'Share barber profile'),
            });
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nearbyText(
                  'اتنسخ ملخص الملف للمشاركة.',
                  'Profile summary copied for sharing.',
                ),
              ),
            ),
          );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nearbyText('تعذر فتح المشاركة.', 'Could not open sharing.'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = detail ?? widget.barber;
    final preferred = appLocale.value.languageCode == 'en'
        ? 'nameEn'
        : 'nameAr';
    final alternate = preferred == 'nameEn' ? 'nameAr' : 'nameEn';
    final name =
        [
          b[preferred],
          widget.barber[preferred],
          b[alternate],
          widget.barber[alternate],
        ].whereType<String>().firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => nearbyText('حلاق رايق', 'Rayeq barber'),
        );
    return BarberPublicProfile(
      name: name,
      profile: b,
      onService: widget.onService,
      isFavorite: favorite,
      onFavorite: toggleFavorite,
      onShare: shareProfile,
      rating: rating,
      photos: photos,
      reviews: rawReviews
          .where((r) => r['demoOnly'] != true || previewFixturesEnabled)
          .map(
            (r) => BarberReview(
              author: r['demoOnly'] == true
                  ? fixtureText(r['customerDisplayName'] ?? '')
                  : '${r['customerDisplayName'] ?? ''}',
              stars: (r['rating'] as num).toInt(),
              comment: r['demoOnly'] == true
                  ? fixtureText(r['text'] ?? '')
                  : '${r['text'] ?? ''}',
              dateLabel: r['createdAt'] == null
                  ? null
                  : '${r['createdAt']}'.split('T').first,
            ),
          )
          .toList(),
      loading: busy,
      error: error,
      onRetry: load,
      onBook: widget.onBook,
      onMoreReviews: nextCursor == null || more ? null : loadMore,
      loadingMore: more,
    );
  }
}

class BarberCoverImage extends StatefulWidget {
  final RayeqApi? api;
  final Map<String, dynamic> barber;
  const BarberCoverImage({super.key, this.api, required this.barber});
  @override
  State<BarberCoverImage> createState() => _BarberCoverImageState();
}

class _BarberCoverImageState extends State<BarberCoverImage> {
  Map<String, dynamic>? loaded;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant BarberCoverImage old) {
    super.didUpdateWidget(old);
    if (old.barber['id'] != widget.barber['id'] ||
        old.api != widget.api ||
        old.barber['portraitUrl'] != widget.barber['portraitUrl'] ||
        old.barber['galleryThumbnailUrl'] !=
            widget.barber['galleryThumbnailUrl']) {
      loaded = null;
      load();
    }
  }

  Future<void> load() async {
    if (widget.api == null ||
        widget.barber['id'] == null ||
        ('${widget.barber['portraitUrl'] ?? ''}'.isNotEmpty ||
            '${widget.barber['galleryThumbnailUrl'] ?? ''}'.isNotEmpty))
      return;
    try {
      final data = await widget.api!.getMap(
        'barbers/${Uri.encodeComponent('${widget.barber['id']}')}',
      );
      if (mounted) setState(() => loaded = data);
    } catch (_) {
      /* A neutral placeholder remains when no published photo exists. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = loaded ?? widget.barber;
    final portrait = '${b['portraitUrl'] ?? ''}'.trim();
    final gallery = b['gallery'];
    final items = gallery is Map && gallery['items'] is List
        ? gallery['items'] as List
        : const [];
    final photo = items
        .whereType<Map>()
        .where((p) => '${p['url'] ?? ''}'.isNotEmpty)
        .firstOrNull;
    var url = portrait.isNotEmpty
        ? portrait
        : '${b['galleryThumbnailUrl'] ?? photo?['url'] ?? ''}';
    if (url.isNotEmpty && widget.api != null)
      url = Uri.parse(widget.api!.baseUrl).resolve(url).toString();
    final uri = Uri.tryParse(url);
    final valid = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    final fallback = ColoredBox(
      color: royalRaised,
      child: Center(
        child: Icon(
          portrait.isNotEmpty
              ? Icons.person_outline_rounded
              : Icons.content_cut_rounded,
          size: 58,
          color: royalGold,
        ),
      ),
    );
    if (!valid) return fallback;
    // Flutter's image cache reuses decoded network images between cards,
    // profile covers and the full-screen viewer without storing auth data.
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : fallback,
        ),
        if (portrait.isEmpty)
          PositionedDirectional(
            bottom: 8,
            start: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: royalBackground.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                nearbyText('صورة من الأعمال', 'Work photo'),
                style: const TextStyle(fontSize: 10, color: royalText),
              ),
            ),
          ),
      ],
    );
  }
}
