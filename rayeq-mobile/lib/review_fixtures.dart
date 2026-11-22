// Web review fixtures. No live account, storage or network effects.
import 'dart:typed_data';

import 'api.dart';
import 'localization.dart';

const reviewService = {
  'id': 'preview-hair',
  'nameAr': 'حلاقة وتصفيف',
  'nameEn': 'Haircut & styling',
  'descriptionAr': 'قصة مرتبة وتصفيف يناسبك، بعناية بكل التفاصيل.',
  'descriptionEn': 'A precise cut and styling, with care in every detail.',
  'category': 'hair',
  'categoryEn': 'Haircut',
  'priceMinor': 20000,
  'durationMinutes': 45,
  'version': 1,
  'englishReady': true,
};
const reviewArea = {
  'id': 'preview-area',
  'nameAr': 'وسط البلد',
  'nameEn': 'Central Cairo',
  'version': 1,
  'englishReady': true,
};
const reviewCatalog = {
  'intakeEnabled': true,
  'isDemo': true,
  'instapayAvailable': true,
  'services': [
    reviewService,
    {
      'id': 'preview-beard',
      'nameAr': 'العناية بالذقن',
      'nameEn': 'Beard care',
      'descriptionAr': 'تحديد وعناية بالذقن.',
      'descriptionEn': 'Beard shaping and care.',
      'category': 'beard',
      'categoryEn': 'Beard',
      'priceMinor': 12000,
      'durationMinutes': 30,
      'version': 1,
      'englishReady': true,
    },
  ],
  'areas': [reviewArea],
};
const reviewBarber = {
  'id': 'preview-barber',
  'nameAr': 'أحمد حسن',
  'nameEn': 'Ahmed Hassan',
  'availabilityStatus': 'available',
  'ratingAverage': null,
  'reviewCount': 0,
  'approximateDistance': {'minKm': 2, 'maxKm': 4},
  'demoOnly': true,
};
Map<String, dynamic> reviewBooking({bool completed = false}) => {
  'id': 'preview-booking',
  'reference': 'RAY-PREVIEW',
  'status': completed ? 'COMPLETED' : 'CONFIRMED',
  'version': 1,
  'service': reviewService,
  'area': reviewArea,
  'requestedAt': '2026-11-23T10:00:00Z',
  'startAt': '2026-11-23T10:00:00Z',
  'endAt': '2026-11-23T10:45:00Z',
  'customerName': appLocale.value.languageCode == 'en'
      ? 'Karim Ahmed'
      : 'كريم أحمد',
  'contactPhone': '+201000000000',
  'locationType': 'home',
  'bookingType': 'scheduled',
  'address': {
    'street': appLocale.value.languageCode == 'en'
        ? 'Museum Street'
        : 'شارع المعرض',
    'building': '12',
    'floor': '2',
    'apartment': '5',
  },
  'price': {'serviceMinor': 20000, 'travelMinor': 3000, 'totalMinor': 23000},
  'payment': {'method': 'cash', 'status': 'UNPAID'},
  'assignedWorker': {
    'id': 'preview-barber',
    'name': 'أحمد حسن',
    'nameEn': 'Ahmed Hassan',
  },
  'history': [
    {'status': 'CONFIRMED', 'at': '2026-11-22T16:00:00Z'},
  ],
  'canReview': completed,
  'review': null,
  'demoOnly': true,
};

class ReviewApi extends RayeqApi {
  String role;
  bool authenticated, reviewed = false;
  String availability = 'offline';
  Uint8List? avatar;
  ReviewApi({this.role = 'customer', this.authenticated = true})
    : super(baseUrl: 'https://preview.invalid/api/v1');
  @override
  bool get signedIn => authenticated;
  @override
  Future<void> restore() async {}
  @override
  Future<void> saveSession(Map<String, dynamic> session) async {
    authenticated = true;
  }

  @override
  Future<void> forgetSession() async {
    authenticated = false;
  }

