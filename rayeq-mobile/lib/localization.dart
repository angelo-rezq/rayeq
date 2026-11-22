import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLocale = ValueNotifier<Locale>(const Locale('ar', 'EG'));
Future<void> initLanguage() async {
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getString('app_language') == 'en')
      appLocale.value = const Locale('en');
  } catch (_) {}
}

Future<void> setAppLanguage(String language) async {
  appLocale.value = language == 'en'
      ? const Locale('en')
      : const Locale('ar', 'EG');
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('app_language', language);
  } catch (_) {}
}

String tr(String value) {
  if (appLocale.value.languageCode != 'en') return value;
  if (english.containsKey(value)) return english[value]!;
  if (extraEnglish.containsKey(value)) return extraEnglish[value]!;
  var result = value;
  for (final key in [
    'الموعد المطلوب: ',
    'الإجمالي: ',
    'الدفع: ',
    'أهلًا ',
    'الإصدار ',
    ' بتوقيت القاهرة',
    ' دقيقة',
    ' ج.م',
  ]) {
    result = result.replaceAll(
      key,
      {
        'الموعد المطلوب: ': 'Requested time: ',
        'الإجمالي: ': 'Total: ',
        'الدفع: ': 'Payment: ',
        'أهلًا ': 'Hello, ',
        'الإصدار ': 'Version ',
        ' بتوقيت القاهرة': ' Cairo time',
        ' دقيقة': ' min',
        ' ج.م': ' EGP',
      }[key]!,
    );
  }
  return result;
}

