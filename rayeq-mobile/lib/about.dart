import 'package:flutter/material.dart';

import 'localization.dart';
import 'royal_theme.dart';

String aboutText(String ar, String en) =>
    appLocale.value.languageCode == 'en' ? en : ar;

class AboutRayeq extends StatelessWidget {
  const AboutRayeq({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(aboutText('عن رايق', 'About Rayeq'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: royalSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: royalLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aboutText('رايق', 'Rayeq'),
                    style: const TextStyle(
                      color: royalGold,
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    aboutText('حلاقك عندك', 'Your barber, at your door'),
                    style: const TextStyle(color: royalGold, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    aboutText(
                      'رايق بيرتب لك خدمات الحلاقة والعناية الشخصية في بيتك أو مكان شغلك. اختار خدمتك واطلب ميعادك، وفريق رايق بيراجع التفاصيل ويأكد الزيارة.',
                      'Rayeq helps you request barbering and grooming at home or work. Choose a service and requested time. The Rayeq team reviews the details and confirms each visit.',
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.9),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: royalLine),
              ),
              tileColor: royalSurface,
              leading: const Icon(Icons.shield_outlined, color: royalGold),
              title: Text(aboutText('سياسة الخصوصية', 'Privacy policy')),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: royalMuted,
              ),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicy())),
            ),
            const SizedBox(height: 32),
            Text(
              aboutText('تطوير هيكسا بلس', 'Developed by HEXA PLUS'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: royalMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});
  @override
  Widget build(BuildContext context) {
    Widget section(
      IconData icon,
      String titleAr,
      String titleEn,
      String bodyAr,
      String bodyEn,
    ) => Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: royalSurface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: royalLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: royalGold, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  aboutText(titleAr, titleEn),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            aboutText(bodyAr, bodyEn),
            style: const TextStyle(
              fontSize: 13,
              height: 1.9,
              color: royalMuted,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(aboutText('سياسة الخصوصية', 'Privacy policy')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
            children: [
              Text(
                aboutText('بياناتك في رايق', 'Your data in Rayeq'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                aboutText(
                  'توضيح للبيانات اللي بيستخدمها الإصدار الحالي من التطبيق.',
                  'How the current version of the app uses your information.',
                ),
                style: const TextStyle(color: royalMuted, fontSize: 13),
              ),
              section(
                Icons.person_outline_rounded,
                'الحساب',
                'Your account',
                'بنستخدم اسمك وإيميلك وكلمة المرور لإنشاء الحساب وتسجيل الدخول. الإيميل بيستخدم لتفعيل الحساب واستعادة كلمة المرور. تقدر تضيف موبايل وصورة شخصية لحسابك باختيارك.',
                'We use your name, email and password to create your account and sign you in. Email is used for verification and password recovery. You can optionally add a phone number and profile photo.',
              ),
              section(
                Icons.calendar_month_outlined,
                'طلبات الزيارة',
                'Visit requests',
                'الحجز بيحتاج اسم العميل وموبايل للتواصل وعنوان الزيارة، مع الخدمة والميعاد المطلوب وطريقة الدفع. العنوان ممكن يشمل الشارع والعمارة والدور والشقة وجهة العمل وإرشادات الوصول. بنحتفظ بحالة الزيارة وحالة الدفع لإدارة الطلب.',
                'A booking needs a customer name, contact phone and visit address, plus the service, requested time and payment method. An address may include the street, building, floor, apartment, workplace and arrival notes. Visit and payment status are kept to manage the request.',
              ),
              section(
                Icons.groups_outlined,
                'استخدام بيانات الزيارة',
                'Using visit details',
                'بيانات الزيارة بتظهر للإدارة وللحلاق اللي بتتسند له، بالقدر اللازم لتنظيم الخدمة والتواصل بخصوصها. حسابات الحلاقين بتحتاج موافقة الإدارة قبل استلام زيارات. الخدمات التقنية اللي بتشغّل التطبيق والبريد بتتعامل مع البيانات اللازمة لتشغيل الخدمة.',
                'Visit details are available to the admin team and assigned barber as needed to organise the service and communicate about it. Barber accounts need approval before receiving visits. The services that host the app and deliver email process the information needed to operate it.',
              ),
              section(
                Icons.phone_android_rounded,
                'على جهازك',
                'On your device',
                'جلسة الدخول بتتحفظ على جهازك، وتسجيل الخروج بيمسح الجلسة من الجهاز. المحفوظات بتتخزن على نفس الجهاز ومش بتتزامن بين الأجهزة. التطبيق الحالي مش بيطلب الموقع الجغرافي أو بيانات بطاقة بنكية في مسار الحجز.',
                'Your sign-in session is stored on your device. Signing out clears that device session. Favourites are stored on this device and do not sync between devices. The current booking flow does not request GPS location or bank-card details.',
              ),
              section(
                Icons.tune_rounded,
                'إدارة بياناتك',
                'Managing your details',
                'تقدر تعدّل اسمك وموبايلك وصورتك من الملف الشخصي. تغيير الإيميل ونوع الحساب وحذف الحساب مش متاحين من داخل التطبيق في الإصدار الحالي.',
                'You can edit your name, phone and photo from your profile. Changing email or account type and deleting an account are not available inside the current version of the app.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
