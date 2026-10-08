// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get about => 'О приложении';

  @override
  String get accept => 'Принять';

  @override
  String get add => 'Добавить';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get admin => 'Админ';

  @override
  String get advanced => 'Дополнительно';

  @override
  String get appLock => 'Блокировка приложения';

  @override
  String get appLockHint => 'Требовать отпечаток, лицо или PIN устройства';

  @override
  String get appLockUnavailable =>
      'На устройстве не настроена блокировка экрана';

  @override
  String get appLocked => 'Arcana заблокирована';

  @override
  String get appearance => 'Оформление';

  @override
  String get backupData => 'Данные резервной копии';

  @override
  String get backupId => 'Резервная копия ID';

  @override
  String get backupIdHint => 'Экспорт личности с защитой паролем';

  @override
  String get backupInvalid => 'Неверная копия или пароль';

  @override
  String get backupPasswordHint =>
      'Выберите надёжный пароль (мин. 8 символов). Без него копию нельзя восстановить.';

  @override
  String get block => 'Заблокировать';

  @override
  String get callEnded => 'Звонок завершён';

  @override
  String get calls => 'Звонки';

  @override
  String get camera => 'Камера';

  @override
  String get cancel => 'Отмена';

  @override
  String get captionOptional => 'Подпись (необязательно)';

  @override
  String get chats => 'Чаты';

  @override
  String get clearChat => 'Очистить чат';

  @override
  String get clearChatConfirm =>
      'Удалить все сообщения этого чата на устройстве?';

  @override
  String get commonGroups => 'Общие группы';

  @override
  String get connecting => 'Подключение…';

  @override
  String get contactBlocked => 'Вы заблокировали этот контакт';

  @override
  String get contactInfo => 'Информация о контакте';

  @override
  String get contactVerified => 'Контакт подтверждён';

  @override
  String get contacts => 'Контакты';

  @override
  String get copied => 'Скопировано';

  @override
  String get copy => 'Копировать';

  @override
  String get create => 'Создать';

  @override
  String get createId => 'Создать мой ID';

  @override
  String get decline => 'Отклонить';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteChat => 'Удалить чат';

  @override
  String get deleteChatConfirm => 'Чат и сообщения будут удалены с устройства.';

  @override
  String get deleteContact => 'Удалить контакт';

  @override
  String get deleteContactConfirm => 'Удалить контакт и чат?';

  @override
  String get deleteForEveryone => 'Удалить у всех';

  @override
  String get deleteForMe => 'Удалить у меня';

  @override
  String get deleteGroup => 'Удалить группу';

  @override
  String get deleteId => 'Удалить ID';

  @override
  String get deleteIdConfirm =>
      'Ваш ID будет навсегда отозван на сервере, а все данные на устройстве удалены. Это необратимо.';

  @override
  String get deleteIdHint => 'Отозвать личность и стереть все данные';

  @override
  String get dissolveGroup => 'Распустить группу';

  @override
  String get downloadFailed => 'Ошибка загрузки';

  @override
  String get draft => 'Черновик';

  @override
  String get e2eNotice =>
      'Сообщения и звонки защищены сквозным шифрованием. Никто вне чата, даже сервер, не может их прочитать.';

  @override
  String get edit => 'Изменить';

  @override
  String get editMembers => 'Изменить участников';

  @override
  String get editMessage => 'Изменить сообщение';

  @override
  String get editName => 'Изменить имя';

  @override
  String get edited => 'изменено';

  @override
  String get enterId => 'Arcana ID (8 символов)';

  @override
  String get enterSends => 'Enter отправляет';

  @override
  String get errorInvalidId => 'Неверный ID';

  @override
  String get errorKeyMismatch => 'Ключ не соответствует этому ID!';

  @override
  String get errorNotFound => 'ID не найден';

  @override
  String get errorSelf => 'Это ваш собственный ID';

  @override
  String get featureCalls =>
      'Зашифрованные аудио- и видеозвонки, также в группах';

  @override
  String get featureE2E => 'Сквозное шифрование всего';

  @override
  String get featureNoPhone => 'Без номера телефона и e-mail';

  @override
  String get file => 'Файл';

  @override
  String get fileTooLarge => 'Файл слишком большой (макс. 100 МБ)';

  @override
  String get gallery => 'Галерея';

  @override
  String get groupCallActive => 'Идёт групповой звонок';

  @override
  String get groupInfo => 'Информация о группе';

  @override
  String get groupName => 'Название группы';

  @override
  String get groupNameRequired => 'Введите название группы';

  @override
  String get groups => 'Группы';

  @override
  String get id => 'ID';

  @override
  String get identityRevoked =>
      'Этот ID отозван. Переустановите приложение, чтобы создать новый ID.';

  @override
  String get incomingCall => 'Входящий звонок';

  @override
  String get incomingVideoCall => 'Входящий видеозвонок';

  @override
  String get join => 'Присоединиться';

  @override
  String get keyFingerprint => 'Отпечаток ключа';

  @override
  String get language => 'Язык';

  @override
  String get leaveGroup => 'Покинуть группу';

  @override
  String get leaveGroupConfirm =>
      'Вы больше не будете получать сообщения этой группы.';

  @override
  String get location => 'Местоположение';

  @override
  String get messageDeleted => 'Сообщение удалено';

  @override
  String get messageHint => 'Сообщение';

  @override
  String get messageInfo => 'Информация о сообщении';

  @override
  String get micPermission => 'Требуется доступ к микрофону';

  @override
  String get mute => 'Без звука';

  @override
  String get myId => 'Мой ID';

  @override
  String get myIdHint =>
      'Дайте другим отсканировать код, чтобы безопасно добавить вас.';

  @override
  String get newChat => 'Новый чат';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get nickname => 'Псевдоним';

  @override
  String get nicknameOptional => 'Псевдоним (необязательно)';

  @override
  String get noCalls => 'Звонков пока нет';

  @override
  String get noChats => 'Чатов пока нет.\nДобавьте контакт, чтобы начать.';

  @override
  String get noContacts => 'Контактов пока нет';

  @override
  String get notGroupMember => 'Вы больше не участник этой группы';

  @override
  String get notVerified => 'Не подтверждён – отсканируйте QR-код';

  @override
  String get offline => 'Не в сети';

  @override
  String get ok => 'ОК';

  @override
  String get online => 'В сети';

  @override
  String get password => 'Пароль';

  @override
  String get passwordRules =>
      'Пароли должны совпадать и содержать мин. 8 символов';

  @override
  String get pin => 'Закрепить чат';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get privacySummary =>
      'Arcana не собирает номера телефонов, e-mail и контакты. Сообщения зашифрованы и хранятся на сервере только до доставки.';

  @override
  String get profile => 'Профиль';

  @override
  String get readReceipts => 'Отчёты о прочтении';

  @override
  String get readReceiptsHint => 'Контакты видят, когда вы прочитали сообщения';

  @override
  String get recording => 'Запись';

  @override
  String get renameGroup => 'Переименовать группу';

  @override
  String get repeatPassword => 'Повторите пароль';

  @override
  String get reply => 'Ответить';

  @override
  String get restore => 'Восстановить';

  @override
  String get restoreBackup => 'Восстановить ID из копии';

  @override
  String get retry => 'Повторить';

  @override
  String get ringing => 'Вызов…';

  @override
  String get save => 'Сохранить';

  @override
  String get scanQr => 'Сканировать QR-код';

  @override
  String get scanQrHint =>
      'Сканирование QR-кода лично даёт наивысший уровень доверия (подтверждён).';

  @override
  String get search => 'Поиск';

  @override
  String get security => 'Безопасность';

  @override
  String get selectMembers => 'Выберите хотя бы одного участника';

  @override
  String get send => 'Отправить';

  @override
  String get sendImage => 'Отправить изображение';

  @override
  String get sender => 'Отправитель';

  @override
  String get serverAddress => 'Адрес сервера';

  @override
  String get serverUnreachable =>
      'Сервер недоступен. Проверьте подключение к интернету.';

  @override
  String get settings => 'Настройки';

  @override
  String get share => 'Поделиться';

  @override
  String get status => 'Статус';

  @override
  String get statusDelivered => 'Доставлено';

  @override
  String get statusFailed => 'Ошибка';

  @override
  String get statusPending => 'Ожидание';

  @override
  String get statusRead => 'Прочитано';

  @override
  String get statusReceived => 'Получено';

  @override
  String get statusSent => 'Отправлено';

  @override
  String get systemDefault => 'Как в системе';

  @override
  String get theme => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get time => 'Время';

  @override
  String get today => 'Сегодня';

  @override
  String get typing => 'печатает…';

  @override
  String get typingIndicators => 'Индикатор набора';

  @override
  String get unknownContact => 'Этого отправителя нет в ваших контактах.';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get unlockReason => 'Разблокировать Arcana';

  @override
  String get unmute => 'Включить звук';

  @override
  String get unpin => 'Открепить чат';

  @override
  String get verificationLevel => 'Уровень проверки';

  @override
  String get verifiedQr => 'Подтверждён по QR-коду';

  @override
  String get version => 'Версия';

  @override
  String get voiceMessage => 'Голосовое сообщение';

  @override
  String get welcomeText =>
      'Приватный мессенджер без номера телефона. Ваш ID создаётся на этом устройстве.';

  @override
  String get sysYouLeft => 'Вы покинули группу';

  @override
  String get sysYouWereRemoved => 'Вас удалили из группы';

  @override
  String get yesterday => 'Вчера';

  @override
  String get you => 'Вы';

  @override
  String createdBy(String name) {
    return 'Создатель: $name';
  }

  @override
  String incomingGroupCall(String name) {
    return '$name начал(а) групповой звонок';
  }

  @override
  String shareIdText(String id) {
    return 'Пишите мне безопасно в Arcana. Мой ID: $id';
  }

  @override
  String sysGroupCreated(String name) {
    return '$name создал(а) группу';
  }

  @override
  String sysKeyChanged(String name) {
    return 'Ключ безопасности $name изменился';
  }

  @override
  String sysAddedToGroup(String name) {
    return '$name добавил(а) вас в группу';
  }

  @override
  String sysMemberLeft(String name) {
    return '$name покинул(а) группу';
  }

  @override
  String sysMemberAdded(String name, String member) {
    return '$name добавил(а) $member';
  }

  @override
  String sysMemberRemoved(String name, String member) {
    return '$name удалил(а) $member';
  }

  @override
  String sysRenamed(String name, String title) {
    return '$name переименовал(а) группу в «$title»';
  }

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String participants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }
}