const english = <String, String>{
  'حلاقك عندك': 'Your barber, at your door',
  'رايق': 'Rayeq',
  'الملف الشخصي': 'Profile',
  'خيارات الحساب': 'Account options',
  'تحديث': 'Refresh',
  'تسجيل الخروج': 'Sign out',
  'تسجيل الدخول': 'Sign in',
  'إنشاء حساب': 'Create account',
  'كلمة المرور': 'Password',
  'البريد الإلكتروني': 'Email',
  'نسيت كلمة المرور؟': 'Forgot password?',
  'اسمك بالكامل': 'Full name',
  'كود التفعيل': 'Verification code',
  'تأكيد الإيميل': 'Verify email',
  'إعادة إرسال الكود': 'Resend code',
  'رجوع للدخول': 'Back to sign in',
  'استعادة الحساب': 'Reset password',
  'إرسال كود الاستعادة': 'Send reset code',
  'الكود': 'Code',
  'كلمة المرور الجديدة': 'New password',
  'تغيير كلمة المرور': 'Change password',
  'التالي': 'Next',
  'رجوع': 'Back',
  'تخطي': 'Skip',
  'ابدأ مع رايق': 'Get started',
  'دخول': 'Sign in',
  'خلّينا نبدأ': 'Get started',
  'أهلًا بيك في رايق': 'Welcome to Rayeq',
  'نورت رايق': 'Welcome to Rayeq',
  'أول مرة؟ اعمل حساب': 'New here? Create an account',
  'عندك حساب؟ سجّل دخول': 'Already registered? Sign in',
  'ادخل حسابك ورتّب وقت لنفسك.': 'Sign in and make time for yourself.',
  'بص على إيميلك': 'Check your email',
  'هنبعت كود على بريدك لو الحساب مسجل.':
      'If your email is registered, we will send a code.',
  'لو الإيميل مسجل ومتاح للإرسال، هتوصلك رسالة.':
      'If your email is registered, a message will arrive shortly.',
  'اكتب كود التفعيل اللي وصلك. حساب الحلاق ينتظر موافقة الإدارة بعد التفعيل.':
      'Enter your email code. Worker accounts also need admin approval.',
  'رقم الموبايل بيتطلب وقت الحجز للتواصل فقط، ومش بديل لتفعيل الإيميل.': 'Your phone is used for booking contact only. Email verification is required.',
  'رقم الموبايل للتواصل فقط، ومش بديل لتفعيل الإيميل.':
      'Your phone is for contact only, not verification.',
  'حساب الحلاق يحتاج موافقة الإدارة. التسجيل لا يفتح بيانات العملاء أو الزيارات.': 'Worker registration requires admin approval before jobs or customer details are available.',
  'عميل': 'Customer',
  'انضم كعامل': 'Join as a barber',
  'حساب خفيف، وزيارات على مزاجك.': 'Your next visit starts here.',
  'حسابك ومساحة شغلك في مكان واحد.': 'Your account and work, in one place.',
  'إطلالتك.\nعلى مزاجك.': 'Your style.\nYour way.',
  'رتّب زيارتك.\nفي خطوات بسيطة.': 'Book a visit.\nKeep it simple.',
  'عناية مرتبة وتفاصيل تفرق. اختار خدمتك وسيب المشوار علينا.':
      'Careful grooming, wherever suits you.',
  'اختار خدمة ومكان ومعاد تطلبه. الإدارة تراجع وتأكد الزيارة معاك.': 'Choose a service, place and requested time. Our team will confirm your visit.',
  'الرئيسية': 'Home',
  'الخدمات': 'Services',
  'حجوزاتي': 'Bookings',
  'المحفوظات': 'Saved',
  'حسابي': 'Account',
  'الزيارات': 'Visits',
  'جدولي': 'Schedule',
  'مساحة العمل': 'Workspace',
  'زياراتي': 'My visits',
  'الجدول': 'Schedule',
  'طلباتك وحالة كل زيارة.': 'Your visits and their latest status.',
  'الحالية': 'Current',
  'السابقة': 'Past',
  'تحميل المزيد': 'Load more',
  'مفيش زيارات سابقة.': 'No past visits yet.',
  'مفيش حجوزات حالية. اختار خدمة واطلب زيارة.':
      'No current bookings. Choose a service to request a visit.',
  'عنايتك بنفسك، في المكان اللي يريحك.': 'Personal care, wherever suits you.',
  'من غير مشوار': 'Skip the trip',
  'حلاقك عندك.\nعلى راحتك.': 'Your barber.\nYour place.',
  'شوف الخدمات ←': 'Explore services',
  'وقت لنفسك': 'Time for yourself',
  'كل الخدمات': 'All services',
  'اختار العناية اللي تناسبك.': 'Find the care that suits you.',
  'دوّر على خدمة': 'Search services',
  'الكل': 'All',
  'حلاقين مميزين': 'Featured barbers',
  'عناية بالتفاصيل، من أول الزيارة لآخر لمسة.':
      'Care in every detail, from start to finish.',
  'اختر خدمة': 'Choose a service',
  'اختار الخدمة': 'Choose service',
  'شوف الخدمات': 'Explore services',
  'استقبال الطلبات مش متاح حاليًا.': 'Bookings are currently unavailable.',
  'الخدمات هتظهر هنا بعد تجهيزها من الإدارة.':
      'Services will appear here when available.',
  'مفيش خدمات مطابقة للبحث ده.': 'No services match your search.',
  'حلاقة وتصفيف': 'Haircut & styling',
  'احفظ خدماتك وحلاقينك المفضلين بعلامة القلب.':
      'Tap the heart to save your favourite services and barbers.',
  'محفوظة على الجهاز ده فقط، ومش بتحدد العامل المسند ليك.':
      'Saved on this device. Your barber is assigned by our team.',
  'تفاصيل الخدمة': 'Service details',
  'عن الخدمة': 'About this service',
  'المدة': 'Duration',
  'السعر': 'Price',
  'سعر الخدمة': 'Service price',
  'الزيارة بتتم إزاي؟': 'How it works',
  'اطلب الزيارة': 'Request visit',
  'اختار المنطقة والمعاد ووافق على مراجعة الطلب.':
      'Choose an area and requested time, then review your request.',
  'رسوم الانتقال بتظهر قبل إرسال الطلب. الإدارة بتختار الحلاق المناسب لزيارتك.': 'Travel fees appear before submission. Our team assigns a barber for your visit.',
  'الإدارة تراجع وتأكد الزيارة وتسند العامل.': 'Our team reviews the request, confirms the visit and assigns your barber.',
  'تفاصيل الزيارة': 'Visit details',
  'الموعد المطلوب': 'Requested time',
  'حالة الدفع': 'Payment status',
  'رقم الطلب': 'Booking reference',
  'قيد المراجعة': 'Pending review',
  'تحت المراجعة': 'Under review',
  'تم التأكيد': 'Confirmed',
  'في الطريق': 'On the way',
  'وصل الحلاق': 'Barber arrived',
  'الخدمة بدأت': 'In progress',
  'مكتملة': 'Completed',
  'ملغاة': 'Cancelled',
  'في أقرب وقت، بعد تأكيد الإدارة': 'As soon as possible, once confirmed',
  'راجع الإدارة لتأكيد الموعد': 'Contact our team to confirm the time',
  'غير مؤكد التحصيل': 'Payment not confirmed',
  'مدفوع': 'Paid',
  'الإجمالي': 'Total',
  'الانتقال': 'Travel',
  'خصم': 'Discount',
  'الحلاق': 'Barber',
  'العميل': 'Customer',
  'الخدمة': 'Service',
  'المنطقة': 'Area',
  'العنوان': 'Address',
  'المكان': 'Place',
  'الدور / الشقة': 'Floor / apartment',
  'الشارع': 'Street',
  'رقم العمارة': 'Building',
  'الشقة': 'Apartment',
  'الدور': 'Floor',
  'طلب زيارة': 'Request a visit',
  'اختار المكان والمعاد اللي تطلبه.': 'Choose your place and requested time.',
  'اسم العميل': 'Customer name',
  'موبايل للتواصل فقط': 'Contact phone',
  'منطقة الخدمة': 'Service area',
  'في البيت': 'At home',
  'في الشغل': 'At work',
  'نوع الزيارة': 'Visit type',
  'معاد مطلوب': 'Scheduled request',
  'في أقرب وقت، بعد المراجعة': 'As soon as possible, after review',
  'اختار يوم تطلبه': 'Choose requested date',
  'اختار اليوم': 'Choose day',
  'اختار الساعة': 'Choose time',
  'تفاصيل المكان والتواصل': 'Address and contact details',
  'علامة مميزة': 'Directions / landmark',
  'طريقة الدفع': 'Payment method',
  'كاش': 'Cash',
  'إنستا باي لحساب الشركة': 'InstaPay to company account',
  'إنستا باي للشركة': 'Company InstaPay',
  'لا تحول أي مبلغ قبل استلام بيانات الشركة المؤكدة من الإدارة. اختيار الطريقة لا يعني الدفع.': 'Do not transfer money before our team confirms the company payment details. Selecting a method does not mean paid.',
  'فاهم إن ده طلب زيارة، والتأكيد بعد مراجعة الإدارة.':
      'I understand this is a request and is subject to confirmation.',
  'مراجعة السعر وإرسال الطلب': 'Review price and submit',
  'راجع طلب الزيارة': 'Review visit request',
  'إرسال الطلب': 'Submit request',
  'طلبك اتسجل': 'Request received',
  'طلبك عند الإدارة': 'Your request is with our team',
  'شوف حجوزاتي': 'View bookings',
  'الإدارة هتراجع التفاصيل وتأكد الزيارة معاك. ده مش تأكيد توفر أو تحصيل دفع.': 'Our team will review and confirm the visit. Availability and payment are not yet confirmed.',
  'راجع الإجمالي بعد اختيار المنطقة.': 'Choose an area to review the total.',
  'الأيام الظاهرة لا تعني توفر مواعيد. التأكيد بعد مراجعة الإدارة.': 'Dates shown are not confirmed availability. Our team reviews every request.',
  'الطلب يتأكد بعد مراجعة الإدارة. كل الأوقات بتوقيت القاهرة.':
      'Requests are subject to confirmation. All times are Cairo time.',
  'حسابك وتفاصيلك، في مكان واحد.': 'Your account, in one place.',
  'بيانات الحساب': 'Account details',
  'فريق رايق': 'Rayeq team',
  'عميل رايق': 'Rayeq customer',
  'تغيير الصورة': 'Change photo',
  'حذف الصورة': 'Remove photo',
  'تعديل بياناتك': 'Edit details',
  'تعديل الملف الشخصي': 'Edit profile',
  'الاسم': 'Name',
  'موبايل التواصل': 'Contact phone',
  'غير مضاف': 'Not added',
  'حالة البريد': 'Email status',
  'مفعّل': 'Verified',
  'غير مفعّل': 'Not verified',
  'حالة الانضمام': 'Approval status',
  'حلاق معتمد': 'Approved barber',
  'في انتظار موافقة الإدارة': 'Awaiting admin approval',
  'المهارات': 'Services',
  'مناطق العمل': 'Work areas',
  'الأمان': 'Security',
  'استعادة أو تغيير كلمة المرور': 'Reset or change password',
  'حفظ': 'Save',
  'موبايل للتواصل (اختياري)': 'Contact phone (optional)',
  'الإيميل ونوع الحساب مش قابلين للتغيير هنا.':
      'Email and account type cannot be changed here.',
  'ملف الحلاق': 'Barber profile',
  'التقييم': 'Rating',
  'مراجعات': 'Reviews',
  'سنوات خبرة': 'Years of experience',
  'عن الحلاق': 'About the barber',
  'المراجعات': 'Reviews',
  'الإدارة بتختار الحلاق المناسب لخدمتك وموعدك.':
      'Our team assigns a barber to suit your service and time.',
  'جرّب تاني': 'Try again',
  'حصلت مشكلة، جرّب مرة تانية.': 'Something went wrong. Try again.',
  'تعذر الاتصال. جرّب تاني.': 'Could not connect. Try again.',
  'تعذر إرسال الطلب. جرّب تاني.': 'Could not submit. Try again.',
  'اكتب إيميل صحيح وكلمة مرور ١٠ أحرف على الأقل.':
      'Enter a valid email and a password of at least 10 characters.',
  'اكتب اسمك الأول.': 'Enter your name.',
  'تعذر حفظ المفضلة على الجهاز.': 'Could not save favourites on this device.',
  'تعذر تحميل تفاصيل الزيارة.': 'Could not load visit details.',
  'تعذر تحميل كل بيانات الحساب.': 'Could not load all account details.',
  'تعذر حفظ التغييرات.': 'Could not save changes.',
  'اتحفظت بياناتك.': 'Your details have been saved.',
  'التحقق من التحديثات': 'Check for updates',
  'أنت على أحدث نسخة متاحة.': 'You are on the latest version.',
  'نسخة جديدة من رايق': 'A new version of Rayeq',
  'التحديث مطلوب': 'Update required',
  'مش دلوقتي': 'Not now',
  'تنزيل وتثبيت التحديث': 'Download and install',
  'متابعة التثبيت': 'Continue installation',
  'جاري تنزيل التحديث والتحقق من سلامته…':
      'Downloading and verifying the update…',
  'جاري فتح مثبت أندرويد…': 'Opening Android installer…',
  'لازم تحدّث النسخة عشان تكمل استخدام التطبيق.': 'Update the app to continue.',
  'نزّل التحديث من داخل التطبيق. أندرويد هيطلب منك تأكيد التثبيت.':
      'Download the update here. Android will ask you to confirm installation.',
  'فعّل السماح بالتثبيت من رايق في إعدادات أندرويد، وارجع اضغط متابعة التثبيت.': 'Allow Rayeq to install updates in Android settings, then return and continue.',
  'كمّل التأكيد من شاشة أندرويد. بيانات حسابك هتفضل موجودة بعد التحديث.':
      'Confirm in Android. Your account data stays after the update.',
  'تحسينات وتحديثات للتطبيق.': 'App improvements and updates.',
  'مفيش تحديثات إضافية.': 'No additional updates.',
};

