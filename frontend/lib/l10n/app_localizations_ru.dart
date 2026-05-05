// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Пульс';

  @override
  String get subtitle => 'ваших финансов';

  @override
  String get loginLabel => 'Логин (email или телефон)';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get rememberMe => 'Запомнить меня';

  @override
  String get signIn => 'Войти';

  @override
  String get fingerprintLogin => 'Войти по отпечатку пальца';

  @override
  String get noAccount => 'Нет аккаунта? Создать';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get noSavedCredentials =>
      'Нет сохранённых учётных данных для входа по биометрии';

  @override
  String get biometricError => 'Ошибка биометрической аутентификации';

  @override
  String get invalidCredentials => 'Неверный логин или пароль';

  @override
  String get accountDeactivated => 'Учётная запись деактивирована';

  @override
  String get connectionError => 'Ошибка подключения к серверу';

  @override
  String get unknownError => 'Неизвестная ошибка';

  @override
  String get registrationTitle => 'Регистрация';

  @override
  String get registrationSubtitle => 'создайте аккаунт';

  @override
  String get emailRequired => 'Email*';

  @override
  String get phoneOptional => 'Телефон (необязательно)';

  @override
  String get min6Chars => 'Минимум 6 символов';

  @override
  String get nameRequired => 'Название*';

  @override
  String get passwordMin8 => 'Пароль (мин. 8 символов)*';

  @override
  String get confirmPassword => 'Подтвердите пароль*';

  @override
  String get registerButton => 'Зарегистрироваться';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get passwordWarning =>
      '⚠️ При утере пароля вы сможете восстановить его через email.\nСохраните пароль в надёжном месте.';

  @override
  String get invalidEmail => 'Введите корректный email';

  @override
  String get phoneTooShort => 'Телефон должен содержать не менее 6 символов';

  @override
  String get enterName => 'Введите имя';

  @override
  String get passwordTooShort => 'Пароль должен содержать не менее 8 символов';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get registrationError => 'Ошибка регистрации';

  @override
  String get forgotPasswordTitle => 'Восстановление пароля';

  @override
  String get forgotPasswordInstruction =>
      'Введите email, указанный при регистрации, и мы отправим ссылку для сброса пароля.';

  @override
  String get emailLabel => 'Email';

  @override
  String get enterEmail => 'Введите email';

  @override
  String get sendResetLink => 'Отправить ссылку';

  @override
  String get backToLogin => 'Вернуться ко входу';

  @override
  String get resetLinkSent =>
      'Ссылка для сброса пароля отправлена на ваш email.';

  @override
  String get error => 'Ошибка';

  @override
  String get resetPasswordTitle => 'Сброс пароля';

  @override
  String get resetPasswordInstruction => 'Введите новый пароль.';

  @override
  String get newPasswordLabel => 'Новый пароль (мин. 8 символов)';

  @override
  String get confirmPasswordLabel => 'Подтвердите пароль';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get resetPasswordButton => 'Сбросить пароль';

  @override
  String get passwordChangedSuccess =>
      'Пароль успешно изменён. Теперь вы можете войти.';

  @override
  String get settings => 'Настройки';

  @override
  String get employees => 'Сотрудники';

  @override
  String get employeesInDevelopment => 'Список сотрудников в разработке';

  @override
  String get chooseTheme => 'Выберите тему';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeBlue => 'Голубая';

  @override
  String get themeGreen => 'Зелёная';

  @override
  String get subscription => 'Подписка';

  @override
  String get subscriptionStatus => 'Статус: Активна';

  @override
  String get support => 'Поддержка';

  @override
  String get emailSupport => 'Email';

  @override
  String get totalAll => 'Суммарно';

  @override
  String get totalCash => 'Наличные';

  @override
  String get totalBank => 'Банк';

  @override
  String get manager => 'Управляющий';

  @override
  String get phone => 'Тел';

  @override
  String get totalAmount => 'Сумма';

  @override
  String get messages => 'Сообщения';

  @override
  String get tasks => 'Задачи';

  @override
  String get language => 'Язык';

  @override
  String get logout => 'Выйти';

  @override
  String get tabOperations => 'Операции';

  @override
  String get tabShowcase => 'Витрина';

  @override
  String get tabChatTasks => 'Чат/Задачи';

  @override
  String get tabStock => 'Склад';

  @override
  String get tabReports => 'Отчеты';

  @override
  String get tabOrders => 'Заказы';

  @override
  String get tabCounterparties => 'Контрагенты';

  @override
  String get editCompany => 'Редактировать компанию';

  @override
  String get addAccount => 'Добавить счёт';

  @override
  String get manageCategories => 'Управление категориями';

  @override
  String get manageEmployees => 'Управление сотрудниками';

  @override
  String get archive => 'Архив';

  @override
  String get deleteCompany => 'Удалить компанию';

  @override
  String get archiveNotFound => 'Архивный счёт не найден.';

  @override
  String get deleteCompanyConfirmTitle => 'Удалить компанию?';

  @override
  String get deleteCompanyConfirmContent =>
      'Все данные компании будут безвозвратно удалены.';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get companyDeleted => 'Компания удалена';

  @override
  String get archiveTitle => 'Архив операций';

  @override
  String get archiveEmpty => 'Архив пуст';

  @override
  String get income => 'Доход';

  @override
  String get expense => 'Расход';

  @override
  String get transfer => 'Перевод';

  @override
  String get createdBy => 'Создал';

  @override
  String get pending => 'Ожидают';

  @override
  String get accepted => 'Приняты';

  @override
  String get completed => 'Выполнены';

  @override
  String get failed => 'Провалены';

  @override
  String get createOrder => 'Создать заказ';

  @override
  String get noOrders => 'Нет заказов';

  @override
  String get workPrice => 'Цена работы';

  @override
  String get materials => 'Материалы';

  @override
  String get paid => 'Оплачено';

  @override
  String get assignedTo => 'Назначен';

  @override
  String get deadline => 'Дедлайн';

  @override
  String get remaining => 'Остаток';

  @override
  String get accept => 'Принять';

  @override
  String get complete => 'Выполнить';

  @override
  String get fail => 'Провалить';

  @override
  String get details => 'Детали';

  @override
  String get noPermissionToViewOrders => 'У вас нет прав для просмотра заказов';

  @override
  String get deleteOrderConfirmTitle => 'Удалить заказ?';

  @override
  String get deleteOrderConfirmContent => 'Заказ будет удалён безвозвратно.';

  @override
  String get orderDeleted => 'Заказ удалён';

  @override
  String get incomeSale => 'Приход (Продажа)';

  @override
  String get expensePurchase => 'Расход (Покупка)';

  @override
  String get withoutCategory => 'Без категории';

  @override
  String get transactionRestored => 'Операция восстановлена';

  @override
  String get permanentDeleteTitle => 'Удалить операцию навсегда?';

  @override
  String get permanentDeleteContent =>
      'Операция будет удалена без возможности восстановления.';

  @override
  String get transactionDeleted => 'Операция удалена';

  @override
  String get savedTo => 'Сохранено';

  @override
  String get photo => 'Фото';

  @override
  String get pdfFile => 'PDF файл';

  @override
  String get downloadPdf => 'Файл в формате PDF. Скачать?';

  @override
  String get download => 'Скачать';

  @override
  String get cannotDisplayFile => 'Невозможно отобразить файл';

  @override
  String get noTransactionsForPeriod => 'Нет операций за выбранный период';

  @override
  String get turnover => 'Оборот';

  @override
  String get cash => 'Наличные';

  @override
  String get nonCash => 'Безналичные';

  @override
  String get transactionNumber => 'Операция';

  @override
  String get counterpartyLabel => 'Контрагент';

  @override
  String get productsLabel => 'Товары';

  @override
  String get pcs => 'шт';

  @override
  String get createdByLabel => 'Создал';

  @override
  String get changedByLabel => 'Изменил';

  @override
  String get viewAttachment => 'Просмотреть вложение';

  @override
  String get restore => 'Восстановить';

  @override
  String get permanentDelete => 'Удалить навсегда';

  @override
  String get noStockPermission => 'Нет прав для просмотра склада';

  @override
  String get products => 'Товары';

  @override
  String get searchByNameOrArticle => 'Поиск по названию или артикулу';

  @override
  String get noData => 'Нет данных';

  @override
  String get article => 'Артикул';

  @override
  String get size => 'Размер';

  @override
  String get barcode => 'Штрихкод';

  @override
  String get supplier => 'Поставщик';

  @override
  String get deleteProductConfirmTitle => 'Удалить товар/материал?';

  @override
  String get deleteProductConfirmContent => 'Вы уверены, что хотите удалить';

  @override
  String get productWillBeHidden =>
      'Товар будет помечен как удалённый и перестанет отображаться в списках, но останется в истории заказов.';

  @override
  String get productDeleted => 'Товар удалён';

  @override
  String get editProduct => 'Редактировать';

  @override
  String get newProduct => 'Новый ';

  @override
  String get unitRequired => 'Единица измерения*';

  @override
  String get articleOptional => 'Артикул / метка (необязательно)';

  @override
  String get sizeOptional => 'Размер (необязательно)';

  @override
  String get barcodeOptional => 'Штрихкод / маркировка (необязательно)';

  @override
  String get supplierOptional => 'Поставщик (необязательно)';

  @override
  String get fillNameAndUnit => 'Заполните название и единицу измерения';

  @override
  String get save => 'Сохранить';

  @override
  String get create => 'Создать';

  @override
  String get addIngredient => 'Добавить ингредиент';

  @override
  String get ingredients => 'Ингредиенты';

  @override
  String get remainingStock => 'остаток';

  @override
  String get productLabel => 'Товар';

  @override
  String get quantityLabel => 'Количество';

  @override
  String get fillAllFields => 'Заполните все поля';

  @override
  String get changeOrder => 'Изменить порядок';

  @override
  String get newShowcaseItem => 'Новый товар/услуга';

  @override
  String get nameLabel => 'Название';

  @override
  String get priceLabel => 'Цена';

  @override
  String get categoryOptional => 'Категория (необязательно)';

  @override
  String get editShowcaseItem => 'Редактировать';

  @override
  String get deleteShowcaseItemTitle => 'Удалить элемент?';

  @override
  String get deleteShowcaseItemContent => 'Действие необратимо.';

  @override
  String get sell => 'Продать';

  @override
  String get saleFromShowcase => 'Продажа с витрины';

  @override
  String get saleCompleted => 'Продажа оформлена';

  @override
  String get bulkSale => 'Продажа списком';

  @override
  String get selectAtLeastOne => 'Выберите хотя бы один товар';

  @override
  String get selectPaymentMethod => 'Выберите способ оплаты';

  @override
  String get createShowcaseItem => 'Создать товар/услугу витрины';

  @override
  String get edit => 'Редактировать';

  @override
  String get bank => 'Банк';

  @override
  String get date => 'Дата';

  @override
  String get counterpartyOptional => 'Контрагент (необязательно)';

  @override
  String get total => 'Итого';

  @override
  String get noCategory => 'Без категории';

  @override
  String get add => 'Добавить';

  @override
  String get employeePasswords => 'Пароли сотрудников';

  @override
  String get managerRole => 'Управляющий';

  @override
  String get employeeRole => 'Сотрудник';

  @override
  String get phoneLabel => 'Телефон';

  @override
  String get passwordCopied => 'Пароль скопирован';

  @override
  String get close => 'Закрыть';

  @override
  String get newCompany => 'Новая компания';

  @override
  String get companyName => 'Название компании*';

  @override
  String get enterCompanyName => 'Введите название компании';

  @override
  String get managerFullName => 'Управляющий (ФИО)*';

  @override
  String get enterFullName => 'Введите ФИО';

  @override
  String get managerPhoneLogin => 'Телефон управляющего (логин)*';

  @override
  String get phoneHelperText => 'Используется для входа, не менее 6 символов';

  @override
  String get enterPhone => 'Введите телефон';

  @override
  String get employeesOptional => 'Сотрудники (необязательно):';

  @override
  String get fullName => 'ФИО';

  @override
  String get phoneLogin => 'Телефон (логин)';

  @override
  String get addEmployee => 'Добавить сотрудника';

  @override
  String get createCompany => 'Создать компанию';

  @override
  String get permissionsSaved => 'Права сохранены';

  @override
  String get employeePermissions => 'Права сотрудника';

  @override
  String get groupOperations => 'Операции';

  @override
  String get groupShowcase => 'Витрина';

  @override
  String get groupChatTasks => 'Чат и Задачи';

  @override
  String get groupStock => 'Склад';

  @override
  String get groupReports => 'Отчеты';

  @override
  String get groupManagement => 'Управление';

  @override
  String get groupDocuments => 'Документы';

  @override
  String get groupCounterparties => 'Контрагенты';

  @override
  String get groupOrders => 'Заказы';

  @override
  String get permViewOperations => 'Просмотр операций';

  @override
  String get permCreateTransaction => 'Создание операций';

  @override
  String get permEditTransaction => 'Редактирование операций';

  @override
  String get permViewCounterparties => 'Просмотр контрагентов';

  @override
  String get permEditCounterparties => 'Редактирование контрагентов';

  @override
  String get permViewShowcase => 'Просмотр витрины';

  @override
  String get permEditShowcase => 'Редактирование витрины';

  @override
  String get permSellFromShowcase => 'Продажа с витрины';

  @override
  String get permViewChat => 'Просмотр чата';

  @override
  String get permSendMessages => 'Отправка сообщений';

  @override
  String get permViewTasks => 'Просмотр задач';

  @override
  String get permCreateTask => 'Создание задач';

  @override
  String get permEditTask => 'Редактирование задач';

  @override
  String get permViewProducts => 'Просмотр товаров';

  @override
  String get permCreateProduct => 'Создание товаров';

  @override
  String get permEditProduct => 'Редактирование товаров';

  @override
  String get permViewMaterials => 'Просмотр материалов';

  @override
  String get permCreateMaterial => 'Создание материалов';

  @override
  String get permEditMaterial => 'Редактирование материалов';

  @override
  String get permViewReports => 'Просмотр отчётов';

  @override
  String get permManageEmployees => 'Управление сотрудниками';

  @override
  String get permManagePermissions => 'Управление правами';

  @override
  String get permViewAccounts => 'Просмотр счетов';

  @override
  String get permCreateAccount => 'Создание счетов';

  @override
  String get permManageCategories => 'Управление категориями';

  @override
  String get permEditCompany => 'Редактирование компании';

  @override
  String get permViewArchive => 'Просмотр архива';

  @override
  String get permViewDocuments => 'Просмотр документов';

  @override
  String get permCreateDocuments => 'Создание документов';

  @override
  String get permEditDocuments => 'Редактирование документов';

  @override
  String get permViewOrders => 'Просмотр заказов';

  @override
  String get permEditOrders => 'Редактирование заказов';

  @override
  String get addCounterparty => 'Добавить контрагента';

  @override
  String get noCounterparties => 'Нет контрагентов';

  @override
  String get innLabel => 'ИНН';

  @override
  String get directorLabel => 'Директор';

  @override
  String get newCounterparty => 'Новый контрагент';

  @override
  String get editCounterparty => 'Редактировать контрагента';

  @override
  String get innOptional => 'ИНН (необязательно)';

  @override
  String get directorOptional => 'Директор (необязательно)';

  @override
  String get deleteCounterpartyTitle => 'Удалить контрагента?';

  @override
  String get deleteCounterpartyContent => 'Контрагент будет удалён';

  @override
  String get operationsNotDeleted => 'Это не удалит связанные операции.';

  @override
  String get balance => 'Баланс';

  @override
  String get recentTransactions => 'Последние операции';

  @override
  String get noPermissionToViewCounterparties =>
      'Нет прав для просмотра контрагентов';

  @override
  String get dynamics => 'Динамика';

  @override
  String get cashVsNoncash => 'Наличные vs Безналичные';

  @override
  String get incomeByCategory => 'Доходы по категориям';

  @override
  String get expenseByCategory => 'Расходы по категориям';

  @override
  String get productIncomeExpense => 'Товары (приход/расход)';

  @override
  String get sales => 'Продажи';

  @override
  String get materialConsumptionInOrders => 'Расход материалов в заказах';

  @override
  String get orderStatistics => 'Статистика заказов';

  @override
  String get counterparties => 'Контрагенты';

  @override
  String get weekAbbr => 'нед.';

  @override
  String get userAssignedAsManager => 'Пользователь назначен управляющим';

  @override
  String get passwordFor => 'Пароль для';

  @override
  String get copyPassword => 'Копировать пароль';

  @override
  String get deleteEmployee => 'Удалить';

  @override
  String get employeeWillLoseAccess => 'Сотрудник потеряет доступ к компании.';

  @override
  String get failedToLoadPermissions => 'Не удалось загрузить права сотрудника';

  @override
  String get managePermissionsTooltip => 'Управление правами';

  @override
  String get resetPasswordTooltip => 'Сбросить пароль';

  @override
  String get deleteEmployeeTooltip => 'Удалить сотрудника';

  @override
  String get categoryAdded => 'Категория добавлена';

  @override
  String get categoryDeleted => 'Категория удалена';

  @override
  String get balanceForPeriod => 'Баланс за период';

  @override
  String get incomeTitle => 'Приходы';

  @override
  String get expenseTitle => 'Расходы';

  @override
  String get noTransactions => 'Нет операций';

  @override
  String get editCompanyTitle => 'Редактировать компанию';

  @override
  String get companyUpdated => 'Компания обновлена';

  @override
  String get chooseFromGallery => 'Выбрать из галереи';

  @override
  String get takePhoto => 'Сделать фото';

  @override
  String get chooseFile => 'Выбрать файл';

  @override
  String get file => 'Файл';

  @override
  String get downloadAttachment => 'Скачать вложение?';

  @override
  String get sendError => 'Ошибка отправки';

  @override
  String get clearChatTitle => 'Очистить чат?';

  @override
  String get clearChatContent => 'Все сообщения будут удалены безвозвратно.';

  @override
  String get clear => 'Очистить';

  @override
  String get messageActions => 'Действия с сообщением';

  @override
  String get editMessage => 'Редактировать сообщение';

  @override
  String get newText => 'Новый текст';

  @override
  String get deleteMessageTitle => 'Удалить сообщение?';

  @override
  String get deleteMessageContent => 'Сообщение будет удалено безвозвратно.';

  @override
  String get loadEmployeesFirst =>
      'Загрузка списка сотрудников... Попробуйте позже';

  @override
  String get newTaskTitle => 'Новая задача';

  @override
  String get taskName => 'Название';

  @override
  String get enterTaskName => 'Введите название';

  @override
  String get taskDescription => 'Описание';

  @override
  String get assignTo => 'Назначить';

  @override
  String get notAssigned => 'Не назначено';

  @override
  String get notSelected => 'Не выбран';

  @override
  String get deleteTaskTitle => 'Удалить задачу?';

  @override
  String get deleteTaskContent => 'Задача будет удалена безвозвратно.';

  @override
  String get pendingStatus => 'Ожидают';

  @override
  String get acceptedStatus => 'Приняты';

  @override
  String get completedStatus => 'Выполнены';

  @override
  String get failedStatus => 'Провалены';

  @override
  String get chatTab => 'Чат';

  @override
  String get tasksTab => 'Задачи';

  @override
  String get clearChatTooltip => 'Очистить чат';

  @override
  String get attachFileTooltip => 'Прикрепить файл';

  @override
  String get enterMessageHint => 'Введите сообщение...';

  @override
  String get newTaskButton => 'Новая задача';

  @override
  String get noTasks => 'Нет задач';

  @override
  String get editedLabel => '(изменено)';

  @override
  String get taskAuthorLabel => 'Автор';

  @override
  String get taskAssigneeLabel => 'Назначена';

  @override
  String get deadlineLabel => 'Дедлайн';

  @override
  String get acceptButton => 'Принять';

  @override
  String get completeButton => 'Выполнить';

  @override
  String get failButton => 'Провалить';

  @override
  String get addProductTitle => 'Добавить товар';

  @override
  String get editProductTitle => 'Редактировать товар';

  @override
  String get productsInOperation => 'Товары в операции:';

  @override
  String get addProductButton => 'Добавить товар';

  @override
  String get noAccountsAvailable => 'Нет доступных счетов для редактирования.';

  @override
  String get editIncomeTitle => 'Редактировать приход (продажа)';

  @override
  String get editExpenseTitle => 'Редактировать расход (покупка)';

  @override
  String get editTransferTitle => 'Редактировать перевод';

  @override
  String get incomeShort => 'Приход';

  @override
  String get incomeFull => 'Приход (Продажа)';

  @override
  String get expenseShort => 'Расход';

  @override
  String get expenseFull => 'Расход (Покупка)';

  @override
  String get transferShort => 'Перевод';

  @override
  String get transferFull => 'Перевод';

  @override
  String get toAccountLabel => 'Счёт получатель';

  @override
  String get deleteTransactionTitle => 'Удалить операцию';

  @override
  String get deleteTransactionContentPermanent =>
      'Операция будет удалена навсегда. Восстановление невозможно.';

  @override
  String get hideTransactionTitle => 'Скрыть операцию';

  @override
  String get hideTransactionContent =>
      'Операция будет скрыта из отчётов, но останется в истории. Вы сможете восстановить её позже.';

  @override
  String get hide => 'Скрыть';

  @override
  String get transactionDeletedPermanent => 'Операция удалена';

  @override
  String get transactionHidden => 'Операция скрыта';

  @override
  String get enterAmountOrProducts => 'Укажите сумму или добавьте товары';

  @override
  String get selectDestAccount => 'Выберите счёт получатель';

  @override
  String get cannotTransferSame => 'Нельзя переводить на тот же счёт';

  @override
  String get newIncomeTitle => 'Новый приход (продажа)';

  @override
  String get newExpenseTitle => 'Новый расход (покупка)';

  @override
  String get newTransferTitle => 'Новый перевод';

  @override
  String get enterAmount => 'Введите сумму';

  @override
  String get invalidNumber => 'Введите число';

  @override
  String get totalLabel => 'Итого';

  @override
  String get totalAmountLabel => 'Сумма (₽)';

  @override
  String get insufficientStock => 'Недостаточно товара на складе для продажи';

  @override
  String get refreshList => 'Обновить список';

  @override
  String get accountLabel => 'Счёт';

  @override
  String get amountLabel => 'Сумма';

  @override
  String get dateLabel => 'Дата';

  @override
  String get descriptionLabel => 'Описание';

  @override
  String get fileButton => 'Файл';

  @override
  String get cameraButton => 'Камера';

  @override
  String get hasAttachment => 'Есть вложение';

  @override
  String get newCustomAccount => 'Новый пользовательский счёт';

  @override
  String get accountName => 'Название счёта';

  @override
  String get includeInProfitLoss => 'Учитывать в прибыли/убытке';

  @override
  String get profitLossHint =>
      'Вы можете выбрать, влияет ли этот счёт на финансовый результат.';

  @override
  String get cashType => 'Наличные';

  @override
  String get bankType => 'Банк';

  @override
  String get customType => 'Пользовательский';

  @override
  String get noCounterpartiesPeriod => 'Нет контрагентов за выбранный период';

  @override
  String get noChartData => 'Нет данных для графика';

  @override
  String get incomeTooltip => 'Доход';

  @override
  String get expenseTooltip => 'Расход';

  @override
  String get noMaterialData => 'Нет данных о расходе материалов';

  @override
  String get materialConsumptionTitle =>
      'Расход материалов в выполненных заказах';

  @override
  String get materialColumn => 'Материал';

  @override
  String get unitColumn => 'Ед. изм.';

  @override
  String get quantityColumn => 'Количество';

  @override
  String get costColumn => 'Стоимость';

  @override
  String get noOrderData => 'Нет данных о заказах';

  @override
  String get orderStatisticsTitle => 'Статистика заказов';

  @override
  String get quantityLabelLower => 'Количество';

  @override
  String get amountLabelLower => 'Сумма';

  @override
  String get dayLabel => 'День';

  @override
  String get weekLabel => 'Неделя';

  @override
  String get monthLabel => 'Месяц';

  @override
  String get yearLabel => 'Год';

  @override
  String get customButton => 'Выбрать';

  @override
  String get totalConsumptionTitle => 'Общий расход товара (склад+витрина)';

  @override
  String get totalIncomeTitle => 'Общий приход товара (склад)';

  @override
  String get productColumn => 'Товар';

  @override
  String get quantityPcsColumn => 'Количество (шт)';

  @override
  String get salesTitle => 'Продажи';

  @override
  String get salesTooltip =>
      'Продажи со склада (не включают товары, проданные через витрину)';

  @override
  String get warehouseSalesTab => 'Товары со склада';

  @override
  String get showcaseSalesTab => 'Товары с витрины';

  @override
  String get noSalesData => 'Нет продаж';

  @override
  String get profitTitle => 'Прибыль';

  @override
  String get productNameLabel => 'Название';

  @override
  String get addMaterialTitle => 'Добавить материал';

  @override
  String get searchMaterialHint =>
      'Поиск материала или введите название нового';

  @override
  String get remainingStockLower => 'остаток';

  @override
  String get selectedLabel => 'Выбран';

  @override
  String get createNewMaterialButton => 'Создать новый материал';

  @override
  String get quantityRequired => 'Количество*';

  @override
  String get totalPriceRequired => 'Общая цена (₽)*';

  @override
  String get useFromStockLabel => 'Использовать со склада';

  @override
  String get newMaterialTitle => 'Новый материал';

  @override
  String get pricePerUnitHint => 'Цена за единицу (0 - бесплатно)';

  @override
  String get enterMaterialName => 'Введите название материала';

  @override
  String get selectMaterialAndQuantity =>
      'Выберите материал, укажите количество и цену';

  @override
  String get newOrderTitle => 'Новый заказ';

  @override
  String get enterOrderName => 'Введите название заказа';

  @override
  String get orderNameRequired => 'Название*';

  @override
  String get orderDescription => 'Описание';

  @override
  String get workPriceLabel => 'Цена работы';

  @override
  String get assignResponsible => 'Назначить ответственного';

  @override
  String get materialsLabel => 'Материалы';

  @override
  String get materialsTotal => 'Сумма материалов';

  @override
  String get orderStatusLabel => 'Статус';

  @override
  String get materialsPaidLabel => 'Оплачено материалов';

  @override
  String get orderTotalAmountLabel => 'Общая сумма заказа';

  @override
  String get totalPaidLabel => 'Оплачено всего';

  @override
  String get remainingToPayLabel => 'Остаток к оплате';

  @override
  String get paymentsLabel => 'Оплаты';

  @override
  String get addPhotoAttachment => 'Сделать фото / прикрепить файл';

  @override
  String get attachedFilesLabel => 'Прикреплённые файлы:';

  @override
  String get completeOrderButton => 'Выполнить заказ';

  @override
  String get addPaymentTitle => 'Добавить оплату';

  @override
  String get amountRequired => 'Сумма*';

  @override
  String get paymentDateLabel => 'Дата оплаты';

  @override
  String get receivingAccountLabel => 'Счёт получения оплаты*';

  @override
  String get waiting => 'Ожидает';

  @override
  String get acceptedStatusShort => 'Принят';

  @override
  String get completedStatusShort => 'Выполнен';

  @override
  String get failedStatusShort => 'Провален';

  @override
  String get orderLabel => 'Заказ';

  @override
  String get statusLabel => 'Статус';

  @override
  String get orderStatusPending => 'Ожидает';

  @override
  String get orderStatusAccepted => 'Принят';

  @override
  String get orderStatusCompleted => 'Выполнен';

  @override
  String get orderStatusFailed => 'Провален';

  @override
  String get materialsPaid => 'Оплачено материалов';

  @override
  String get orderTotal => 'Общая сумма заказа';

  @override
  String get totalPaid => 'Оплачено всего';

  @override
  String get remainingToPay => 'Остаток к оплате';

  @override
  String get paidLabel => 'Оплачено';

  @override
  String get paidTooltip =>
      'Отметка оплаты материала не создаёт финансовую операцию.\nДля реального движения денег используйте кнопку \"Добавить оплату\".';

  @override
  String get changeTotalPrice => 'Изменить общую цену';

  @override
  String get newTotalPriceLabel => 'Новая общая цена (₽)';

  @override
  String get receivingAccountRequired => 'Счёт получения оплаты*';

  @override
  String get commentOptional => 'Комментарий (необязательно)';

  @override
  String get enterAmountAndSelectAccount => 'Введите сумму и выберите счёт';

  @override
  String get maxAttachmentsReached =>
      'Нельзя прикрепить более 10 файлов к заказу';

  @override
  String get selectSource => 'Выберите источник';

  @override
  String get camera => 'Камера';

  @override
  String get gallery => 'Галерея';

  @override
  String get fileAttached => 'Файл прикреплён';

  @override
  String get filePreview => 'Просмотр файла';

  @override
  String get takePhotoAttach => 'Сделать фото / прикрепить файл';

  @override
  String get attachedFiles => 'Прикреплённые файлы:';

  @override
  String get view => 'Просмотреть';

  @override
  String get deleteFileTitle => 'Удалить файл?';

  @override
  String get deleteFileContent => 'Файл будет удалён безвозвратно.';

  @override
  String get titleRequired => 'Название*';

  @override
  String get createButton => 'Создать';

  @override
  String get enterTitle => 'Введите название';
}
