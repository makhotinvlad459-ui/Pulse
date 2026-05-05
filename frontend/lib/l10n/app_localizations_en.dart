// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pulse';

  @override
  String get subtitle => 'of your finances';

  @override
  String get loginLabel => 'Login (email or phone)';

  @override
  String get passwordLabel => 'Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get signIn => 'Sign in';

  @override
  String get fingerprintLogin => 'Login with fingerprint';

  @override
  String get noAccount => 'Don\'t have an account? Create';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noSavedCredentials => 'No saved credentials for biometric login';

  @override
  String get biometricError => 'Biometric authentication error';

  @override
  String get invalidCredentials => 'Invalid login or password';

  @override
  String get accountDeactivated => 'Account deactivated';

  @override
  String get connectionError => 'Connection error';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get registrationTitle => 'Registration';

  @override
  String get registrationSubtitle => 'create an account';

  @override
  String get emailRequired => 'Email*';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get min6Chars => 'Minimum 6 characters';

  @override
  String get nameRequired => 'Name*';

  @override
  String get passwordMin8 => 'Password (min. 8 characters)*';

  @override
  String get confirmPassword => 'Confirm password*';

  @override
  String get registerButton => 'Register';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get passwordWarning =>
      '⚠️ If you lose your password, you can reset it via email.\nSave your password in a secure place.';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get phoneTooShort => 'Phone must contain at least 6 characters';

  @override
  String get enterName => 'Enter your name';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get registrationError => 'Registration error';

  @override
  String get forgotPasswordTitle => 'Password recovery';

  @override
  String get forgotPasswordInstruction =>
      'Enter the email you used during registration, and we will send a link to reset your password.';

  @override
  String get emailLabel => 'Email';

  @override
  String get enterEmail => 'Enter email';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get resetLinkSent =>
      'Password reset link has been sent to your email.';

  @override
  String get error => 'Error';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordInstruction => 'Enter a new password.';

  @override
  String get newPasswordLabel => 'New password (min. 8 characters)';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get resetPasswordButton => 'Reset password';

  @override
  String get passwordChangedSuccess =>
      'Password changed successfully. You can now log in.';

  @override
  String get settings => 'Settings';

  @override
  String get employees => 'Employees';

  @override
  String get employeesInDevelopment => 'Employee list is under development';

  @override
  String get chooseTheme => 'Choose theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeBlue => 'Blue';

  @override
  String get themeGreen => 'Green';

  @override
  String get subscription => 'Subscription';

  @override
  String get subscriptionStatus => 'Status: Active';

  @override
  String get support => 'Support';

  @override
  String get emailSupport => 'Email';

  @override
  String get totalAll => 'Total';

  @override
  String get totalCash => 'Cash';

  @override
  String get totalBank => 'Bank';

  @override
  String get manager => 'Manager';

  @override
  String get phone => 'Phone';

  @override
  String get totalAmount => 'Amount';

  @override
  String get messages => 'Messages';

  @override
  String get tasks => 'Tasks';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Logout';

  @override
  String get tabOperations => 'Operations';

  @override
  String get tabShowcase => 'Showcase';

  @override
  String get tabChatTasks => 'Chat/Tasks';

  @override
  String get tabStock => 'Stock';

  @override
  String get tabReports => 'Reports';

  @override
  String get tabOrders => 'Orders';

  @override
  String get tabCounterparties => 'Counterparties';

  @override
  String get editCompany => 'Edit company';

  @override
  String get addAccount => 'Add account';

  @override
  String get manageCategories => 'Manage categories';

  @override
  String get manageEmployees => 'Manage employees';

  @override
  String get archive => 'Archive';

  @override
  String get deleteCompany => 'Delete company';

  @override
  String get archiveNotFound => 'Archive account not found.';

  @override
  String get deleteCompanyConfirmTitle => 'Delete company?';

  @override
  String get deleteCompanyConfirmContent =>
      'All company data will be permanently deleted.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get companyDeleted => 'Company deleted';

  @override
  String get archiveTitle => 'Archive of operations';

  @override
  String get archiveEmpty => 'Archive is empty';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get transfer => 'Transfer';

  @override
  String get createdBy => 'Created by';

  @override
  String get pending => 'Pending';

  @override
  String get accepted => 'Accepted';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String get createOrder => 'Create order';

  @override
  String get noOrders => 'No orders';

  @override
  String get workPrice => 'Work price';

  @override
  String get materials => 'Materials';

  @override
  String get paid => 'Paid';

  @override
  String get assignedTo => 'Assigned to';

  @override
  String get deadline => 'Deadline';

  @override
  String get remaining => 'Remaining';

  @override
  String get accept => 'Accept';

  @override
  String get complete => 'Complete';

  @override
  String get fail => 'Fail';

  @override
  String get details => 'Details';

  @override
  String get noPermissionToViewOrders => 'No permission to view orders';

  @override
  String get deleteOrderConfirmTitle => 'Delete order?';

  @override
  String get deleteOrderConfirmContent =>
      'The order will be permanently deleted.';

  @override
  String get orderDeleted => 'Order deleted';

  @override
  String get incomeSale => 'Income (Sale)';

  @override
  String get expensePurchase => 'Expense (Purchase)';

  @override
  String get withoutCategory => 'No category';

  @override
  String get transactionRestored => 'Transaction restored';

  @override
  String get permanentDeleteTitle => 'Permanently delete transaction?';

  @override
  String get permanentDeleteContent =>
      'The transaction will be deleted without possibility of recovery.';

  @override
  String get transactionDeleted => 'Transaction deleted';

  @override
  String get savedTo => 'Saved to';

  @override
  String get photo => 'Photo';

  @override
  String get pdfFile => 'PDF file';

  @override
  String get downloadPdf => 'Download PDF file?';

  @override
  String get download => 'Download';

  @override
  String get cannotDisplayFile => 'Cannot display file';

  @override
  String get noTransactionsForPeriod =>
      'No transactions for the selected period';

  @override
  String get turnover => 'Turnover';

  @override
  String get cash => 'Cash';

  @override
  String get nonCash => 'Non-cash';

  @override
  String get transactionNumber => 'Transaction';

  @override
  String get counterpartyLabel => 'Counterparty';

  @override
  String get productsLabel => 'Products';

  @override
  String get pcs => 'pcs';

  @override
  String get createdByLabel => 'Created by';

  @override
  String get changedByLabel => 'Changed by';

  @override
  String get viewAttachment => 'View attachment';

  @override
  String get restore => 'Restore';

  @override
  String get permanentDelete => 'Delete forever';

  @override
  String get noStockPermission => 'No permission to view stock';

  @override
  String get products => 'Products';

  @override
  String get searchByNameOrArticle => 'Search by name or article';

  @override
  String get noData => 'No data';

  @override
  String get article => 'Article';

  @override
  String get size => 'Size';

  @override
  String get barcode => 'Barcode';

  @override
  String get supplier => 'Supplier';

  @override
  String get deleteProductConfirmTitle => 'Delete product/material?';

  @override
  String get deleteProductConfirmContent => 'Are you sure you want to delete';

  @override
  String get productWillBeHidden =>
      'The item will be marked as deleted and will no longer appear in lists, but will remain in order history.';

  @override
  String get productDeleted => 'Item deleted';

  @override
  String get editProduct => 'Edit';

  @override
  String get newProduct => 'New ';

  @override
  String get unitRequired => 'Unit*';

  @override
  String get articleOptional => 'Article / label (optional)';

  @override
  String get sizeOptional => 'Size (optional)';

  @override
  String get barcodeOptional => 'Barcode / marking (optional)';

  @override
  String get supplierOptional => 'Supplier (optional)';

  @override
  String get fillNameAndUnit => 'Please fill in name and unit';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get addIngredient => 'Add ingredient';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get remainingStock => 'remaining';

  @override
  String get productLabel => 'Product';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get fillAllFields => 'Please fill in all fields';

  @override
  String get changeOrder => 'Change order';

  @override
  String get newShowcaseItem => 'New showcase item';

  @override
  String get nameLabel => 'Name';

  @override
  String get priceLabel => 'Price';

  @override
  String get categoryOptional => 'Category (optional)';

  @override
  String get editShowcaseItem => 'Edit showcase item';

  @override
  String get deleteShowcaseItemTitle => 'Delete item?';

  @override
  String get deleteShowcaseItemContent => 'This action cannot be undone.';

  @override
  String get sell => 'Sell';

  @override
  String get saleFromShowcase => 'Sale from showcase';

  @override
  String get saleCompleted => 'Sale completed';

  @override
  String get bulkSale => 'Bulk sale';

  @override
  String get selectAtLeastOne => 'Select at least one item';

  @override
  String get selectPaymentMethod => 'Select payment method';

  @override
  String get createShowcaseItem => 'Create showcase item';

  @override
  String get edit => 'Edit';

  @override
  String get bank => 'Bank';

  @override
  String get date => 'Date';

  @override
  String get counterpartyOptional => 'Counterparty (optional)';

  @override
  String get total => 'Total';

  @override
  String get noCategory => 'No category';

  @override
  String get add => 'Add';

  @override
  String get employeePasswords => 'Employee passwords';

  @override
  String get managerRole => 'Manager';

  @override
  String get employeeRole => 'Employee';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get passwordCopied => 'Password copied';

  @override
  String get close => 'Close';

  @override
  String get newCompany => 'New company';

  @override
  String get companyName => 'Company name*';

  @override
  String get enterCompanyName => 'Enter company name';

  @override
  String get managerFullName => 'Manager full name*';

  @override
  String get enterFullName => 'Enter full name';

  @override
  String get managerPhoneLogin => 'Manager phone (login)*';

  @override
  String get phoneHelperText => 'Used for login, at least 6 characters';

  @override
  String get enterPhone => 'Enter phone';

  @override
  String get employeesOptional => 'Employees (optional):';

  @override
  String get fullName => 'Full name';

  @override
  String get phoneLogin => 'Phone (login)';

  @override
  String get addEmployee => 'Add employee';

  @override
  String get createCompany => 'Create company';

  @override
  String get permissionsSaved => 'Permissions saved';

  @override
  String get employeePermissions => 'Employee permissions';

  @override
  String get groupOperations => 'Operations';

  @override
  String get groupShowcase => 'Showcase';

  @override
  String get groupChatTasks => 'Chat & Tasks';

  @override
  String get groupStock => 'Stock';

  @override
  String get groupReports => 'Reports';

  @override
  String get groupManagement => 'Management';

  @override
  String get groupDocuments => 'Documents';

  @override
  String get groupCounterparties => 'Counterparties';

  @override
  String get groupOrders => 'Orders';

  @override
  String get permViewOperations => 'View operations';

  @override
  String get permCreateTransaction => 'Create transactions';

  @override
  String get permEditTransaction => 'Edit transactions';

  @override
  String get permViewCounterparties => 'View counterparties';

  @override
  String get permEditCounterparties => 'Edit counterparties';

  @override
  String get permViewShowcase => 'View showcase';

  @override
  String get permEditShowcase => 'Edit showcase';

  @override
  String get permSellFromShowcase => 'Sell from showcase';

  @override
  String get permViewChat => 'View chat';

  @override
  String get permSendMessages => 'Send messages';

  @override
  String get permViewTasks => 'View tasks';

  @override
  String get permCreateTask => 'Create tasks';

  @override
  String get permEditTask => 'Edit tasks';

  @override
  String get permViewProducts => 'View products';

  @override
  String get permCreateProduct => 'Create products';

  @override
  String get permEditProduct => 'Edit products';

  @override
  String get permViewMaterials => 'View materials';

  @override
  String get permCreateMaterial => 'Create materials';

  @override
  String get permEditMaterial => 'Edit materials';

  @override
  String get permViewReports => 'View reports';

  @override
  String get permManageEmployees => 'Manage employees';

  @override
  String get permManagePermissions => 'Manage permissions';

  @override
  String get permViewAccounts => 'View accounts';

  @override
  String get permCreateAccount => 'Create accounts';

  @override
  String get permManageCategories => 'Manage categories';

  @override
  String get permEditCompany => 'Edit company';

  @override
  String get permViewArchive => 'View archive';

  @override
  String get permViewDocuments => 'View documents';

  @override
  String get permCreateDocuments => 'Create documents';

  @override
  String get permEditDocuments => 'Edit documents';

  @override
  String get permViewOrders => 'View orders';

  @override
  String get permEditOrders => 'Edit orders';

  @override
  String get addCounterparty => 'Add counterparty';

  @override
  String get noCounterparties => 'No counterparties';

  @override
  String get innLabel => 'INN';

  @override
  String get directorLabel => 'Director';

  @override
  String get newCounterparty => 'New counterparty';

  @override
  String get editCounterparty => 'Edit counterparty';

  @override
  String get innOptional => 'INN (optional)';

  @override
  String get directorOptional => 'Director (optional)';

  @override
  String get deleteCounterpartyTitle => 'Delete counterparty?';

  @override
  String get deleteCounterpartyContent => 'The counterparty will be deleted';

  @override
  String get operationsNotDeleted =>
      'This will not delete related transactions.';

  @override
  String get balance => 'Balance';

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get noPermissionToViewCounterparties =>
      'No permission to view counterparties';

  @override
  String get dynamics => 'Dynamics';

  @override
  String get cashVsNoncash => 'Cash vs Non-cash';

  @override
  String get incomeByCategory => 'Income by category';

  @override
  String get expenseByCategory => 'Expense by category';

  @override
  String get productIncomeExpense => 'Products (income/expense)';

  @override
  String get sales => 'Sales';

  @override
  String get materialConsumptionInOrders => 'Material consumption in orders';

  @override
  String get orderStatistics => 'Order statistics';

  @override
  String get counterparties => 'Counterparties';

  @override
  String get weekAbbr => 'w';

  @override
  String get userAssignedAsManager => 'User assigned as manager';

  @override
  String get passwordFor => 'Password for';

  @override
  String get copyPassword => 'Copy password';

  @override
  String get deleteEmployee => 'Delete employee';

  @override
  String get employeeWillLoseAccess =>
      'The employee will lose access to the company.';

  @override
  String get failedToLoadPermissions => 'Failed to load employee permissions';

  @override
  String get managePermissionsTooltip => 'Manage permissions';

  @override
  String get resetPasswordTooltip => 'Reset password';

  @override
  String get deleteEmployeeTooltip => 'Delete employee';

  @override
  String get categoryAdded => 'Category added';

  @override
  String get categoryDeleted => 'Category deleted';

  @override
  String get balanceForPeriod => 'Balance for period';

  @override
  String get incomeTitle => 'Income';

  @override
  String get expenseTitle => 'Expense';

  @override
  String get noTransactions => 'No transactions';

  @override
  String get editCompanyTitle => 'Edit company';

  @override
  String get companyUpdated => 'Company updated';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get file => 'File';

  @override
  String get downloadAttachment => 'Download attachment?';

  @override
  String get sendError => 'Send error';

  @override
  String get clearChatTitle => 'Clear chat?';

  @override
  String get clearChatContent => 'All messages will be permanently deleted.';

  @override
  String get clear => 'Clear';

  @override
  String get messageActions => 'Message actions';

  @override
  String get editMessage => 'Edit message';

  @override
  String get newText => 'New text';

  @override
  String get deleteMessageTitle => 'Delete message?';

  @override
  String get deleteMessageContent => 'The message will be permanently deleted.';

  @override
  String get loadEmployeesFirst => 'Loading employees... Please try later.';

  @override
  String get newTaskTitle => 'New task';

  @override
  String get taskName => 'Name';

  @override
  String get enterTaskName => 'Enter task name';

  @override
  String get taskDescription => 'Description';

  @override
  String get assignTo => 'Assign to';

  @override
  String get notAssigned => 'Not assigned';

  @override
  String get notSelected => 'Not selected';

  @override
  String get deleteTaskTitle => 'Delete task?';

  @override
  String get deleteTaskContent => 'The task will be permanently deleted.';

  @override
  String get pendingStatus => 'Pending';

  @override
  String get acceptedStatus => 'Accepted';

  @override
  String get completedStatus => 'Completed';

  @override
  String get failedStatus => 'Failed';

  @override
  String get chatTab => 'Chat';

  @override
  String get tasksTab => 'Tasks';

  @override
  String get clearChatTooltip => 'Clear chat';

  @override
  String get attachFileTooltip => 'Attach file';

  @override
  String get enterMessageHint => 'Enter message...';

  @override
  String get newTaskButton => 'New task';

  @override
  String get noTasks => 'No tasks';

  @override
  String get editedLabel => '(edited)';

  @override
  String get taskAuthorLabel => 'Author';

  @override
  String get taskAssigneeLabel => 'Assigned to';

  @override
  String get deadlineLabel => 'Deadline';

  @override
  String get acceptButton => 'Accept';

  @override
  String get completeButton => 'Complete';

  @override
  String get failButton => 'Fail';

  @override
  String get addProductTitle => 'Add product';

  @override
  String get editProductTitle => 'Edit product';

  @override
  String get productsInOperation => 'Products in operation:';

  @override
  String get addProductButton => 'Add product';

  @override
  String get noAccountsAvailable => 'No accounts available for editing.';

  @override
  String get editIncomeTitle => 'Edit income (sale)';

  @override
  String get editExpenseTitle => 'Edit expense (purchase)';

  @override
  String get editTransferTitle => 'Edit transfer';

  @override
  String get incomeShort => 'Income';

  @override
  String get incomeFull => 'Income (Sale)';

  @override
  String get expenseShort => 'Expense';

  @override
  String get expenseFull => 'Expense (Purchase)';

  @override
  String get transferShort => 'Transfer';

  @override
  String get transferFull => 'Transfer';

  @override
  String get toAccountLabel => 'To account';

  @override
  String get deleteTransactionTitle => 'Delete transaction';

  @override
  String get deleteTransactionContentPermanent =>
      'The transaction will be permanently deleted. This cannot be undone.';

  @override
  String get hideTransactionTitle => 'Hide transaction';

  @override
  String get hideTransactionContent =>
      'The transaction will be hidden from reports but will remain in history. You can restore it later.';

  @override
  String get hide => 'Hide';

  @override
  String get transactionDeletedPermanent => 'Transaction deleted';

  @override
  String get transactionHidden => 'Transaction hidden';

  @override
  String get enterAmountOrProducts => 'Please enter amount or add products';

  @override
  String get selectDestAccount => 'Select destination account';

  @override
  String get cannotTransferSame => 'Cannot transfer to the same account';

  @override
  String get newIncomeTitle => 'New income (sale)';

  @override
  String get newExpenseTitle => 'New expense (purchase)';

  @override
  String get newTransferTitle => 'New transfer';

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get invalidNumber => 'Enter a valid number';

  @override
  String get totalLabel => 'Total';

  @override
  String get totalAmountLabel => 'Total (₽)';

  @override
  String get insufficientStock => 'Insufficient stock for sale';

  @override
  String get refreshList => 'Refresh list';

  @override
  String get accountLabel => 'Account';

  @override
  String get amountLabel => 'Amount';

  @override
  String get dateLabel => 'Date';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get fileButton => 'File';

  @override
  String get cameraButton => 'Camera';

  @override
  String get hasAttachment => 'Has attachment';

  @override
  String get newCustomAccount => 'New custom account';

  @override
  String get accountName => 'Account name';

  @override
  String get includeInProfitLoss => 'Include in profit/loss';

  @override
  String get profitLossHint =>
      'You can choose whether this account affects the financial result.';

  @override
  String get cashType => 'Cash';

  @override
  String get bankType => 'Bank';

  @override
  String get customType => 'Custom';

  @override
  String get noCounterpartiesPeriod =>
      'No counterparties for the selected period';

  @override
  String get noChartData => 'No data for chart';

  @override
  String get incomeTooltip => 'Income';

  @override
  String get expenseTooltip => 'Expense';

  @override
  String get noMaterialData => 'No material consumption data';

  @override
  String get materialConsumptionTitle =>
      'Material consumption in completed orders';

  @override
  String get materialColumn => 'Material';

  @override
  String get unitColumn => 'Unit';

  @override
  String get quantityColumn => 'Quantity';

  @override
  String get costColumn => 'Cost';

  @override
  String get noOrderData => 'No order data';

  @override
  String get orderStatisticsTitle => 'Order statistics';

  @override
  String get quantityLabelLower => 'Quantity';

  @override
  String get amountLabelLower => 'Amount';

  @override
  String get dayLabel => 'Day';

  @override
  String get weekLabel => 'Week';

  @override
  String get monthLabel => 'Month';

  @override
  String get yearLabel => 'Year';

  @override
  String get customButton => 'Custom';

  @override
  String get totalConsumptionTitle =>
      'Total product consumption (stock+showcase)';

  @override
  String get totalIncomeTitle => 'Total product income (stock)';

  @override
  String get productColumn => 'Product';

  @override
  String get quantityPcsColumn => 'Quantity (pcs)';

  @override
  String get salesTitle => 'Sales';

  @override
  String get salesTooltip => 'Sales from stock (excluding showcase sales)';

  @override
  String get warehouseSalesTab => 'Stock products';

  @override
  String get showcaseSalesTab => 'Showcase products';

  @override
  String get noSalesData => 'No sales';

  @override
  String get profitTitle => 'Profit';

  @override
  String get productNameLabel => 'Name';

  @override
  String get addMaterialTitle => 'Add material';

  @override
  String get searchMaterialHint => 'Search material or enter name of a new one';

  @override
  String get remainingStockLower => 'remaining';

  @override
  String get selectedLabel => 'Selected';

  @override
  String get createNewMaterialButton => 'Create new material';

  @override
  String get quantityRequired => 'Quantity*';

  @override
  String get totalPriceRequired => 'Total price (₽)*';

  @override
  String get useFromStockLabel => 'Use from stock';

  @override
  String get newMaterialTitle => 'New material';

  @override
  String get pricePerUnitHint => 'Price per unit (0 - free)';

  @override
  String get enterMaterialName => 'Enter material name';

  @override
  String get selectMaterialAndQuantity =>
      'Select material, specify quantity and price';

  @override
  String get newOrderTitle => 'New order';

  @override
  String get enterOrderName => 'Enter order name';

  @override
  String get orderNameRequired => 'Name*';

  @override
  String get orderDescription => 'Description';

  @override
  String get workPriceLabel => 'Work price';

  @override
  String get assignResponsible => 'Assign responsible';

  @override
  String get materialsLabel => 'Materials';

  @override
  String get materialsTotal => 'Materials total';

  @override
  String get orderStatusLabel => 'Status';

  @override
  String get materialsPaidLabel => 'Materials paid';

  @override
  String get orderTotalAmountLabel => 'Order total amount';

  @override
  String get totalPaidLabel => 'Total paid';

  @override
  String get remainingToPayLabel => 'Remaining to pay';

  @override
  String get paymentsLabel => 'Payments';

  @override
  String get addPhotoAttachment => 'Take photo / attach file';

  @override
  String get attachedFilesLabel => 'Attached files:';

  @override
  String get completeOrderButton => 'Complete order';

  @override
  String get addPaymentTitle => 'Add payment';

  @override
  String get amountRequired => 'Amount*';

  @override
  String get paymentDateLabel => 'Payment date';

  @override
  String get receivingAccountLabel => 'Receiving account*';

  @override
  String get waiting => 'Pending';

  @override
  String get acceptedStatusShort => 'Accepted';

  @override
  String get completedStatusShort => 'Completed';

  @override
  String get failedStatusShort => 'Failed';

  @override
  String get orderLabel => 'Order';

  @override
  String get statusLabel => 'Status';

  @override
  String get orderStatusPending => 'Pending';

  @override
  String get orderStatusAccepted => 'Accepted';

  @override
  String get orderStatusCompleted => 'Completed';

  @override
  String get orderStatusFailed => 'Failed';

  @override
  String get materialsPaid => 'Materials paid';

  @override
  String get orderTotal => 'Order total';

  @override
  String get totalPaid => 'Total paid';

  @override
  String get remainingToPay => 'Remaining to pay';

  @override
  String get paidLabel => 'Paid';

  @override
  String get paidTooltip =>
      'Marking material as paid does NOT create a financial transaction.\nFor real money movement, use the \"Add payment\" button.';

  @override
  String get changeTotalPrice => 'Change total price';

  @override
  String get newTotalPriceLabel => 'New total price (₽)';

  @override
  String get receivingAccountRequired => 'Receiving account*';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get enterAmountAndSelectAccount => 'Enter amount and select account';

  @override
  String get maxAttachmentsReached =>
      'Cannot attach more than 10 files to an order';

  @override
  String get selectSource => 'Select source';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get fileAttached => 'File attached';

  @override
  String get filePreview => 'File preview';

  @override
  String get takePhotoAttach => 'Take photo / attach file';

  @override
  String get attachedFiles => 'Attached files:';

  @override
  String get view => 'View';

  @override
  String get deleteFileTitle => 'Delete file?';

  @override
  String get deleteFileContent => 'The file will be permanently deleted.';

  @override
  String get titleRequired => 'Title*';

  @override
  String get createButton => 'Create';

  @override
  String get enterTitle => 'Enter title';
}