const extraEnglish = <String, String>{
  'الموعد يتأكد مع الإدارة': 'Our team will confirm the time',
  'تفاصيلك، على راحتك.': 'Your details, your way.',
  'حساب تجربة': 'Account',
  'غير معتمد': 'Not approved',
  'الزيارات بتتسند ليك من الإدارة. بيانات العملاء متاحة للزيارات المسندة ليك فقط.': 'Our team assigns your visits. Customer details are available for assigned visits only.',
  'رايق · حلاقك عندك': 'Rayeq · Your barber, at your door',
  'الموبايل': 'Phone',
  'جهة العمل': 'Workplace',
  'تفاصيل الحساب': 'Price breakdown',
  'بانتظار المراجعة': 'Pending review',
  'حالة الزيارة منفصلة عن حالة تحصيل الدفع.':
      'Visit status and payment status are separate.',
  'متابعة الطلب': 'Visit updates',
  'رابط التحديث مش جاهز حاليًا. جرّب لاحقًا.':
      'The update is not ready to download yet. Try again later.',
  'تعذر التحقق من التحديثات. اتأكد من الإنترنت وجرّب تاني.':
      'Could not check for updates. Check your connection and try again.',
  'التحديث مكملش أو التحقق من الملف فشل. مفيش ملف غير موثوق اتفتح. جرّب تاني.': 'The update could not be verified or completed. No unverified package was opened. Try again.',
  'تعذر تنزيل التحديث أو فتح المثبت. جرّب تاني.':
      'Could not download the update or open the installer. Try again.',
  'جاري التحديث…': 'Updating…',
  'تعذر حفظ جلسة الدخول. جرّب تاني.': 'Could not save your session. Try again.',
  'الخدمة قيد التجهيز، جرّب مرة تانية بعد شوية.':
      'The service is being set up. Try again shortly.',
  'تعذر الاتصال الآمن بالخدمة.': 'Could not connect securely.',
  'الاتصال اتأخر. اتأكد من الإنترنت وجرّب تاني.':
      'The connection timed out. Check your internet and try again.',
  'الخدمة مش متاحة دلوقتي. جرّب بعد شوية.':
      'The service is unavailable right now. Try again shortly.',
  'فعّل بريدك الإلكتروني الأول.': 'Verify your email first.',
  'الإيميل أو كلمة المرور مش صحيحة.': 'Email or password is incorrect.',
  'حساب الحلاق في انتظار موافقة الإدارة.':
      'Your barber account is awaiting approval.',
  'السعر اتحدث. راجع السعر الجديد قبل تأكيد الطلب.':
      'The price changed. Review it before submitting.',
  'حالة الزيارة اتغيرت. حدّث الصفحة وجرّب تاني.':
      'This visit changed. Refresh and try again.',
  'راجع البيانات المطلوبة وجرّب تاني.':
      'Check the required details and try again.',
  'طلبات كتير في وقت قصير. استنى شوية وجرّب تاني.':
      'Too many requests. Wait a moment and try again.',
  'الحساب ده معندوش صلاحية للخطوة دي.':
      'Your account does not have permission for this action.',
  'سجّل دخولك عشان تكمل.': 'Sign in to continue.',
  'الكود مش صحيح أو انتهت صلاحيته.': 'The code is incorrect or expired.',
  'إرسال الإيميل مش متاح حاليًا، جرّب لاحقًا.':
      'Email delivery is unavailable. Try again later.',
  'استنى شوية قبل المحاولة التالية.': 'Wait a moment before trying again.',
  'الطلب مكملش. جرّب مرة تانية أو تواصل مع الإدارة.':
      'The request could not be completed. Try again or contact our team.',
  'الصورة كبيرة. اختار صورة أصغر من ٢ ميجا.':
      'Choose an image smaller than 2 MB.',
  'اختار صورة أصغر من ٢ ميجا.': 'Choose an image smaller than 2 MB.',
  'تعذر تحديث الصورة. جرّب تاني.': 'Could not update the photo. Try again.',
  'تعديل الحساب قيد التجهيز. بيانات حسابك الحالية ظاهرة هنا.': 'Profile editing is not available yet. Your current details are shown here.',
  'اختار صورة JPEG أو PNG أو WebP.': 'Choose a JPEG, PNG or WebP image.',
  'تعذر فتح أو حفظ الصورة. جرّب صورة تانية.':
      'Could not open or save this image. Try another.',
  'الإدارة بتسند الزيارات ليك. بيانات العملاء متاحة لمهامك فقط، وإكمال الزيارة مش تأكيد لتحصيل الدفع.': 'Your team assigns visits. Customer details are for your assigned work only. Completing a visit does not confirm payment.',
  'حساب إدارة': 'Admin account',
  'لوحة الإدارة متاحة على الويب. استخدم حساب عميل للحجز.':
      'The admin dashboard is on the web. Use a customer account to book.',
  'إيميلك اتفعّل، وحساب الحلاق في انتظار الموافقة. بيانات الزيارات هتظهر بعد موافقة الإدارة وإسناد مهام ليك.': 'Your email is verified. Your barber account is awaiting approval. Assigned visits will appear after approval.',
  'تحديث حالة الحساب': 'Refresh account status',
  'استقبال الطلبات غير متاح حاليًا.': 'Bookings are currently unavailable.',
  'المهام المسندة ليك فقط. إكمال الزيارة لا يعني تحصيل الدفع.':
      'Your assigned visits and their latest status.',
  'المواعيد المسندة خلال ٣٠ يومًا بتوقيت القاهرة.':
      'Assigned visits over the next 30 days. All times are Cairo time.',
  'مفيش مواعيد مسندة في الفترة دي.': 'No assigned visits in this period.',
  'مفيش زيارات في القائمة دي.': 'No visits in this list.',
  'مطلوب': 'Required',
  'تابع زياراتك وحدّث حالتها.':
      'Track your assigned visits and update their status.',
  'عناية بالشعر': 'Hair care',
  'العناية بالشعر': 'Hair care',
  'شعر': 'Hair',
  'ذقن': 'Beard',
  'باقات': 'Packages',
  'في أقرب وقت بعد المراجعة': 'As soon as possible, after review',
  'الحي الأول': 'District One',
  'شارع النخيل': 'Palm Street',
  'بجوار الحديقة': 'Beside the park',
  'حلاقة مرتبة وتصفيف يناسبك، مع عناية بكل التفاصيل.':
      'A clean cut and a style that suits you, with care in every detail.',
  'عميل': 'Customer',
  'حلاق': 'Barber',
  'احجز زيارتك': 'Book a visit',
  'انضم للفريق': 'Join the team',
  'حسابك الجديد': 'Create your account',
  'انضم لفريق رايق': 'Join the Rayeq team',
  'اختار خدمتك واحجز زيارتك في خطوات بسيطة.':
      'Choose your service and request a visit in a few simple steps.',
  'خلّي خبرتك توصل لعملاء أكتر.': 'Bring your skills to more customers.',
  'هنبعت كود تفعيل على إيميلك بعد التسجيل.':
      'We will email a verification code after sign-up.',
  'بعد تفعيل الإيميل، الإدارة بتراجع طلبك قبل أول زيارة.': 'After email verification, our team reviews your application before you receive visits.',
  'إنشاء حساب عميل': 'Create customer account',
  'إنشاء حساب حلاق': 'Create barber account',
  'إظهار كلمة المرور': 'Show password',
  'إخفاء كلمة المرور': 'Hide password',
  '١٠ أحرف على الأقل': 'At least 10 characters',
  'اكتب الكود اللي وصلك على إيميلك.': 'Enter the code sent to your email.',
  'تفاصيل الزيارة وحالة الدفع': 'Visit and payment details',
  'لسه ما اتدفعش': 'Not paid yet',
  'إصدار': 'Version',
  'تغيير اللغة': 'Change language',
  'جلسة الدخول انتهت. سجّل دخولك تاني.': 'Your session expired. Sign in again.',
  'عن رايق': 'About Rayeq',
  'سياسة الخصوصية': 'Privacy policy',
};
