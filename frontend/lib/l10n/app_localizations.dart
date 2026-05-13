import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get appTitle;

  /// No description provided for @subtitle.
  ///
  /// In en, this message translates to:
  /// **'of your finances'**
  String get subtitle;

  /// No description provided for @loginLabel.
  ///
  /// In en, this message translates to:
  /// **'Login (email or phone)'**
  String get loginLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @fingerprintLogin.
  ///
  /// In en, this message translates to:
  /// **'Login with fingerprint'**
  String get fingerprintLogin;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Create'**
  String get noAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @noSavedCredentials.
  ///
  /// In en, this message translates to:
  /// **'No saved credentials for biometric login'**
  String get noSavedCredentials;

  /// No description provided for @biometricError.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication error'**
  String get biometricError;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid login or password'**
  String get invalidCredentials;

  /// No description provided for @accountDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Account deactivated'**
  String get accountDeactivated;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @registrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registrationTitle;

  /// No description provided for @registrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'create an account'**
  String get registrationSubtitle;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email*'**
  String get emailRequired;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @min6Chars.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get min6Chars;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name*'**
  String get nameRequired;

  /// No description provided for @passwordMin8.
  ///
  /// In en, this message translates to:
  /// **'Password (min. 8 characters)*'**
  String get passwordMin8;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password*'**
  String get confirmPassword;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @passwordWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ If you lose your password, you can reset it via email.\nSave your password in a secure place.'**
  String get passwordWarning;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @phoneTooShort.
  ///
  /// In en, this message translates to:
  /// **'Phone must contain at least 6 characters'**
  String get phoneTooShort;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterName;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @registrationError.
  ///
  /// In en, this message translates to:
  /// **'Registration error'**
  String get registrationError;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password recovery'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you used during registration, and we will send a link to reset your password.'**
  String get forgotPasswordInstruction;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter email'**
  String get enterEmail;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link has been sent to your email.'**
  String get resetLinkSent;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password.'**
  String get resetPasswordInstruction;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password (min. 8 characters)'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordButton;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully. You can now log in.'**
  String get passwordChangedSuccess;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employees;

  /// No description provided for @employeesInDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Employee list is under development'**
  String get employeesInDevelopment;

  /// No description provided for @chooseTheme.
  ///
  /// In en, this message translates to:
  /// **'Choose theme'**
  String get chooseTheme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get themeBlue;

  /// No description provided for @themeGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get themeGreen;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @subscriptionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: Active'**
  String get subscriptionStatus;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @emailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailSupport;

  /// No description provided for @totalAll.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalAll;

  /// No description provided for @totalCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get totalCash;

  /// No description provided for @totalBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get totalBank;

  /// No description provided for @manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get manager;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get totalAmount;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @tabOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get tabOperations;

  /// No description provided for @tabShowcase.
  ///
  /// In en, this message translates to:
  /// **'Showcase'**
  String get tabShowcase;

  /// No description provided for @tabChatTasks.
  ///
  /// In en, this message translates to:
  /// **'Chat/Tasks'**
  String get tabChatTasks;

  /// No description provided for @tabStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get tabStock;

  /// No description provided for @tabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get tabReports;

  /// No description provided for @tabOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get tabOrders;

  /// No description provided for @tabCounterparties.
  ///
  /// In en, this message translates to:
  /// **'Counterparties'**
  String get tabCounterparties;

  /// No description provided for @editCompany.
  ///
  /// In en, this message translates to:
  /// **'Edit company'**
  String get editCompany;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manageCategories;

  /// No description provided for @manageEmployees.
  ///
  /// In en, this message translates to:
  /// **'Manage employees'**
  String get manageEmployees;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @deleteCompany.
  ///
  /// In en, this message translates to:
  /// **'Delete company'**
  String get deleteCompany;

  /// No description provided for @archiveNotFound.
  ///
  /// In en, this message translates to:
  /// **'Archive account not found.'**
  String get archiveNotFound;

  /// No description provided for @deleteCompanyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete company?'**
  String get deleteCompanyConfirmTitle;

  /// No description provided for @deleteCompanyConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'All company data will be permanently deleted.'**
  String get deleteCompanyConfirmContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @companyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Company deleted'**
  String get companyDeleted;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive of operations'**
  String get archiveTitle;

  /// No description provided for @archiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Archive is empty'**
  String get archiveEmpty;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get createdBy;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @createOrder.
  ///
  /// In en, this message translates to:
  /// **'Create order'**
  String get createOrder;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders'**
  String get noOrders;

  /// No description provided for @workPrice.
  ///
  /// In en, this message translates to:
  /// **'Work price'**
  String get workPrice;

  /// No description provided for @materials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get assignedTo;

  /// No description provided for @deadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get deadline;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @fail.
  ///
  /// In en, this message translates to:
  /// **'Fail'**
  String get fail;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @noPermissionToViewOrders.
  ///
  /// In en, this message translates to:
  /// **'No permission to view orders'**
  String get noPermissionToViewOrders;

  /// No description provided for @deleteOrderConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete order?'**
  String get deleteOrderConfirmTitle;

  /// No description provided for @deleteOrderConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'The order will be permanently deleted.'**
  String get deleteOrderConfirmContent;

  /// No description provided for @orderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Order deleted'**
  String get orderDeleted;

  /// No description provided for @incomeSale.
  ///
  /// In en, this message translates to:
  /// **'Income (Sale)'**
  String get incomeSale;

  /// No description provided for @expensePurchase.
  ///
  /// In en, this message translates to:
  /// **'Expense (Purchase)'**
  String get expensePurchase;

  /// No description provided for @withoutCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get withoutCategory;

  /// No description provided for @transactionRestored.
  ///
  /// In en, this message translates to:
  /// **'Transaction restored'**
  String get transactionRestored;

  /// No description provided for @permanentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete transaction?'**
  String get permanentDeleteTitle;

  /// No description provided for @permanentDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'The transaction will be deleted without possibility of recovery.'**
  String get permanentDeleteContent;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transactionDeleted;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to'**
  String get savedTo;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @pdfFile.
  ///
  /// In en, this message translates to:
  /// **'PDF file'**
  String get pdfFile;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF file?'**
  String get downloadPdf;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @cannotDisplayFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot display file'**
  String get cannotDisplayFile;

  /// No description provided for @noTransactionsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No transactions for the selected period'**
  String get noTransactionsForPeriod;

  /// No description provided for @turnover.
  ///
  /// In en, this message translates to:
  /// **'Turnover'**
  String get turnover;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @nonCash.
  ///
  /// In en, this message translates to:
  /// **'Non-cash'**
  String get nonCash;

  /// No description provided for @transactionNumber.
  ///
  /// In en, this message translates to:
  /// **'№'**
  String get transactionNumber;

  /// No description provided for @counterpartyLabel.
  ///
  /// In en, this message translates to:
  /// **'Counterparty'**
  String get counterpartyLabel;

  /// No description provided for @productsLabel.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsLabel;

  /// No description provided for @pcs.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get pcs;

  /// No description provided for @createdByLabel.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get createdByLabel;

  /// No description provided for @changedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Changed by'**
  String get changedByLabel;

  /// No description provided for @viewAttachment.
  ///
  /// In en, this message translates to:
  /// **'View attachment'**
  String get viewAttachment;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @permanentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get permanentDelete;

  /// No description provided for @noStockPermission.
  ///
  /// In en, this message translates to:
  /// **'No permission to view stock'**
  String get noStockPermission;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @searchByNameOrArticle.
  ///
  /// In en, this message translates to:
  /// **'Search by name or article'**
  String get searchByNameOrArticle;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @article.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get article;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @deleteProductConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete product/material?'**
  String get deleteProductConfirmTitle;

  /// No description provided for @deleteProductConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get deleteProductConfirmContent;

  /// No description provided for @productWillBeHidden.
  ///
  /// In en, this message translates to:
  /// **'The item will be marked as deleted and will no longer appear in lists, but will remain in order history.'**
  String get productWillBeHidden;

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get productDeleted;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editProduct;

  /// No description provided for @newProduct.
  ///
  /// In en, this message translates to:
  /// **'New '**
  String get newProduct;

  /// No description provided for @unitRequired.
  ///
  /// In en, this message translates to:
  /// **'Unit*'**
  String get unitRequired;

  /// No description provided for @articleOptional.
  ///
  /// In en, this message translates to:
  /// **'Article / label (optional)'**
  String get articleOptional;

  /// No description provided for @sizeOptional.
  ///
  /// In en, this message translates to:
  /// **'Size (optional)'**
  String get sizeOptional;

  /// No description provided for @barcodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Barcode / marking (optional)'**
  String get barcodeOptional;

  /// No description provided for @supplierOptional.
  ///
  /// In en, this message translates to:
  /// **'Supplier (optional)'**
  String get supplierOptional;

  /// No description provided for @fillNameAndUnit.
  ///
  /// In en, this message translates to:
  /// **'Please fill in name and unit'**
  String get fillNameAndUnit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @addIngredient.
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get addIngredient;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @remainingStock.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get remainingStock;

  /// No description provided for @productLabel.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productLabel;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get fillAllFields;

  /// No description provided for @changeOrder.
  ///
  /// In en, this message translates to:
  /// **'Change order'**
  String get changeOrder;

  /// No description provided for @newShowcaseItem.
  ///
  /// In en, this message translates to:
  /// **'New showcase item'**
  String get newShowcaseItem;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @categoryOptional.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get categoryOptional;

  /// No description provided for @editShowcaseItem.
  ///
  /// In en, this message translates to:
  /// **'Edit showcase item'**
  String get editShowcaseItem;

  /// No description provided for @deleteShowcaseItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get deleteShowcaseItemTitle;

  /// No description provided for @deleteShowcaseItemContent.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteShowcaseItemContent;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @saleFromShowcase.
  ///
  /// In en, this message translates to:
  /// **'Sale from showcase'**
  String get saleFromShowcase;

  /// No description provided for @saleCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sale completed'**
  String get saleCompleted;

  /// No description provided for @bulkSale.
  ///
  /// In en, this message translates to:
  /// **'Bulk sale'**
  String get bulkSale;

  /// No description provided for @selectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one item'**
  String get selectAtLeastOne;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select payment method'**
  String get selectPaymentMethod;

  /// No description provided for @createShowcaseItem.
  ///
  /// In en, this message translates to:
  /// **'Create showcase item'**
  String get createShowcaseItem;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @bank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bank;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @counterpartyOptional.
  ///
  /// In en, this message translates to:
  /// **'Counterparty (optional)'**
  String get counterpartyOptional;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @employeePasswords.
  ///
  /// In en, this message translates to:
  /// **'Employee passwords'**
  String get employeePasswords;

  /// No description provided for @managerRole.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get managerRole;

  /// No description provided for @employeeRole.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employeeRole;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get passwordCopied;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @newCompany.
  ///
  /// In en, this message translates to:
  /// **'New company'**
  String get newCompany;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company name*'**
  String get companyName;

  /// No description provided for @enterCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Enter company name'**
  String get enterCompanyName;

  /// No description provided for @managerFullName.
  ///
  /// In en, this message translates to:
  /// **'Manager full name*'**
  String get managerFullName;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter full name'**
  String get enterFullName;

  /// No description provided for @managerPhoneLogin.
  ///
  /// In en, this message translates to:
  /// **'Manager phone (login)*'**
  String get managerPhoneLogin;

  /// No description provided for @phoneHelperText.
  ///
  /// In en, this message translates to:
  /// **'Used for login, at least 6 characters'**
  String get phoneHelperText;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter phone'**
  String get enterPhone;

  /// No description provided for @employeesOptional.
  ///
  /// In en, this message translates to:
  /// **'Employees (optional):'**
  String get employeesOptional;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @phoneLogin.
  ///
  /// In en, this message translates to:
  /// **'Phone (login)'**
  String get phoneLogin;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add employee'**
  String get addEmployee;

  /// No description provided for @createCompany.
  ///
  /// In en, this message translates to:
  /// **'Create company'**
  String get createCompany;

  /// No description provided for @permissionsSaved.
  ///
  /// In en, this message translates to:
  /// **'Permissions saved'**
  String get permissionsSaved;

  /// No description provided for @employeePermissions.
  ///
  /// In en, this message translates to:
  /// **'Employee permissions'**
  String get employeePermissions;

  /// No description provided for @groupOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get groupOperations;

  /// No description provided for @groupShowcase.
  ///
  /// In en, this message translates to:
  /// **'Showcase'**
  String get groupShowcase;

  /// No description provided for @groupChatTasks.
  ///
  /// In en, this message translates to:
  /// **'Chat & Tasks'**
  String get groupChatTasks;

  /// No description provided for @groupStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get groupStock;

  /// No description provided for @groupReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get groupReports;

  /// No description provided for @groupManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get groupManagement;

  /// No description provided for @groupDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get groupDocuments;

  /// No description provided for @groupCounterparties.
  ///
  /// In en, this message translates to:
  /// **'Counterparties'**
  String get groupCounterparties;

  /// No description provided for @groupOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get groupOrders;

  /// No description provided for @permViewOperations.
  ///
  /// In en, this message translates to:
  /// **'View operations'**
  String get permViewOperations;

  /// No description provided for @permCreateTransaction.
  ///
  /// In en, this message translates to:
  /// **'Create transactions'**
  String get permCreateTransaction;

  /// No description provided for @permEditTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transactions'**
  String get permEditTransaction;

  /// No description provided for @permViewCounterparties.
  ///
  /// In en, this message translates to:
  /// **'View counterparties'**
  String get permViewCounterparties;

  /// No description provided for @permEditCounterparties.
  ///
  /// In en, this message translates to:
  /// **'Edit counterparties'**
  String get permEditCounterparties;

  /// No description provided for @permViewShowcase.
  ///
  /// In en, this message translates to:
  /// **'View showcase'**
  String get permViewShowcase;

  /// No description provided for @permEditShowcase.
  ///
  /// In en, this message translates to:
  /// **'Edit showcase'**
  String get permEditShowcase;

  /// No description provided for @permSellFromShowcase.
  ///
  /// In en, this message translates to:
  /// **'Sell from showcase'**
  String get permSellFromShowcase;

  /// No description provided for @permViewChat.
  ///
  /// In en, this message translates to:
  /// **'View chat'**
  String get permViewChat;

  /// No description provided for @permSendMessages.
  ///
  /// In en, this message translates to:
  /// **'Send messages'**
  String get permSendMessages;

  /// No description provided for @permViewTasks.
  ///
  /// In en, this message translates to:
  /// **'View tasks'**
  String get permViewTasks;

  /// No description provided for @permCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Create tasks'**
  String get permCreateTask;

  /// No description provided for @permEditTask.
  ///
  /// In en, this message translates to:
  /// **'Edit tasks'**
  String get permEditTask;

  /// No description provided for @permViewProducts.
  ///
  /// In en, this message translates to:
  /// **'View products'**
  String get permViewProducts;

  /// No description provided for @permCreateProduct.
  ///
  /// In en, this message translates to:
  /// **'Create products'**
  String get permCreateProduct;

  /// No description provided for @permEditProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit products'**
  String get permEditProduct;

  /// No description provided for @permViewMaterials.
  ///
  /// In en, this message translates to:
  /// **'View materials'**
  String get permViewMaterials;

  /// No description provided for @permCreateMaterial.
  ///
  /// In en, this message translates to:
  /// **'Create materials'**
  String get permCreateMaterial;

  /// No description provided for @permEditMaterial.
  ///
  /// In en, this message translates to:
  /// **'Edit materials'**
  String get permEditMaterial;

  /// No description provided for @permViewReports.
  ///
  /// In en, this message translates to:
  /// **'View reports'**
  String get permViewReports;

  /// No description provided for @permManageEmployees.
  ///
  /// In en, this message translates to:
  /// **'Manage employees'**
  String get permManageEmployees;

  /// No description provided for @permManagePermissions.
  ///
  /// In en, this message translates to:
  /// **'Manage permissions'**
  String get permManagePermissions;

  /// No description provided for @permViewAccounts.
  ///
  /// In en, this message translates to:
  /// **'View accounts'**
  String get permViewAccounts;

  /// No description provided for @permCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create accounts'**
  String get permCreateAccount;

  /// No description provided for @permManageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get permManageCategories;

  /// No description provided for @permEditCompany.
  ///
  /// In en, this message translates to:
  /// **'Edit company'**
  String get permEditCompany;

  /// No description provided for @permViewArchive.
  ///
  /// In en, this message translates to:
  /// **'View archive'**
  String get permViewArchive;

  /// No description provided for @permViewDocuments.
  ///
  /// In en, this message translates to:
  /// **'View documents'**
  String get permViewDocuments;

  /// No description provided for @permCreateDocuments.
  ///
  /// In en, this message translates to:
  /// **'Create documents'**
  String get permCreateDocuments;

  /// No description provided for @permEditDocuments.
  ///
  /// In en, this message translates to:
  /// **'Edit documents'**
  String get permEditDocuments;

  /// No description provided for @permViewOrders.
  ///
  /// In en, this message translates to:
  /// **'View orders'**
  String get permViewOrders;

  /// No description provided for @permEditOrders.
  ///
  /// In en, this message translates to:
  /// **'Edit orders'**
  String get permEditOrders;

  /// No description provided for @addCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Add counterparty'**
  String get addCounterparty;

  /// No description provided for @noCounterparties.
  ///
  /// In en, this message translates to:
  /// **'No counterparties'**
  String get noCounterparties;

  /// No description provided for @innLabel.
  ///
  /// In en, this message translates to:
  /// **'INN'**
  String get innLabel;

  /// No description provided for @directorLabel.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get directorLabel;

  /// No description provided for @newCounterparty.
  ///
  /// In en, this message translates to:
  /// **'New counterparty'**
  String get newCounterparty;

  /// No description provided for @editCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Edit counterparty'**
  String get editCounterparty;

  /// No description provided for @innOptional.
  ///
  /// In en, this message translates to:
  /// **'INN (optional)'**
  String get innOptional;

  /// No description provided for @directorOptional.
  ///
  /// In en, this message translates to:
  /// **'Director (optional)'**
  String get directorOptional;

  /// No description provided for @deleteCounterpartyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete counterparty?'**
  String get deleteCounterpartyTitle;

  /// No description provided for @deleteCounterpartyContent.
  ///
  /// In en, this message translates to:
  /// **'The counterparty will be deleted'**
  String get deleteCounterpartyContent;

  /// No description provided for @operationsNotDeleted.
  ///
  /// In en, this message translates to:
  /// **'This will not delete related transactions.'**
  String get operationsNotDeleted;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get recentTransactions;

  /// No description provided for @noPermissionToViewCounterparties.
  ///
  /// In en, this message translates to:
  /// **'No permission to view counterparties'**
  String get noPermissionToViewCounterparties;

  /// No description provided for @dynamics.
  ///
  /// In en, this message translates to:
  /// **'Dynamics'**
  String get dynamics;

  /// No description provided for @cashVsNoncash.
  ///
  /// In en, this message translates to:
  /// **'Cash vs Non-cash'**
  String get cashVsNoncash;

  /// No description provided for @incomeByCategory.
  ///
  /// In en, this message translates to:
  /// **'Income by category'**
  String get incomeByCategory;

  /// No description provided for @expenseByCategory.
  ///
  /// In en, this message translates to:
  /// **'Expense by category'**
  String get expenseByCategory;

  /// No description provided for @productIncomeExpense.
  ///
  /// In en, this message translates to:
  /// **'Products (income/expense)'**
  String get productIncomeExpense;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @materialConsumptionInOrders.
  ///
  /// In en, this message translates to:
  /// **'Material consumption in orders'**
  String get materialConsumptionInOrders;

  /// No description provided for @orderStatistics.
  ///
  /// In en, this message translates to:
  /// **'Order statistics'**
  String get orderStatistics;

  /// No description provided for @counterparties.
  ///
  /// In en, this message translates to:
  /// **'Counterparties'**
  String get counterparties;

  /// No description provided for @weekAbbr.
  ///
  /// In en, this message translates to:
  /// **'w'**
  String get weekAbbr;

  /// No description provided for @userAssignedAsManager.
  ///
  /// In en, this message translates to:
  /// **'User assigned as manager'**
  String get userAssignedAsManager;

  /// No description provided for @passwordFor.
  ///
  /// In en, this message translates to:
  /// **'Password for'**
  String get passwordFor;

  /// No description provided for @copyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get copyPassword;

  /// No description provided for @deleteEmployee.
  ///
  /// In en, this message translates to:
  /// **'Delete employee'**
  String get deleteEmployee;

  /// No description provided for @employeeWillLoseAccess.
  ///
  /// In en, this message translates to:
  /// **'The employee will lose access to the company.'**
  String get employeeWillLoseAccess;

  /// No description provided for @failedToLoadPermissions.
  ///
  /// In en, this message translates to:
  /// **'Failed to load employee permissions'**
  String get failedToLoadPermissions;

  /// No description provided for @managePermissionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage permissions'**
  String get managePermissionsTooltip;

  /// No description provided for @resetPasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTooltip;

  /// No description provided for @deleteEmployeeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete employee'**
  String get deleteEmployeeTooltip;

  /// No description provided for @categoryAdded.
  ///
  /// In en, this message translates to:
  /// **'Category added'**
  String get categoryAdded;

  /// No description provided for @categoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categoryDeleted;

  /// No description provided for @balanceForPeriod.
  ///
  /// In en, this message translates to:
  /// **'Balance for period'**
  String get balanceForPeriod;

  /// No description provided for @incomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeTitle;

  /// No description provided for @expenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseTitle;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get noTransactions;

  /// No description provided for @editCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit company'**
  String get editCompanyTitle;

  /// No description provided for @companyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Company updated'**
  String get companyUpdated;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @downloadAttachment.
  ///
  /// In en, this message translates to:
  /// **'Download attachment?'**
  String get downloadAttachment;

  /// No description provided for @sendError.
  ///
  /// In en, this message translates to:
  /// **'Send error'**
  String get sendError;

  /// No description provided for @clearChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear chat?'**
  String get clearChatTitle;

  /// No description provided for @clearChatContent.
  ///
  /// In en, this message translates to:
  /// **'All messages will be permanently deleted.'**
  String get clearChatContent;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @messageActions.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get messageActions;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessage;

  /// No description provided for @newText.
  ///
  /// In en, this message translates to:
  /// **'New text'**
  String get newText;

  /// No description provided for @deleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get deleteMessageTitle;

  /// No description provided for @deleteMessageContent.
  ///
  /// In en, this message translates to:
  /// **'The message will be permanently deleted.'**
  String get deleteMessageContent;

  /// No description provided for @loadEmployeesFirst.
  ///
  /// In en, this message translates to:
  /// **'Loading employees... Please try later.'**
  String get loadEmployeesFirst;

  /// No description provided for @newTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTaskTitle;

  /// No description provided for @taskName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get taskName;

  /// No description provided for @enterTaskName.
  ///
  /// In en, this message translates to:
  /// **'Enter task name'**
  String get enterTaskName;

  /// No description provided for @taskDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskDescription;

  /// No description provided for @assignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get assignTo;

  /// No description provided for @notAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get notAssigned;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @deleteTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get deleteTaskTitle;

  /// No description provided for @deleteTaskContent.
  ///
  /// In en, this message translates to:
  /// **'The task will be permanently deleted.'**
  String get deleteTaskContent;

  /// No description provided for @pendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingStatus;

  /// No description provided for @acceptedStatus.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get acceptedStatus;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedStatus;

  /// No description provided for @failedStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedStatus;

  /// No description provided for @chatTab.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTab;

  /// No description provided for @tasksTab.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTab;

  /// No description provided for @clearChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get clearChatTooltip;

  /// No description provided for @attachFileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFileTooltip;

  /// No description provided for @enterMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Enter message...'**
  String get enterMessageHint;

  /// No description provided for @newTaskButton.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTaskButton;

  /// No description provided for @noTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get noTasks;

  /// No description provided for @editedLabel.
  ///
  /// In en, this message translates to:
  /// **'(edited)'**
  String get editedLabel;

  /// No description provided for @taskAuthorLabel.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get taskAuthorLabel;

  /// No description provided for @taskAssigneeLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get taskAssigneeLabel;

  /// No description provided for @deadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get deadlineLabel;

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @completeButton.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeButton;

  /// No description provided for @failButton.
  ///
  /// In en, this message translates to:
  /// **'Fail'**
  String get failButton;

  /// No description provided for @addProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProductTitle;

  /// No description provided for @editProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProductTitle;

  /// No description provided for @productsInOperation.
  ///
  /// In en, this message translates to:
  /// **'Products in operation:'**
  String get productsInOperation;

  /// No description provided for @addProductButton.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProductButton;

  /// No description provided for @noAccountsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No accounts available for editing.'**
  String get noAccountsAvailable;

  /// No description provided for @editIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit income (sale)'**
  String get editIncomeTitle;

  /// No description provided for @editExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit expense (purchase)'**
  String get editExpenseTitle;

  /// No description provided for @editTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get editTransferTitle;

  /// No description provided for @incomeShort.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeShort;

  /// No description provided for @incomeFull.
  ///
  /// In en, this message translates to:
  /// **'Income (Sale)'**
  String get incomeFull;

  /// No description provided for @expenseShort.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseShort;

  /// No description provided for @expenseFull.
  ///
  /// In en, this message translates to:
  /// **'Expense (Purchase)'**
  String get expenseFull;

  /// No description provided for @transferShort.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferShort;

  /// No description provided for @transferFull.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferFull;

  /// No description provided for @toAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get toAccountLabel;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionContentPermanent.
  ///
  /// In en, this message translates to:
  /// **'The transaction will be permanently deleted. This cannot be undone.'**
  String get deleteTransactionContentPermanent;

  /// No description provided for @hideTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide transaction'**
  String get hideTransactionTitle;

  /// No description provided for @hideTransactionContent.
  ///
  /// In en, this message translates to:
  /// **'The transaction will be hidden from reports but will remain in history. You can restore it later.'**
  String get hideTransactionContent;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @transactionDeletedPermanent.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transactionDeletedPermanent;

  /// No description provided for @transactionHidden.
  ///
  /// In en, this message translates to:
  /// **'Transaction hidden'**
  String get transactionHidden;

  /// No description provided for @enterAmountOrProducts.
  ///
  /// In en, this message translates to:
  /// **'Please enter amount or add products'**
  String get enterAmountOrProducts;

  /// No description provided for @selectDestAccount.
  ///
  /// In en, this message translates to:
  /// **'Select destination account'**
  String get selectDestAccount;

  /// No description provided for @cannotTransferSame.
  ///
  /// In en, this message translates to:
  /// **'Cannot transfer to the same account'**
  String get cannotTransferSame;

  /// No description provided for @newIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'New income (sale)'**
  String get newIncomeTitle;

  /// No description provided for @newExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'New expense (purchase)'**
  String get newExpenseTitle;

  /// No description provided for @newTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'New transfer'**
  String get newTransferTitle;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get invalidNumber;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @totalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Total (₽)'**
  String get totalAmountLabel;

  /// No description provided for @insufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Insufficient stock for sale'**
  String get insufficientStock;

  /// No description provided for @refreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get refreshList;

  /// No description provided for @accountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @fileButton.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileButton;

  /// No description provided for @cameraButton.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraButton;

  /// No description provided for @hasAttachment.
  ///
  /// In en, this message translates to:
  /// **'Has attachment'**
  String get hasAttachment;

  /// No description provided for @newCustomAccount.
  ///
  /// In en, this message translates to:
  /// **'New custom account'**
  String get newCustomAccount;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// No description provided for @includeInProfitLoss.
  ///
  /// In en, this message translates to:
  /// **'Include in profit/loss'**
  String get includeInProfitLoss;

  /// No description provided for @profitLossHint.
  ///
  /// In en, this message translates to:
  /// **'You can choose whether this account affects the financial result.'**
  String get profitLossHint;

  /// No description provided for @cashType.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cashType;

  /// No description provided for @bankType.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bankType;

  /// No description provided for @customType.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customType;

  /// No description provided for @noCounterpartiesPeriod.
  ///
  /// In en, this message translates to:
  /// **'No counterparties for the selected period'**
  String get noCounterpartiesPeriod;

  /// No description provided for @noChartData.
  ///
  /// In en, this message translates to:
  /// **'No data for chart'**
  String get noChartData;

  /// No description provided for @incomeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeTooltip;

  /// No description provided for @expenseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseTooltip;

  /// No description provided for @noMaterialData.
  ///
  /// In en, this message translates to:
  /// **'No material consumption data'**
  String get noMaterialData;

  /// No description provided for @materialConsumptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Material consumption in completed orders'**
  String get materialConsumptionTitle;

  /// No description provided for @materialColumn.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get materialColumn;

  /// No description provided for @unitColumn.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitColumn;

  /// No description provided for @quantityColumn.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityColumn;

  /// No description provided for @costColumn.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get costColumn;

  /// No description provided for @noOrderData.
  ///
  /// In en, this message translates to:
  /// **'No order data'**
  String get noOrderData;

  /// No description provided for @orderStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Order statistics'**
  String get orderStatisticsTitle;

  /// No description provided for @quantityLabelLower.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabelLower;

  /// No description provided for @amountLabelLower.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabelLower;

  /// No description provided for @dayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayLabel;

  /// No description provided for @weekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekLabel;

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthLabel;

  /// No description provided for @yearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get yearLabel;

  /// No description provided for @customButton.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customButton;

  /// No description provided for @totalConsumptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Total product consumption (stock+showcase)'**
  String get totalConsumptionTitle;

  /// No description provided for @totalIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Total product income (stock)'**
  String get totalIncomeTitle;

  /// No description provided for @productColumn.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productColumn;

  /// No description provided for @quantityPcsColumn.
  ///
  /// In en, this message translates to:
  /// **'Quantity (pcs)'**
  String get quantityPcsColumn;

  /// No description provided for @salesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesTitle;

  /// No description provided for @salesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sales from stock (excluding showcase sales)'**
  String get salesTooltip;

  /// No description provided for @warehouseSalesTab.
  ///
  /// In en, this message translates to:
  /// **'Stock products'**
  String get warehouseSalesTab;

  /// No description provided for @showcaseSalesTab.
  ///
  /// In en, this message translates to:
  /// **'Showcase products'**
  String get showcaseSalesTab;

  /// No description provided for @noSalesData.
  ///
  /// In en, this message translates to:
  /// **'No sales'**
  String get noSalesData;

  /// No description provided for @profitTitle.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profitTitle;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get productNameLabel;

  /// No description provided for @addMaterialTitle.
  ///
  /// In en, this message translates to:
  /// **'Add material'**
  String get addMaterialTitle;

  /// No description provided for @searchMaterialHint.
  ///
  /// In en, this message translates to:
  /// **'Search material or enter name of a new one'**
  String get searchMaterialHint;

  /// No description provided for @remainingStockLower.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get remainingStockLower;

  /// No description provided for @selectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selectedLabel;

  /// No description provided for @createNewMaterialButton.
  ///
  /// In en, this message translates to:
  /// **'Create new material'**
  String get createNewMaterialButton;

  /// No description provided for @quantityRequired.
  ///
  /// In en, this message translates to:
  /// **'Quantity*'**
  String get quantityRequired;

  /// No description provided for @totalPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Total price (₽)*'**
  String get totalPriceRequired;

  /// No description provided for @useFromStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Use from stock'**
  String get useFromStockLabel;

  /// No description provided for @newMaterialTitle.
  ///
  /// In en, this message translates to:
  /// **'New material'**
  String get newMaterialTitle;

  /// No description provided for @pricePerUnitHint.
  ///
  /// In en, this message translates to:
  /// **'Price per unit (0 - free)'**
  String get pricePerUnitHint;

  /// No description provided for @enterMaterialName.
  ///
  /// In en, this message translates to:
  /// **'Enter material name'**
  String get enterMaterialName;

  /// No description provided for @selectMaterialAndQuantity.
  ///
  /// In en, this message translates to:
  /// **'Select material, specify quantity and price'**
  String get selectMaterialAndQuantity;

  /// No description provided for @newOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get newOrderTitle;

  /// No description provided for @enterOrderName.
  ///
  /// In en, this message translates to:
  /// **'Enter order name'**
  String get enterOrderName;

  /// No description provided for @orderNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name*'**
  String get orderNameRequired;

  /// No description provided for @orderDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get orderDescription;

  /// No description provided for @workPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Work price'**
  String get workPriceLabel;

  /// No description provided for @assignResponsible.
  ///
  /// In en, this message translates to:
  /// **'Assign responsible'**
  String get assignResponsible;

  /// No description provided for @materialsLabel.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materialsLabel;

  /// No description provided for @materialsTotal.
  ///
  /// In en, this message translates to:
  /// **'Materials total'**
  String get materialsTotal;

  /// No description provided for @orderStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get orderStatusLabel;

  /// No description provided for @materialsPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Materials paid'**
  String get materialsPaidLabel;

  /// No description provided for @orderTotalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Order total amount'**
  String get orderTotalAmountLabel;

  /// No description provided for @totalPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get totalPaidLabel;

  /// No description provided for @remainingToPayLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining to pay'**
  String get remainingToPayLabel;

  /// No description provided for @paymentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsLabel;

  /// No description provided for @addPhotoAttachment.
  ///
  /// In en, this message translates to:
  /// **'Take photo / attach file'**
  String get addPhotoAttachment;

  /// No description provided for @attachedFilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Attached files:'**
  String get attachedFilesLabel;

  /// No description provided for @completeOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Complete order'**
  String get completeOrderButton;

  /// No description provided for @addPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add payment'**
  String get addPaymentTitle;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount*'**
  String get amountRequired;

  /// No description provided for @paymentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment date'**
  String get paymentDateLabel;

  /// No description provided for @receivingAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Receiving account*'**
  String get receivingAccountLabel;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get waiting;

  /// No description provided for @acceptedStatusShort.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get acceptedStatusShort;

  /// No description provided for @completedStatusShort.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedStatusShort;

  /// No description provided for @failedStatusShort.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedStatusShort;

  /// No description provided for @orderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatusPending;

  /// No description provided for @orderStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get orderStatusAccepted;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get orderStatusFailed;

  /// No description provided for @materialsPaid.
  ///
  /// In en, this message translates to:
  /// **'Materials paid'**
  String get materialsPaid;

  /// No description provided for @orderTotal.
  ///
  /// In en, this message translates to:
  /// **'Order total'**
  String get orderTotal;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get totalPaid;

  /// No description provided for @remainingToPay.
  ///
  /// In en, this message translates to:
  /// **'Remaining to pay'**
  String get remainingToPay;

  /// No description provided for @paidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidLabel;

  /// No description provided for @paidTooltip.
  ///
  /// In en, this message translates to:
  /// **'Marking material as paid does NOT create a financial transaction.\nFor real money movement, use the \"Add payment\" button.'**
  String get paidTooltip;

  /// No description provided for @changeTotalPrice.
  ///
  /// In en, this message translates to:
  /// **'Change total price'**
  String get changeTotalPrice;

  /// No description provided for @newTotalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'New total price (₽)'**
  String get newTotalPriceLabel;

  /// No description provided for @receivingAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Receiving account*'**
  String get receivingAccountRequired;

  /// No description provided for @commentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptional;

  /// No description provided for @enterAmountAndSelectAccount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount and select account'**
  String get enterAmountAndSelectAccount;

  /// No description provided for @maxAttachmentsReached.
  ///
  /// In en, this message translates to:
  /// **'Cannot attach more than 10 files to an order'**
  String get maxAttachmentsReached;

  /// No description provided for @selectSource.
  ///
  /// In en, this message translates to:
  /// **'Select source'**
  String get selectSource;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @fileAttached.
  ///
  /// In en, this message translates to:
  /// **'File attached'**
  String get fileAttached;

  /// No description provided for @filePreview.
  ///
  /// In en, this message translates to:
  /// **'File preview'**
  String get filePreview;

  /// No description provided for @takePhotoAttach.
  ///
  /// In en, this message translates to:
  /// **'Take photo / attach file'**
  String get takePhotoAttach;

  /// No description provided for @attachedFiles.
  ///
  /// In en, this message translates to:
  /// **'Attached files:'**
  String get attachedFiles;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @deleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete file?'**
  String get deleteFileTitle;

  /// No description provided for @deleteFileContent.
  ///
  /// In en, this message translates to:
  /// **'The file will be permanently deleted.'**
  String get deleteFileContent;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title*'**
  String get titleRequired;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @enterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter title'**
  String get enterTitle;

  /// No description provided for @currencySymbol.
  ///
  /// In en, this message translates to:
  /// **''**
  String get currencySymbol;

  /// No description provided for @unitPcs.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get unitPcs;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitG;

  /// No description provided for @unitL.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get unitL;

  /// No description provided for @unitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unitMl;

  /// No description provided for @unitM.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitM;

  /// No description provided for @unitCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @unitInch.
  ///
  /// In en, this message translates to:
  /// **'inch'**
  String get unitInch;

  /// No description provided for @unitPackage.
  ///
  /// In en, this message translates to:
  /// **'pack'**
  String get unitPackage;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountTypeBank;

  /// No description provided for @accountTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get accountTypeCustom;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get roleEmployee;

  /// No description provided for @roleFounder.
  ///
  /// In en, this message translates to:
  /// **'Founder'**
  String get roleFounder;

  /// No description provided for @unitGram.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitGram;

  /// No description provided for @unitLiter.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get unitLiter;

  /// No description provided for @unitMeter.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitMeter;

  /// No description provided for @unitPack.
  ///
  /// In en, this message translates to:
  /// **'pack'**
  String get unitPack;

  /// No description provided for @categoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get categoryTransport;

  /// No description provided for @catSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get catSalary;

  /// No description provided for @catRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get catRent;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get catCommunication;

  /// No description provided for @catAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Advertising'**
  String get catAdvertising;

  /// No description provided for @catTaxes.
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get catTaxes;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @catImplementation.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get catImplementation;

  /// No description provided for @catRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get catRevenue;

  /// No description provided for @catOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get catOffice;

  /// No description provided for @catShop.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get catShop;

  /// No description provided for @catCashbox.
  ///
  /// In en, this message translates to:
  /// **'Cashbox'**
  String get catCashbox;

  /// No description provided for @catContractors.
  ///
  /// In en, this message translates to:
  /// **'Contractors'**
  String get catContractors;

  /// No description provided for @founderRole.
  ///
  /// In en, this message translates to:
  /// **'Founder'**
  String get founderRole;

  /// No description provided for @catSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get catSales;

  /// No description provided for @catCashDesk.
  ///
  /// In en, this message translates to:
  /// **'Cash desk'**
  String get catCashDesk;

  /// No description provided for @paymentForOrder.
  ///
  /// In en, this message translates to:
  /// **'Payment for order'**
  String get paymentForOrder;

  /// No description provided for @orderCompletion.
  ///
  /// In en, this message translates to:
  /// **'Order completion'**
  String get orderCompletion;

  /// No description provided for @productMovementTitle.
  ///
  /// In en, this message translates to:
  /// **'Product movement'**
  String get productMovementTitle;

  /// No description provided for @selectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select product'**
  String get selectProduct;

  /// No description provided for @exportToExcel.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get exportToExcel;

  /// No description provided for @selectProductHint.
  ///
  /// In en, this message translates to:
  /// **'Select a product to view its transactions'**
  String get selectProductHint;

  /// No description provided for @noTransactionsForProduct.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this product'**
  String get noTransactionsForProduct;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @exportReport.
  ///
  /// In en, this message translates to:
  /// **'Export report'**
  String get exportReport;

  /// No description provided for @noDataToExport.
  ///
  /// In en, this message translates to:
  /// **'No data to export'**
  String get noDataToExport;

  /// No description provided for @errorExcelGenerate.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate Excel file'**
  String get errorExcelGenerate;

  /// No description provided for @incomeType.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeType;

  /// No description provided for @expenseType.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseType;

  /// No description provided for @operationsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Operations export'**
  String get operationsExportTitle;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @selectCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Select counterparty'**
  String get selectCounterparty;

  /// No description provided for @selectCounterpartyHint.
  ///
  /// In en, this message translates to:
  /// **'Select a counterparty to view transactions'**
  String get selectCounterpartyHint;

  /// No description provided for @noTransactionsForCounterparty.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this counterparty'**
  String get noTransactionsForCounterparty;

  /// No description provided for @counterpartyMovementTitle.
  ///
  /// In en, this message translates to:
  /// **'Counterparty movement'**
  String get counterpartyMovementTitle;

  /// No description provided for @cashMovementTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash movement'**
  String get cashMovementTitle;

  /// No description provided for @bankMovementTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank movement'**
  String get bankMovementTitle;

  /// No description provided for @userGuide.
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get userGuide;

  /// No description provided for @userGuideText.
  ///
  /// In en, this message translates to:
  /// **'🚀 **Pulse of your finances** — financial accounting for business\n\n✅ **All‑in‑one tool** – no need for separate programs for accounting, chat, tasks, and orders.\n✅ **Owner’s overview across all companies** – see finances of each company and the overall situation. Employees only see what you allow.\n✅ **Simple** – anyone who can use a smartphone can figure it out.\n✅ **Time saving** – reports are built in seconds, no manual calculations.\n✅ **Mobile** – work from home, office, on the road. Everything syncs.\n✅ **Support** – we are always in touch.\n\n🌍 **Works anywhere**\n💻 Web version – open in a browser on a computer or laptop.\n📱 Mobile apps for Android and iOS – download from stores (Google Play, App Store) and work from your phone or tablet.\nData syncs automatically – start on computer, continue on phone.\n\n**Why this app?**\nManage money, orders, goods, and employees – all in one place.\nBusiness owner can keep a finger on the pulse of several companies at once: see income, expenses, account balances, debts, orders, and stock.\nEmployees work only with the companies and sections you assign.\n\n**How to get started**\n1. **Sign up** – provide email, phone (optional), name, and password (min 8 characters).\n2. **Create a company** (owner only) – tap the green ‘+’ button. Fill in: company name, manager name, manager phone (login). Optionally add employees – the app generates a password for each. ⚠️ Password is NOT sent by email – copy it and give to the employee personally.\n3. **Roles & permissions** – owner has full access. Manager and employees see only what you allow. To change permissions later: Company → menu (three dots) → “Manage employees”.\n\n**Main screen (after entering a company)**\n- Account cards – “Cash” and “Bank” (and any extra accounts). Balance updates automatically.\n- Tabs (depending on role):\n  - **Transactions** – record income/expense. Attach photo, add products, specify counterparty. Products can be deducted from stock automatically.\n  - **Showcase** – fixed‑price products/services. Attach a recipe (tech card) – when sold, materials are deducted automatically.\n  - **Chat & Tasks** – communicate and assign tasks. Employees see only their tasks. Attach files.\n  - **Stock** – product and material balances. Add, edit, set units (pcs, kg, m, pack…). Materials in orders can be deducted or not – you choose.\n  - **Reports** – dynamics, income/expense by category, sales, material consumption in orders, order statistics, counterparties, **Export to Excel** (transactions, product movement, counterparty movement, cash/bank movement).\n  - **Orders** – create orders, assign responsible, set deadline, track payments, attach files, change status (pending → accepted → completed / failed).\n  - **Counterparties** – list of suppliers and customers, automatic stats (income, expense, balance). Add/edit.\n\n**Features for owners of multiple companies**\n- Create any number of companies, switch between them on the main screen.\n- Each company has separate accounts, employees, transactions, categories.\n- Financial overview of all companies – you see the total cash and bank balances of each company.\nThis is real management accounting – you always know where the money is, what expenses, what profit per business area. No confusion.\n\n**Switch language**\nTap ☰ (menu) in the top‑left corner, then choose 🇬🇧 or 🇷🇺. System strings (buttons, tab names, categories) translate automatically. Your personal data (company names, account names, product names) remain in the language you entered.\n\n**Try it – it’s easier than it looks. All data at hand, reports build themselves.** 😊'**
  String get userGuideText;

  /// No description provided for @reorderTabs.
  ///
  /// In en, this message translates to:
  /// **'Reorder tabs'**
  String get reorderTabs;

  /// No description provided for @activeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Active subscription'**
  String get activeSubscription;

  /// No description provided for @noActiveSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active subscription'**
  String get noActiveSubscription;

  /// No description provided for @expiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires at'**
  String get expiresAt;

  /// No description provided for @companiesCount.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get companiesCount;

  /// No description provided for @remainingFreeCompanies.
  ///
  /// In en, this message translates to:
  /// **'Remaining free companies'**
  String get remainingFreeCompanies;

  /// No description provided for @chooseTariff.
  ///
  /// In en, this message translates to:
  /// **'Choose tariff'**
  String get chooseTariff;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly (30 days)'**
  String get monthly;

  /// No description provided for @halfYear.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get halfYear;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get yearly;

  /// No description provided for @extraCompany.
  ///
  /// In en, this message translates to:
  /// **'Extra company slot'**
  String get extraCompany;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentNote.
  ///
  /// In en, this message translates to:
  /// **'Payment is processed via secure gateway. After payment, the status will update automatically.'**
  String get paymentNote;

  /// No description provided for @companyLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Company limit reached'**
  String get companyLimitReached;

  /// No description provided for @companyLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'You have reached the limit of free companies. Please buy a subscription or an extra company slot to continue.'**
  String get companyLimitMessage;

  /// No description provided for @buySubscription.
  ///
  /// In en, this message translates to:
  /// **'Buy subscription'**
  String get buySubscription;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
