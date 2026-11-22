import 'package:flutter/material.dart';

import 'api.dart';
import 'barber_profiles.dart';
import 'nearby.dart';
import 'royal_theme.dart';

class SavedPublicBarbers extends StatefulWidget {
  final RayeqApi api;
  final List<String> ids;
  final ValueChanged<String> onSave;
  const SavedPublicBarbers({
    super.key,
    required this.api,
    required this.ids,
    required this.onSave,
  });
  @override
  State<SavedPublicBarbers> createState() => _SavedPublicBarbersState();
}

class _SavedPublicBarbersState extends State<SavedPublicBarbers> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant SavedPublicBarbers old) {
    super.didUpdateWidget(old);
    if (old.ids.join(',') != widget.ids.join(',') || old.api != widget.api)
      reload();
  }

  void reload() {
    future = Future.wait(
      widget.ids.map((id) async {
        try {
          return {...await widget.api.getMap('barbers/$id'), 'id': id};
        } catch (_) {
          return <String, dynamic>{'id': id, '_failed': true};
        }
      }),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Padding(
          padding: EdgeInsets.all(20),
          child: LinearProgressIndicator(),
        );
      return Column(
        children: [
          for (final b in snapshot.data!)
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: royalSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: royalGold.withValues(alpha: .3),
                  width: .7,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  leading: b['_failed'] == true
                      ? const Icon(Icons.person_outline, color: royalGold)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 56,
                            height: 64,
                            child: BarberCoverImage(api: widget.api, barber: b),
                          ),
                        ),
                  title: Text(
                    b['_failed'] == true
                        ? nearbyText(
                            'تعذر تحميل الحلاق المحفوظ',
                            'Saved barber could not load',
                          )
                        : nearbyText(
                            '${b['nameAr'] ?? b['nameEn'] ?? ''}',
                            '${b['nameEn'] ?? b['nameAr'] ?? ''}',
                          ),
                  ),
                  subtitle: b['_failed'] == true
                      ? TextButton(
                          onPressed: () => setState(reload),
                          child: Text(nearbyText('جرّب تاني', 'Try again')),
                        )
                      : Text(
                          nearbyText('عرض الملف', 'View profile'),
                          style: const TextStyle(color: royalMuted),
                        ),
                  trailing: IconButton(
                    tooltip: nearbyText(
                      'إزالة من المحفوظات',
                      'Remove from saved',
                    ),
                    onPressed: () => widget.onSave('${b['id']}'),
                    icon: const Icon(Icons.favorite_rounded, color: royalGold),
                  ),
                  onTap: b['_failed'] == true
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveBarberProfile(
                              api: widget.api,
                              barber: b,
                              initialFavorite: true,
                              onFavorite: () => widget.onSave('${b['id']}'),
                            ),
                          ),
                        ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
