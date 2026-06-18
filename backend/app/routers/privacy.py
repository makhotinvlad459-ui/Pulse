from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["privacy"])

@router.get("/privacy", response_class=HTMLResponse)
async def privacy_policy(request: Request):
    # Определяем язык по заголовку Accept-Language
    accept_lang = request.headers.get("accept-language", "ru")
    lang = "ru" if "ru" in accept_lang else "en"
    
    if lang == "ru":
        title = "Политика конфиденциальности"
        content = """
        <h1>Политика конфиденциальности</h1>
        <p><strong>Последнее обновление:</strong> 18 июня 2026 г.</p>

        <h2>1. Введение</h2>
        <p>Индивидуальный предприниматель Махотин Владислав Алишадович (далее — "Мы", "Нас", "Наш") уважает вашу конфиденциальность. Настоящая Политика конфиденциальности описывает, как мы собираем, используем и защищаем вашу личную информацию при использовании нашего мобильного приложения Pulse (далее — "Приложение").</p>

        <h2>2. Какие данные мы собираем</h2>
        <p>Мы собираем только те данные, которые необходимы для работы Приложения и предоставления вам наших услуг:</p>
        <ul>
            <li><strong>Регистрационные данные:</strong> адрес электронной почты, номер телефона, имя и фамилия.</li>
            <li><strong>Данные о компаниях:</strong> название, ИНН, юридический адрес.</li>
            <li><strong>Финансовые данные:</strong> информация о транзакциях, счетах и платежах.</li>
            <li><strong>Технические данные:</strong> информация об устройстве, IP-адрес, данные о взаимодействии с Приложением.</li>
            <li><strong>Данные о местоположении:</strong> только с вашего явного согласия, только для функций, которые требуют этой информации.</li>
        </ul>

        <h2>3. Как мы используем ваши данные</h2>
        <p>Ваши данные используются исключительно для следующих целей:</p>
        <ul>
            <li><strong>Предоставление услуг:</strong> регистрация, управление компаниями, обработка платежей.</li>
            <li><strong>Улучшение Приложения:</strong> анализ использования для повышения качества и стабильности.</li>
            <li><strong>Уведомления:</strong> отправка важных сообщений о работе Приложения.</li>
            <li><strong>Безопасность:</strong> защита от мошенничества и несанкционированного доступа.</li>
        </ul>
        <p>Мы не используем ваши данные для рекламных целей и не передаем их третьим лицам без вашего согласия.</p>

        <h2>4. Передача данных третьим лицам</h2>
        <p>Мы можем передавать ваши данные только в следующих случаях:</p>
        <ul>
            <li><strong>Поставщики услуг:</strong> платежные системы (ЮKassa – только для веб-версии, Google Play, App Store), хостинг-провайдеры.</li>
            <li><strong>Уведомления:</strong> Firebase Cloud Messaging для отправки push-уведомлений.</li>
            <li><strong>Аналитика:</strong> для сбора анонимной статистики использования (без привязки к личности).</li>
            <li><strong>По требованию закона:</strong> в случаях, предусмотренных законодательством.</li>
        </ul>
        <p>Все третьи стороны обязаны соблюдать конфиденциальность ваших данных.</p>

        <h2>5. Срок хранения и удаление данных</h2>
        <p>Мы храним ваши данные только в течение необходимого срока:</p>
        <ul>
            <li><strong>Аккаунт:</strong> данные хранятся до тех пор, пока вы пользуетесь Приложением.</li>
            <li><strong>Удаление:</strong> вы можете удалить свои данные в любой момент через настройки профиля.</li>
            <li><strong>Запрос на удаление:</strong> вы можете обратиться к нам с запросом на полное удаление данных.</li>
            <li><strong>Срок хранения:</strong> после удаления аккаунта данные будут удалены в течение 30 дней.</li>
        </ul>

        <h2>6. Ваши права</h2>
        <p>Вы имеете право:</p>
        <ul>
            <li><strong>На доступ:</strong> запросить копию ваших данных.</li>
            <li><strong>На исправление:</strong> исправить неточные данные.</li>
            <li><strong>На удаление:</strong> запросить удаление ваших данных.</li>
            <li><strong>На отзыв согласия:</strong> отозвать согласие на обработку данных в любое время.</li>
        </ul>
        <p>Для реализации ваших прав свяжитесь с нами по email: <a href="mailto:finance.pulsemoney@gmail.com">finance.pulsemoney@gmail.com</a></p>

        <h2>7. Безопасность данных</h2>
        <ul>
            <li><strong>Шифрование:</strong> все данные передаются по защищенному протоколу HTTPS.</li>
            <li><strong>Хранение:</strong> пароли хранятся в зашифрованном виде.</li>
            <li><strong>Доступ:</strong> доступ к данным ограничен только авторизованными сотрудниками.</li>
            <li><strong>Регулярные проверки:</strong> мы регулярно обновляем системы безопасности.</li>
        </ul>

        <h2>8. Изменения в политике</h2>
        <ul>
            <li><strong>Оповещение:</strong> через email или внутри Приложения.</li>
            <li><strong>Дата обновления:</strong> всегда указана в начале документа.</li>
            <li><strong>Продолжение использования:</strong> означает ваше согласие с обновленной Политикой.</li>
        </ul>

        <h2>9. Контактная информация</h2>
        <p>📧 <strong>Email:</strong> <a href="mailto:finance.pulsemoney@gmail.com">finance.pulsemoney@gmail.com</a><br>
        👤 <strong>ИП Махотин Владислав Алишадович</strong><br>
        📍 <strong>Адрес:</strong> Армения, г. Ереван</p>
        <p>Мы ответим на ваш запрос в течение 30 дней.</p>

        <hr>
        <p>© 2026 Pulse. Все права защищены.</p>
        """
    else:
        title = "Privacy Policy"
        content = """
        <h1>Privacy Policy</h1>
        <p><strong>Last updated:</strong> June 18, 2026</p>

        <h2>1. Introduction</h2>
        <p>Individual Entrepreneur Makhotin Vladislav Alishadovich (hereinafter — "We", "Us", "Our") respects your privacy. This Privacy Policy describes how we collect, use and protect your personal information when you use our mobile application Pulse (hereinafter — the "Application").</p>

        <h2>2. What Data We Collect</h2>
        <p>We collect only the data necessary for the Application to work and to provide you with our services:</p>
        <ul>
            <li><strong>Registration data:</strong> email address, phone number, first and last name.</li>
            <li><strong>Company data:</strong> name, TIN, legal address.</li>
            <li><strong>Financial data:</strong> information about transactions, accounts, and payments.</li>
            <li><strong>Technical data:</strong> device information, IP address, data on interaction with the Application.</li>
            <li><strong>Location data:</strong> only with your explicit consent, only for features that require this information.</li>
        </ul>

        <h2>3. How We Use Your Data</h2>
        <p>Your data is used exclusively for the following purposes:</p>
        <ul>
            <li><strong>Service Provision:</strong> registration, company management, payment processing.</li>
            <li><strong>Application Improvement:</strong> usage analysis to improve quality and stability.</li>
            <li><strong>Notifications:</strong> sending important messages about the Application.</li>
            <li><strong>Security:</strong> protection against fraud and unauthorized access.</li>
        </ul>
        <p>We do not use your data for advertising purposes and do not share it with third parties without your consent.</p>

        <h2>4. Data Sharing with Third Parties</h2>
        <p>We may share your data only in the following cases:</p>
        <ul>
            <li><strong>Service Providers:</strong> payment systems (YooKassa – only for the web version, Google Play, App Store), hosting providers.</li>
            <li><strong>Notifications:</strong> Firebase Cloud Messaging for sending push notifications.</li>
            <li><strong>Analytics:</strong> for collecting anonymous usage statistics (without personal identification).</li>
            <li><strong>As Required by Law:</strong> in cases provided for by legislation.</li>
        </ul>
        <p>All third parties are required to maintain the confidentiality of your data.</p>

        <h2>5. Data Retention and Deletion</h2>
        <p>We store your data only for as long as necessary:</p>
        <ul>
            <li><strong>Account:</strong> data is stored as long as you use the Application.</li>
            <li><strong>Deletion:</strong> you can delete your data at any time through your profile settings.</li>
            <li><strong>Deletion Request:</strong> you can contact us with a request for complete data deletion.</li>
            <li><strong>Retention Period:</strong> after account deletion, data will be deleted within 30 days.</li>
        </ul>

        <h2>6. Your Rights</h2>
        <p>You have the right to:</p>
        <ul>
            <li><strong>Access:</strong> request a copy of your data.</li>
            <li><strong>Rectification:</strong> correct inaccurate data.</li>
            <li><strong>Deletion:</strong> request deletion of your data.</li>
            <li><strong>Withdraw Consent:</strong> withdraw consent for data processing at any time.</li>
        </ul>
        <p>To exercise your rights, contact us at: <a href="mailto:finance.pulsemoney@gmail.com">finance.pulsemoney@gmail.com</a></p>

        <h2>7. Data Security</h2>
        <ul>
            <li><strong>Encryption:</strong> all data is transmitted via HTTPS.</li>
            <li><strong>Storage:</strong> passwords are stored encrypted.</li>
            <li><strong>Access:</strong> access to data is limited to authorized personnel only.</li>
            <li><strong>Regular Audits:</strong> we regularly update our security systems.</li>
        </ul>

        <h2>8. Changes to This Policy</h2>
        <ul>
            <li><strong>Notification:</strong> via email or within the Application.</li>
            <li><strong>Update Date:</strong> always indicated at the top of the document.</li>
            <li><strong>Continued Use:</strong> implies your consent to the updated Policy.</li>
        </ul>

        <h2>9. Contact Information</h2>
        <p>📧 <strong>Email:</strong> <a href="mailto:finance.pulsemoney@gmail.com">finance.pulsemoney@gmail.com</a><br>
        👤 <strong>IP Makhotin Vladislav Alishadovich</strong><br>
        📍 <strong>Address:</strong> Armenia, Yerevan</p>
        <p>We will respond to your request within 30 days.</p>

        <hr>
        <p>© 2026 Pulse. All rights reserved.</p>
        """

    html = f"""
    <!DOCTYPE html>
    <html lang="{lang}">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{title}</title>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                line-height: 1.6;
                max-width: 800px;
                margin: 40px auto;
                padding: 0 20px;
                color: #333;
                background: #f9f9f9;
            }}
            h1, h2 {{
                color: #222;
            }}
            a {{
                color: #1a73e8;
            }}
            hr {{
                border: none;
                border-top: 1px solid #ddd;
                margin: 40px 0;
            }}
            ul {{
                padding-left: 20px;
            }}
        </style>
    </head>
    <body>
        {content}
    </body>
    </html>
    """
    return HTMLResponse(content=html)