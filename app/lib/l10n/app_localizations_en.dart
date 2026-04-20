// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Vanij';

  @override
  String get appTagline => 'Built for the backbone of India.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get shopName => 'Shop name';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navFinance => 'Finance';

  @override
  String get navSettings => 'Settings';

  @override
  String get emptyInventoryTitle => 'No items yet';

  @override
  String get emptyInventorySubtitle => 'Tap + to add your first item.';

  @override
  String get emptyCustomersTitle => 'No customers yet';

  @override
  String get emptyCustomersSubtitle => 'Chats will appear here.';

  @override
  String get emptyFinanceTitle => 'No transactions yet';

  @override
  String get emptyFinanceSubtitle => 'Record your first sale to begin.';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get invalidEmail => 'Please enter a valid email.';

  @override
  String get weakPassword => 'Password must be at least 8 characters.';

  @override
  String get shopNameRequired => 'Please enter your shop name.';

  @override
  String get inventoryAddItem => 'Add item';

  @override
  String get inventoryEditItem => 'Edit item';

  @override
  String get inventorySearchHint => 'Search items';

  @override
  String get inventoryFilterCategory => 'Category';

  @override
  String get inventoryFilterColor => 'Colour';

  @override
  String get inventoryFilterAll => 'All';

  @override
  String get inventoryFieldName => 'Name';

  @override
  String get inventoryFieldCategory => 'Category';

  @override
  String get inventoryFieldPattern => 'Pattern (optional)';

  @override
  String get inventoryFieldPrice => 'Selling price';

  @override
  String get inventoryFieldCostPrice => 'Cost price';

  @override
  String get inventoryFieldSizes => 'Sizes';

  @override
  String get inventoryFieldColors => 'Colours';

  @override
  String get inventoryFieldQuantity => 'Qty';

  @override
  String get inventoryFieldImage => 'Photo';

  @override
  String get inventoryChooseFromCamera => 'Camera';

  @override
  String get inventoryChooseFromGallery => 'Gallery';

  @override
  String get inventorySave => 'Save';

  @override
  String get inventoryDelete => 'Delete';

  @override
  String get inventoryDeleteConfirmTitle => 'Delete item?';

  @override
  String get inventoryDeleteConfirmBody => 'This cannot be undone.';

  @override
  String get inventoryLowStockChip => 'Low stock';

  @override
  String get inventoryNoResults => 'No items match this filter.';

  @override
  String get inventoryLoadMore => 'Load more';

  @override
  String get inventoryValidationNameRequired => 'Name is required.';

  @override
  String get inventoryValidationPriceInvalid => 'Enter a valid price.';

  @override
  String get inventoryValidationCostPriceInvalid => 'Enter a valid cost price.';

  @override
  String get inventoryValidationNeedAtLeastOneSize => 'Add at least one size.';

  @override
  String get inventoryValidationImageRequired => 'Add a photo.';

  @override
  String get inventoryUploadingImage => 'Uploading photo…';

  @override
  String get inventoryAddWithAi => 'Scan with AI';

  @override
  String get tagConfirmTitle => 'Confirm tags';

  @override
  String get tagConfirmLoading => 'Asking the AI to look at your photo…';

  @override
  String get tagConfirmHeadline => 'Review the AI suggestions';

  @override
  String get tagConfirmSubheadline =>
      'Nothing is saved until you tap Continue. Edit anything that looks wrong.';

  @override
  String get tagConfirmContinue => 'Continue';

  @override
  String get tagConfirmSkip => 'Skip AI suggestions';

  @override
  String tagConfirmAiSuggested(String value) {
    return 'AI: $value';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get financeToday => 'Today';

  @override
  String financeTodayBreakdown(Object sales, Object refunds, Object expenses) {
    return 'Sales $sales · Refunds $refunds · Expenses $expenses';
  }

  @override
  String get financeWeekPnl => 'Last 7 days P&L';

  @override
  String get financeTopItems => 'Top items this week';

  @override
  String get financeTopItemsEmpty => 'No linked sales this week yet.';

  @override
  String get financeAddEntry => 'Add entry';

  @override
  String get financeEntrySaved => 'Entry saved to ledger.';

  @override
  String get financeEntryType => 'Type';

  @override
  String get financeTypeSale => 'Sale';

  @override
  String get financeTypeExpense => 'Expense';

  @override
  String get financeTypeRefund => 'Refund';

  @override
  String get financeFieldAmount => 'Amount';

  @override
  String get financeFieldDate => 'Date';

  @override
  String get financeFieldNote => 'Note (optional)';

  @override
  String get financeFieldItemRef => 'Linked item id (optional)';

  @override
  String get financeFieldItemRefHint => 'Use for sales tied to a specific SKU.';

  @override
  String get financeFieldUpiRef => 'UPI reference (optional)';

  @override
  String get financeFieldUpiRefHint =>
      'Stored encrypted on device — never in plain text.';

  @override
  String get financeValidationAmountRequired => 'Amount is required.';

  @override
  String get financeValidationAmountInvalid => 'Enter a valid amount.';

  @override
  String get financeLedgerTitle => 'Ledger';

  @override
  String get financeViewLedger => 'View ledger';

  @override
  String get financeExportCsv => 'Export last 30 days';

  @override
  String get financeExportCsvSubject => 'Vanij ledger export';

  @override
  String get financeFilterAll => 'All';

  @override
  String get crmCustomersTitle => 'Customers';

  @override
  String get crmAddCustomer => 'Add customer';

  @override
  String get crmEditCustomer => 'Edit customer';

  @override
  String get crmSearchHint => 'Search by name';

  @override
  String get crmCustomerFieldName => 'Name';

  @override
  String get crmCustomerFieldPhone => 'Phone';

  @override
  String get crmCustomerFieldPhoneHint =>
      'Stored encrypted on device — never in plain text.';

  @override
  String get crmCustomerFieldNotes => 'Notes (optional)';

  @override
  String get crmCustomerFieldTags => 'Tags (comma-separated)';

  @override
  String get crmCustomerSaved => 'Customer saved.';

  @override
  String get crmCustomerValidationNameRequired => 'Name is required.';

  @override
  String get crmCustomerValidationPhoneRequired => 'Phone is required.';

  @override
  String get crmCustomerValidationPhoneInvalid => 'Enter a valid phone number.';

  @override
  String get crmCustomerDeleteConfirmTitle => 'Delete customer?';

  @override
  String get crmCustomerDeleteConfirmBody =>
      'Chat history will be hidden from the list. Cannot be undone.';

  @override
  String get crmCustomerDelete => 'Delete';

  @override
  String get crmNoResults => 'No customers match this search.';

  @override
  String crmLastMessagePrefix(Object when) {
    return 'Last message $when';
  }

  @override
  String get crmNoMessagesYet =>
      'No messages yet — send one to start the chat.';

  @override
  String get crmComposerHint => 'Type a message';

  @override
  String get crmSenderMerchant => 'You';

  @override
  String get crmSenderCustomer => 'Customer';

  @override
  String get crmSenderAgent => 'Assistant';

  @override
  String get crmMessageEdit => 'Edit';

  @override
  String get crmMessageEditSave => 'Save';

  @override
  String get crmMessageEditedBadge => 'edited';

  @override
  String get crmMessageDelete => 'Delete';

  @override
  String get crmCustomerDecryptFailed =>
      'Phone could not be decrypted on this device.';

  @override
  String get crmAgentDraftBadge => 'DRAFT';

  @override
  String get crmAgentDraftReviewHint => 'review before sending';
}
