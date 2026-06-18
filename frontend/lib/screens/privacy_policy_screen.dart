// lib/screens/privacy_policy_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isRussian = locale.languageCode == 'ru';

    return Scaffold(
      appBar: AppBar(
        title: Text(isRussian ? 'Политика конфиденциальности' : 'Privacy Policy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRussian ? 'Политика конфиденциальности' : 'Privacy Policy',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isRussian
                  ? 'Последнее обновление: 18 июня 2026 г.'
                  : 'Last updated: June 18, 2026',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            _buildSection(
              title: isRussian ? '1. Введение' : '1. Introduction',
              content: isRussian
                  ? 'Индивидуальный предприниматель Махотин Владислав Алишадович (далее — "Мы", "Нас", "Наш") уважает вашу конфиденциальность. Настоящая Политика конфиденциальности описывает, как мы собираем, используем и защищаем вашу личную информацию при использовании нашего мобильного приложения Pulse (далее — "Приложение").'
                  : 'Individual Entrepreneur Makhotin Vladislav Alishadovich (hereinafter — "We", "Us", "Our") respects your privacy. This Privacy Policy describes how we collect, use and protect your personal information when you use our mobile application Pulse (hereinafter — the "Application").',
            ),

            _buildSection(
              title: isRussian ? '2. Какие данные мы собираем' : '2. What Data We Collect',
              content: isRussian
                  ? 'Мы собираем только те данные, которые необходимы для работы Приложения и предоставления вам наших услуг:\n\n'
                    '• Регистрационные данные: адрес электронной почты, номер телефона, имя и фамилия.\n'
                    '• Данные о компаниях: название, ИНН, юридический адрес.\n'
                    '• Финансовые данные: информация о транзакциях, счетах и платежах.\n'
                    '• Технические данные: информация об устройстве, IP-адрес, данные о взаимодействии с Приложением.\n'
                    '• Данные о местоположении: только с вашего явного согласия, только для функций, которые требуют этой информации.'
                  : 'We collect only the data necessary for the Application to work and to provide you with our services:\n\n'
                    '• Registration data: email address, phone number, first and last name.\n'
                    '• Company data: name, TIN, legal address.\n'
                    '• Financial data: information about transactions, accounts, and payments.\n'
                    '• Technical data: device information, IP address, data on interaction with the Application.\n'
                    '• Location data: only with your explicit consent, only for features that require this information.',
            ),

            _buildSection(
              title: isRussian ? '3. Как мы используем ваши данные' : '3. How We Use Your Data',
              content: isRussian
                  ? 'Ваши данные используются исключительно для следующих целей:\n\n'
                    '• Предоставление услуг: регистрация, управление компаниями, обработка платежей.\n'
                    '• Улучшение Приложения: анализ использования для повышения качества и стабильности.\n'
                    '• Уведомления: отправка важных сообщений о работе Приложения.\n'
                    '• Безопасность: защита от мошенничества и несанкционированного доступа.\n\n'
                    'Мы не используем ваши данные для рекламных целей и не передаем их третьим лицам без вашего согласия.'
                  : 'Your data is used exclusively for the following purposes:\n\n'
                    '• Service Provision: registration, company management, payment processing.\n'
                    '• Application Improvement: usage analysis to improve quality and stability.\n'
                    '• Notifications: sending important messages about the Application.\n'
                    '• Security: protection against fraud and unauthorized access.\n\n'
                    'We do not use your data for advertising purposes and do not share it with third parties without your consent.',
            ),

            _buildSection(
              title: isRussian ? '4. Передача данных третьим лицам' : '4. Data Sharing with Third Parties',
              content: isRussian
                  ? 'Мы можем передавать ваши данные только в следующих случаях:\n\n'
                    '• Поставщики услуг: платежные системы (ЮKassa – только для веб-версии, Google Play, App Store), хостинг-провайдеры.\n'
                    '• Уведомления: Firebase Cloud Messaging для отправки push-уведомлений.\n'
                    '• Аналитика: для сбора анонимной статистики использования (без привязки к личности).\n'
                    '• По требованию закона: в случаях, предусмотренных законодательством.\n\n'
                    'Все третьи стороны обязаны соблюдать конфиденциальность ваших данных.'
                  : 'We may share your data only in the following cases:\n\n'
                    '• Service Providers: payment systems (YooKassa – only for the web version, Google Play, App Store), hosting providers.\n'
                    '• Notifications: Firebase Cloud Messaging for sending push notifications.\n'
                    '• Analytics: for collecting anonymous usage statistics (without personal identification).\n'
                    '• As Required by Law: in cases provided for by legislation.\n\n'
                    'All third parties are required to maintain the confidentiality of your data.',
            ),

            _buildSection(
              title: isRussian ? '5. Срок хранения и удаление данных' : '5. Data Retention and Deletion',
              content: isRussian
                  ? 'Мы храним ваши данные только в течение необходимого срока:\n\n'
                    '• Аккаунт: данные хранятся до тех пор, пока вы пользуетесь Приложением.\n'
                    '• Удаление: вы можете удалить свои данные в любой момент через настройки профиля.\n'
                    '• Запрос на удаление: вы можете обратиться к нам с запросом на полное удаление данных.\n'
                    '• Срок хранения: после удаления аккаунта данные будут удалены в течение 30 дней.'
                  : 'We store your data only for as long as necessary:\n\n'
                    '• Account: data is stored as long as you use the Application.\n'
                    '• Deletion: you can delete your data at any time through your profile settings.\n'
                    '• Deletion Request: you can contact us with a request for complete data deletion.\n'
                    '• Retention Period: after account deletion, data will be deleted within 30 days.',
            ),

            _buildSection(
              title: isRussian ? '6. Ваши права' : '6. Your Rights',
              content: isRussian
                  ? 'Вы имеете право:\n\n'
                    '• На доступ: запросить копию ваших данных.\n'
                    '• На исправление: исправить неточные данные.\n'
                    '• На удаление: запросить удаление ваших данных.\n'
                    '• На отзыв согласия: отозвать согласие на обработку данных в любое время.\n\n'
                    'Для реализации ваших прав свяжитесь с нами по email: finance.pulsemoney@gmail.com'
                  : 'You have the right to:\n\n'
                    '• Access: request a copy of your data.\n'
                    '• Rectification: correct inaccurate data.\n'
                    '• Deletion: request deletion of your data.\n'
                    '• Withdraw Consent: withdraw consent for data processing at any time.\n\n'
                    'To exercise your rights, contact us at: finance.pulsemoney@gmail.com',
            ),

            _buildSection(
              title: isRussian ? '7. Безопасность данных' : '7. Data Security',
              content: isRussian
                  ? 'Мы принимаем серьезные меры для защиты ваших данных:\n\n'
                    '• Шифрование: все данные передаются по защищенному протоколу HTTPS.\n'
                    '• Хранение: пароли хранятся в зашифрованном виде.\n'
                    '• Доступ: доступ к данным ограничен только авторизованными сотрудниками.\n'
                    '• Регулярные проверки: мы регулярно обновляем системы безопасности.'
                  : 'We take serious measures to protect your data:\n\n'
                    '• Encryption: all data is transmitted via HTTPS.\n'
                    '• Storage: passwords are stored encrypted.\n'
                    '• Access: access to data is limited to authorized personnel only.\n'
                    '• Regular Audits: we regularly update our security systems.',
            ),

            _buildSection(
              title: isRussian ? '8. Изменения в политике' : '8. Changes to This Policy',
              content: isRussian
                  ? 'Мы можем периодически обновлять эту Политику. Мы уведомим вас о значительных изменениях:\n\n'
                    '• Оповещение: через email или внутри Приложения.\n'
                    '• Дата обновления: всегда указана в начале документа.\n'
                    '• Продолжение использования: означает ваше согласие с обновленной Политикой.'
                  : 'We may update this Policy periodically. We will notify you of significant changes:\n\n'
                    '• Notification: via email or within the Application.\n'
                    '• Update Date: always indicated at the top of the document.\n'
                    '• Continued Use: implies your consent to the updated Policy.',
            ),

            _buildSection(
              title: isRussian ? '9. Контактная информация' : '9. Contact Information',
              content: isRussian
                  ? 'По всем вопросам, связанным с политикой конфиденциальности, обращайтесь:\n\n'
                    '📧 Email: finance.pulsemoney@gmail.com\n'
                    '👤 ИП Махотин Владислав Алишадович\n'
                    '📍 Адрес: Армения, г. Ереван\n\n'
                    'Мы ответим на ваш запрос в течение 30 дней.'
                  : 'For all privacy policy questions, contact us:\n\n'
                    '📧 Email: finance.pulsemoney@gmail.com\n'
                    '👤 IP Makhotin Vladislav Alishadovich\n'
                    '📍 Address: Armenia, Yerevan\n\n'
                    'We will respond to your request within 30 days.',
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                isRussian
                    ? '© 2026 Pulse. Все права защищены.'
                    : '© 2026 Pulse. All rights reserved.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}