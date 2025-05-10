import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppLocalization extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      // General
      'app_name': 'Smart Campus',
      
      // Auth
      'login': 'Log In',
      'register': 'Register',
      'forgot_password': 'Forgot Password?',
      'email': 'Email',
      'username': 'Username',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'grade': 'Grade',
      'department': 'Department',
      'profile_photo': 'Profile Photo',
      'already_have_account': 'Already have an account?',
      'dont_have_account': 'Don\'t have an account?',
      
      // New Auth Features
      'change_email': 'Change Email',
      'current_email': 'Current Email',
      'new_email': 'New Email',
      'update_email': 'Update Email',
      'multi_factor_auth': 'Multi-Factor Authentication',
      'verification_code': 'Verification Code',
      'enable_mfa': 'Enable MFA',
      'reset_password': 'Reset Password',
      'send_reset_link': 'Send Reset Link',
      'back_to_login': 'Back to Login',
      'security_settings': 'Security Settings',
      'account_settings': 'Account Settings',
      
      // Home
      'map': 'Map',
      'events': 'Events',
      'calendar': 'Calender',
      'settings': 'Settings',
      'classroom_finder': 'Classroom Finder',
      'cafeteria_info': 'Cafeteria Info',
      'emergency': 'Emergency',
      
      // Map
      'search_location': 'Search for a location',
      'my_location': 'My Location',
      'lecture_halls': 'Lecture Halls',
      'floor_info': 'Floor Information',
      
      // Events
      'add_event': 'Add Event',
      'event_title': 'Event Title',
      'event_description': 'Event Description',
      'event_date': 'Date',
      'event_time': 'Time',
      'event_location': 'Location',
      'upcoming_events': 'Upcoming Events',
      'past_events': 'Past Events',
      'lectures': 'Lectures',
      
      // Settings
      'language': 'Language',
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'notifications': 'Notifications',
      'about': 'About',
      'logout': 'Logout',
      
      // Error Messages
      'network_error': 'Please check your internet connection',
      'unknown_error': 'An unknown error occurred',
      'auth_error': 'Authentication failed',
    },
    'ar': {
      // General
      'app_name': 'الحرم الذكي',
      
      // Auth
      'login': 'تسجيل الدخول',
      'register': 'إنشاء حساب',
      'forgot_password': 'نسيت كلمة المرور؟',
      'email': 'البريد الإلكتروني',
      'username': 'اسم المستخدم',
      'password': 'كلمة المرور',
      'confirm_password': 'تأكيد كلمة المرور',
      'grade': 'الدرجة',
      'department': 'القسم',
      'profile_photo': 'صورة الملف الشخصي',
      'already_have_account': 'لديك حساب بالفعل؟',
      'dont_have_account': 'ليس لديك حساب؟',
      
      // New Auth Features
      'change_email': 'تغيير البريد الإلكتروني',
      'current_email': 'البريد الإلكتروني الحالي',
      'new_email': 'البريد الإلكتروني الجديد',
      'update_email': 'تحديث البريد الإلكتروني',
      'multi_factor_auth': 'المصادقة متعددة العوامل',
      'verification_code': 'رمز التحقق',
      'enable_mfa': 'تفعيل المصادقة متعددة العوامل',
      'reset_password': 'إعادة تعيين كلمة المرور',
      'send_reset_link': 'إرسال رابط إعادة التعيين',
      'back_to_login': 'العودة إلى تسجيل الدخول',
      'security_settings': 'إعدادات الأمان',
      'account_settings': 'إعدادات الحساب',
      
      // Home
      'map': 'الخريطة',
      'events': 'الفعاليات',
      'calendar': 'التقويم',
      'settings': 'الإعدادات',
      'classroom_finder': 'الباحث عن الفصول',
      'cafeteria_info': 'معلومات الكافتيريا',
      'emergency': 'الطوارئ',
      
      // Map
      'search_location': 'ابحث عن موقع',
      'my_location': 'موقعي',
      'lecture_halls': 'قاعات المحاضرات',
      'floor_info': 'معلومات الطابق',
      
      // Events
      'add_event': 'إضافة فعالية',
      'event_title': 'عنوان الفعالية',
      'event_description': 'وصف الفعالية',
      'event_date': 'التاريخ',
      'event_time': 'الوقت',
      'event_location': 'المكان',
      'upcoming_events': 'الفعاليات القادمة',
      'past_events': 'الفعاليات السابقة',
      'lectures': 'المحاضرات',
      
      // Settings
      'language': 'اللغة',
      'theme': 'المظهر',
      'dark_mode': 'الوضع الداكن',
      'light_mode': 'الوضع الفاتح',
      'notifications': 'الإشعارات',
      'about': 'حول',
      'logout': 'تسجيل الخروج',
      
      // Error Messages
      'network_error': 'يرجى التحقق من اتصال الإنترنت',
      'unknown_error': 'حدث خطأ غير معروف',
      'auth_error': 'فشل في المصادقة',
    },
  };
}

class LocalizationService {
  static final LocalizationService _singleton = LocalizationService._internal();
  
  factory LocalizationService() {
    return _singleton;
  }
  
  LocalizationService._internal();
  
  static const Locale enLocale = Locale('en', 'US');
  static const Locale arLocale = Locale('ar', 'EG');
  
  static const List<Locale> supportedLocales = [
    enLocale,
    arLocale,
  ];
  
  static const String localeStorageKey = 'locale';
  
  static void changeLocale(String langCode) {
    Locale locale = _getLocaleFromLanguage(langCode);
    Get.updateLocale(locale);
  }
  
  static Locale _getLocaleFromLanguage(String langCode) {
    switch (langCode) {
      case 'en':
        return enLocale;
      case 'ar':
        return arLocale;
      default:
        return enLocale;
    }
  }
  
  static String getLanguageName(String langCode) {
    switch (langCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }
} 