import 'nearby.dart';
import 'localization.dart';

import 'package:flutter/material.dart';

import 'royal_theme.dart';
import 'ui_parts.dart';
import 'demo_data.dart';

class ServiceDetails extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool demo;
  final VoidCallback onBook;
  final VoidCallback? onNearby;
  const ServiceDetails({
    super.key,
    required this.service,
    required this.demo,
    required this.onBook,
    this.onNearby,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('تفاصيل الخدمة'))),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580),
        child: ListView(
          padding: EdgeInsets.all(24),
          children: [
            ServiceArt(
              name: displayServiceName(service),
              imageUrl: service['imageUrl'] as String?,
              height: 290,
            ),
            SizedBox(height: 22),
            Text(
              tr(displayServiceName(service)),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 8),
            Text(
              displayCategory(service),
              style: TextStyle(color: royalGold, fontSize: 12),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: royalSurface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: royalLine),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('سعر الخدمة'),
                        style: TextStyle(color: royalMuted, fontSize: 12),
                      ),
                      Text(
                        tr(egp(service['priceMinor'])),
                        style: TextStyle(
                          color: royalGold,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.schedule, color: royalGold),
                      Text(
                        tr('${service['durationMinutes']} دقيقة'),
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),
            Text(
              tr('عن الخدمة'),
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              displayServiceDescription(service),
              style: TextStyle(color: royalMuted),
            ),
            SizedBox(height: 22),
            Text(
              tr('الزيارة بتتم إزاي؟'),
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            for (final step in [
              'اختار المكان والمعاد اللي تطلبه.',
              'راجع الإجمالي بعد اختيار المنطقة.',
              'احجز مباشرة مع الحلاق المتاح، أو ابعت طلب ونختار لك.',
            ])
              Padding(
                padding: EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: royalGold,
                      size: 18,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        tr(step),
                        style: TextStyle(color: royalMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 15),
            Text(
              nearbyText(
                'رسوم الانتقال بتظهر قبل الحجز. اختار حلاقك المتاح واحجز معاه مباشرة، أو ابعت طلب ونختار لك.',
                'Travel fees are shown before booking. Choose an available barber to book directly, or send a request and we will assign one.',
              ),
              style: TextStyle(fontSize: 12, color: royalMuted),
            ),
            SizedBox(height: 25),
            if (onNearby != null) ...[
              FilledButton.icon(
                onPressed: onNearby,
                icon: const Icon(Icons.near_me_outlined),
                label: Text(tr('دوّر على حلاق قريب مني')),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: onBook,
                child: Text(tr('اطلب الزيارة')),
              ),
            ),
            SizedBox(height: 25),
          ],
        ),
      ),
    ),
  );
}
