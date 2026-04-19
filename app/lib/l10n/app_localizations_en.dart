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
}
