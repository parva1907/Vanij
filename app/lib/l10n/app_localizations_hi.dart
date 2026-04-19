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

  @override
  String get inventoryAddItem => 'सामान जोड़ें';

  @override
  String get inventoryEditItem => 'सामान बदलें';

  @override
  String get inventorySearchHint => 'सामान खोजें';

  @override
  String get inventoryFilterCategory => 'श्रेणी';

  @override
  String get inventoryFilterColor => 'रंग';

  @override
  String get inventoryFilterAll => 'सभी';

  @override
  String get inventoryFieldName => 'नाम';

  @override
  String get inventoryFieldCategory => 'श्रेणी';

  @override
  String get inventoryFieldPattern => 'पैटर्न (वैकल्पिक)';

  @override
  String get inventoryFieldPrice => 'बिक्री मूल्य';

  @override
  String get inventoryFieldCostPrice => 'लागत मूल्य';

  @override
  String get inventoryFieldSizes => 'साइज़';

  @override
  String get inventoryFieldColors => 'रंग';

  @override
  String get inventoryFieldQuantity => 'संख्या';

  @override
  String get inventoryFieldImage => 'फ़ोटो';

  @override
  String get inventoryChooseFromCamera => 'कैमरा';

  @override
  String get inventoryChooseFromGallery => 'गैलरी';

  @override
  String get inventorySave => 'सहेजें';

  @override
  String get inventoryDelete => 'हटाएँ';

  @override
  String get inventoryDeleteConfirmTitle => 'सामान हटाएँ?';

  @override
  String get inventoryDeleteConfirmBody => 'यह वापस नहीं होगा।';

  @override
  String get inventoryLowStockChip => 'स्टॉक कम';

  @override
  String get inventoryNoResults => 'इस फ़िल्टर से कोई सामान नहीं मिला।';

  @override
  String get inventoryLoadMore => 'और दिखाएँ';

  @override
  String get inventoryValidationNameRequired => 'नाम ज़रूरी है।';

  @override
  String get inventoryValidationPriceInvalid => 'सही बिक्री मूल्य दर्ज करें।';

  @override
  String get inventoryValidationCostPriceInvalid => 'सही लागत मूल्य दर्ज करें।';

  @override
  String get inventoryValidationNeedAtLeastOneSize =>
      'कम से कम एक साइज़ जोड़ें।';

  @override
  String get inventoryValidationImageRequired => 'फ़ोटो जोड़ें।';

  @override
  String get inventoryUploadingImage => 'फ़ोटो अपलोड हो रही है…';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonRetry => 'फिर कोशिश करें';

  @override
  String get commonSaving => 'सहेज रहे हैं…';

  @override
  String get financeToday => 'आज';

  @override
  String financeTodayBreakdown(Object sales, Object refunds, Object expenses) {
    return 'बिक्री $sales · वापसी $refunds · खर्च $expenses';
  }

  @override
  String get financeWeekPnl => 'पिछले 7 दिनों का लाभ/हानि';

  @override
  String get financeTopItems => 'इस हफ़्ते सबसे ज़्यादा बिके';

  @override
  String get financeTopItemsEmpty => 'इस हफ़्ते अभी कोई जुड़ी हुई बिक्री नहीं।';

  @override
  String get financeAddEntry => 'नया लेन-देन';

  @override
  String get financeEntrySaved => 'लेन-देन खाते में सहेजा गया।';

  @override
  String get financeEntryType => 'प्रकार';

  @override
  String get financeTypeSale => 'बिक्री';

  @override
  String get financeTypeExpense => 'खर्च';

  @override
  String get financeTypeRefund => 'वापसी';

  @override
  String get financeFieldAmount => 'रक़म';

  @override
  String get financeFieldDate => 'तारीख़';

  @override
  String get financeFieldNote => 'नोट (वैकल्पिक)';

  @override
  String get financeFieldItemRef => 'जुड़ा हुआ सामान आईडी (वैकल्पिक)';

  @override
  String get financeFieldItemRefHint => 'किसी विशेष सामान की बिक्री के लिए।';

  @override
  String get financeFieldUpiRef => 'UPI रेफ़रेंस (वैकल्पिक)';

  @override
  String get financeFieldUpiRefHint =>
      'डिवाइस पर एन्क्रिप्ट करके सहेजा जाता है — कभी भी प्लेन टेक्स्ट में नहीं।';

  @override
  String get financeValidationAmountRequired => 'रक़म ज़रूरी है।';

  @override
  String get financeValidationAmountInvalid => 'सही रक़म दर्ज करें।';

  @override
  String get financeLedgerTitle => 'खाता-बही';

  @override
  String get financeViewLedger => 'खाता-बही देखें';

  @override
  String get financeExportCsv => 'पिछले 30 दिन CSV डाउनलोड';

  @override
  String get financeExportCsvSubject => 'वणिज् खाता-बही';

  @override
  String get financeFilterAll => 'सभी';
}
