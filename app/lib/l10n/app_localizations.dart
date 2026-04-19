import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Vanij'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Built for the backbone of India.'**
  String get appTagline;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get shopName;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @emptyInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get emptyInventoryTitle;

  /// No description provided for @emptyInventorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first item.'**
  String get emptyInventorySubtitle;

  /// No description provided for @emptyCustomersTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get emptyCustomersTitle;

  /// No description provided for @emptyCustomersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chats will appear here.'**
  String get emptyCustomersSubtitle;

  /// No description provided for @emptyFinanceTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get emptyFinanceTitle;

  /// No description provided for @emptyFinanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record your first sale to begin.'**
  String get emptyFinanceSubtitle;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericError;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email.'**
  String get invalidEmail;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get weakPassword;

  /// No description provided for @shopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your shop name.'**
  String get shopNameRequired;

  /// No description provided for @inventoryAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get inventoryAddItem;

  /// No description provided for @inventoryEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get inventoryEditItem;

  /// No description provided for @inventorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get inventorySearchHint;

  /// No description provided for @inventoryFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get inventoryFilterCategory;

  /// No description provided for @inventoryFilterColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get inventoryFilterColor;

  /// No description provided for @inventoryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get inventoryFilterAll;

  /// No description provided for @inventoryFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get inventoryFieldName;

  /// No description provided for @inventoryFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get inventoryFieldCategory;

  /// No description provided for @inventoryFieldPattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern (optional)'**
  String get inventoryFieldPattern;

  /// No description provided for @inventoryFieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get inventoryFieldPrice;

  /// No description provided for @inventoryFieldCostPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get inventoryFieldCostPrice;

  /// No description provided for @inventoryFieldSizes.
  ///
  /// In en, this message translates to:
  /// **'Sizes'**
  String get inventoryFieldSizes;

  /// No description provided for @inventoryFieldColors.
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get inventoryFieldColors;

  /// No description provided for @inventoryFieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get inventoryFieldQuantity;

  /// No description provided for @inventoryFieldImage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get inventoryFieldImage;

  /// No description provided for @inventoryChooseFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get inventoryChooseFromCamera;

  /// No description provided for @inventoryChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get inventoryChooseFromGallery;

  /// No description provided for @inventorySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get inventorySave;

  /// No description provided for @inventoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get inventoryDelete;

  /// No description provided for @inventoryDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get inventoryDeleteConfirmTitle;

  /// No description provided for @inventoryDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get inventoryDeleteConfirmBody;

  /// No description provided for @inventoryLowStockChip.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get inventoryLowStockChip;

  /// No description provided for @inventoryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No items match this filter.'**
  String get inventoryNoResults;

  /// No description provided for @inventoryLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get inventoryLoadMore;

  /// No description provided for @inventoryValidationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get inventoryValidationNameRequired;

  /// No description provided for @inventoryValidationPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price.'**
  String get inventoryValidationPriceInvalid;

  /// No description provided for @inventoryValidationCostPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid cost price.'**
  String get inventoryValidationCostPriceInvalid;

  /// No description provided for @inventoryValidationNeedAtLeastOneSize.
  ///
  /// In en, this message translates to:
  /// **'Add at least one size.'**
  String get inventoryValidationNeedAtLeastOneSize;

  /// No description provided for @inventoryValidationImageRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a photo.'**
  String get inventoryValidationImageRequired;

  /// No description provided for @inventoryUploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get inventoryUploadingImage;

  /// No description provided for @inventoryAddWithAi.
  ///
  /// In en, this message translates to:
  /// **'Scan with AI'**
  String get inventoryAddWithAi;

  /// No description provided for @tagConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm tags'**
  String get tagConfirmTitle;

  /// No description provided for @tagConfirmLoading.
  ///
  /// In en, this message translates to:
  /// **'Asking the AI to look at your photo…'**
  String get tagConfirmLoading;

  /// No description provided for @tagConfirmHeadline.
  ///
  /// In en, this message translates to:
  /// **'Review the AI suggestions'**
  String get tagConfirmHeadline;

  /// No description provided for @tagConfirmSubheadline.
  ///
  /// In en, this message translates to:
  /// **'Nothing is saved until you tap Continue. Edit anything that looks wrong.'**
  String get tagConfirmSubheadline;

  /// No description provided for @tagConfirmContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get tagConfirmContinue;

  /// No description provided for @tagConfirmSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip AI suggestions'**
  String get tagConfirmSkip;

  /// Inline hint next to a form field showing what the AI suggested.
  ///
  /// In en, this message translates to:
  /// **'AI: {value}'**
  String tagConfirmAiSuggested(String value);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// No description provided for @financeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get financeToday;

  /// No description provided for @financeTodayBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Sales {sales} · Refunds {refunds} · Expenses {expenses}'**
  String financeTodayBreakdown(Object sales, Object refunds, Object expenses);

  /// No description provided for @financeWeekPnl.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days P&L'**
  String get financeWeekPnl;

  /// No description provided for @financeTopItems.
  ///
  /// In en, this message translates to:
  /// **'Top items this week'**
  String get financeTopItems;

  /// No description provided for @financeTopItemsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No linked sales this week yet.'**
  String get financeTopItemsEmpty;

  /// No description provided for @financeAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get financeAddEntry;

  /// No description provided for @financeEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Entry saved to ledger.'**
  String get financeEntrySaved;

  /// No description provided for @financeEntryType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get financeEntryType;

  /// No description provided for @financeTypeSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get financeTypeSale;

  /// No description provided for @financeTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get financeTypeExpense;

  /// No description provided for @financeTypeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get financeTypeRefund;

  /// No description provided for @financeFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get financeFieldAmount;

  /// No description provided for @financeFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get financeFieldDate;

  /// No description provided for @financeFieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get financeFieldNote;

  /// No description provided for @financeFieldItemRef.
  ///
  /// In en, this message translates to:
  /// **'Linked item id (optional)'**
  String get financeFieldItemRef;

  /// No description provided for @financeFieldItemRefHint.
  ///
  /// In en, this message translates to:
  /// **'Use for sales tied to a specific SKU.'**
  String get financeFieldItemRefHint;

  /// No description provided for @financeFieldUpiRef.
  ///
  /// In en, this message translates to:
  /// **'UPI reference (optional)'**
  String get financeFieldUpiRef;

  /// No description provided for @financeFieldUpiRefHint.
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted on device — never in plain text.'**
  String get financeFieldUpiRefHint;

  /// No description provided for @financeValidationAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount is required.'**
  String get financeValidationAmountRequired;

  /// No description provided for @financeValidationAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get financeValidationAmountInvalid;

  /// No description provided for @financeLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get financeLedgerTitle;

  /// No description provided for @financeViewLedger.
  ///
  /// In en, this message translates to:
  /// **'View ledger'**
  String get financeViewLedger;

  /// No description provided for @financeExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export last 30 days'**
  String get financeExportCsv;

  /// No description provided for @financeExportCsvSubject.
  ///
  /// In en, this message translates to:
  /// **'Vanij ledger export'**
  String get financeExportCsvSubject;

  /// No description provided for @financeFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get financeFilterAll;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
