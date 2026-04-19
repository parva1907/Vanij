// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'वणिज्';

  @override
  String get appTagline => 'भारत की रीढ़ के लिए।';

  @override
  String get signIn => 'लॉगिन';

  @override
  String get signUp => 'खाता बनाएँ';

  @override
  String get signOut => 'लॉगआउट';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get shopName => 'दुकान का नाम';

  @override
  String get continueWithGoogle => 'Google से जारी रखें';

  @override
  String get navInventory => 'स्टॉक';

  @override
  String get navCustomers => 'ग्राहक';

  @override
  String get navFinance => 'हिसाब';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get emptyInventoryTitle => 'अभी कोई सामान नहीं';

  @override
  String get emptyInventorySubtitle => 'पहला आइटम जोड़ने के लिए + दबाएँ।';

  @override
  String get emptyCustomersTitle => 'अभी कोई ग्राहक नहीं';

  @override
  String get emptyCustomersSubtitle => 'चैट यहाँ दिखेंगी।';

  @override
  String get emptyFinanceTitle => 'अभी कोई लेन-देन नहीं';

  @override
  String get emptyFinanceSubtitle => 'अपनी पहली बिक्री दर्ज करें।';

  @override
  String get genericError => 'कुछ गलत हुआ। कृपया फिर से कोशिश करें।';

  @override
  String get invalidEmail => 'कृपया सही ईमेल दर्ज करें।';

  @override
  String get weakPassword => 'पासवर्ड कम से कम 8 अक्षर का हो।';

  @override
  String get shopNameRequired => 'कृपया दुकान का नाम दर्ज करें।';
}
