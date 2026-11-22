import 'localization.dart';

import 'package:flutter/material.dart';

import 'royal_theme.dart';
import 'ui_parts.dart';
import 'demo_data.dart';

class ServiceDetails extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool demo;
  final VoidCallback onBook;
  const ServiceDetails({
    super.key,
    required this.service,
    required this.demo,
    required this.onBook,
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
                        style: TextStyle(color: royalMuted, fontSize: 11),
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
                      Icon(Icons.schedule, color: royalPurple),
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
              'الإدارة تراجع وتأكد الزيارة وتسند العامل.',
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
              tr(
                'رسوم الانتقال بتظهر قبل إرسال الطلب. الإدارة بتختار الحلاق المناسب لزيارتك.',
              ),
              style: TextStyle(fontSize: 11, color: royalMuted),
            ),
            SizedBox(height: 25),
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