  Map<String, dynamic> get user => {
    'id': 'preview-$role',
    'role': role,
    'name': role == 'worker' ? 'أحمد حسن' : 'كريم أحمد',
    'displayNameEn': role == 'worker' ? 'Ahmed Hassan' : 'Karim Ahmed',
    'email': role == 'worker'
        ? 'worker-test@rayeq.invalid'
        : 'customer-test@rayeq.invalid',
    'phone': '+201000000000',
    'emailVerified': true,
    'hasAvatar': avatar != null,
    'workerProfile': {
      'employeeName': 'أحمد حسن',
      'employeeNameEn': 'Ahmed Hassan',
    },
  };
  @override
  Future<Uint8List?> getAvatar() async => avatar;
  @override
  Future<void> uploadAvatar(Uint8List bytes, String contentType) async {
    avatar = bytes;
  }

  @override
  Future<void> deleteAvatar() async {
    avatar = null;
  }

  @override
  Future<Map<String, dynamic>> uploadWorkPhoto(
    Uint8List bytes,
    String contentType,
  ) async => throw const ApiFailure(
    'PREVIEW_ONLY',
    'دي معاينة للتصميم فقط. افتح التطبيق المتصل لرفع صورة فعلية.',
  );
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    if (path == 'me' || path == 'profile')
      return {...user, if (method == 'PATCH') ...?body};
    if (path == 'catalog') return reviewCatalog;
    if (path == 'auth/login') return {'token': 'local-preview-only'};
    if (path.startsWith('auth/')) return <String, dynamic>{'next': 'verify'};
    if (path == 'worker/availability') {
      if (method == 'PATCH')
        availability = '${body?['availabilityStatus'] ?? availability}';
      return {
        'availabilityStatus': availability,
        'effectiveAvailabilityStatus': availability,
        'hasCoarseZone': false,
        'isFresh': availability != 'offline',
      };
    }
    if (path == 'barbers/nearby')
      return {
        'mode': body?['latitude'] == null ? 'area' : 'location',
        'barbers': [reviewBarber],
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
        'demoOnly': true,
        'availabilityIsPreview': true,
      };
    if (path == 'barbers/featured')
      return {
        'items': [],
      };
    if (path == 'worker/rating')
      return {'ratingAverage': null, 'reviewCount': 0, 'demoOnly': true};
    if (path.endsWith('/gallery')) return {'items': [], 'maxPhotos': 6};
    if (path.endsWith('/reviews'))
      return {
        'items': [],
        'nextCursor': null,
        'ratingAverage': null,
        'reviewCount': 0,
      };
    if (path.startsWith('barbers/')) return reviewBarber;
    if (path == 'quotes')
      return {
        'serviceVersion': 1,
        'areaVersion': 1,
        'totalMinor': 23000,
        'serviceNameEn': 'Haircut & styling',
      };
    if (path == 'bookings' && method == 'POST')
      return {
        ...reviewBooking(),
        'status': body?['preferredBarberId'] == null ? 'PENDING' : 'CONFIRMED',
        'assignmentMode': body?['preferredBarberId'] == null
            ? 'MANAGED'
            : 'CUSTOMER_SELECTED',
        'requiresAdminApproval': body?['preferredBarberId'] == null,
      };
    if (path == 'bookings' || path == 'worker/bookings')
      return {
        'items': [reviewBooking(completed: query?['scope'] == 'past')],
        'nextCursor': null,
      };
    if (path == 'worker/schedule')
      return {
        'items': [
          {
            'serviceNameAr': 'حلاقة وتصفيف',
            'serviceNameEn': 'Haircut & styling',
            'areaNameAr': 'وسط البلد',
            'areaNameEn': 'Central Cairo',
            'startAt': '2026-11-23T10:00:00Z',
            'status': 'CONFIRMED',
            'reference': 'RAY-PREVIEW',
          },
        ],
      };
    if (path.endsWith('/review') && method == 'POST') {
      reviewed = true;
      return {
        'id': 'preview-review',
        'rating': body?['rating'],
        'text': body?['text'],
        'demoOnly': true,
      };
    }
    if (path.startsWith('bookings/'))
      return {...reviewBooking(completed: true), 'canReview': !reviewed};
    if (path.startsWith('worker/bookings/')) return reviewBooking();
    if (method == 'DELETE') return null;
    return <String, dynamic>{};
  }
}
