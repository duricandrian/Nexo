import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockHint.
  ///
  /// In en, this message translates to:
  /// **'Require fingerprint, face or device PIN to open'**
  String get appLockHint;

  /// No description provided for @appLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No screen lock set up on this device'**
  String get appLockUnavailable;

  /// No description provided for @appLocked.
  ///
  /// In en, this message translates to:
  /// **'Arcana is locked'**
  String get appLocked;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @backupData.
  ///
  /// In en, this message translates to:
  /// **'Backup data'**
  String get backupData;

  /// No description provided for @backupId.
  ///
  /// In en, this message translates to:
  /// **'Back up ID'**
  String get backupId;

  /// No description provided for @backupIdHint.
  ///
  /// In en, this message translates to:
  /// **'Password-protected export of your identity'**
  String get backupIdHint;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'Backup or password is wrong'**
  String get backupInvalid;

  /// No description provided for @backupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a strong password (min. 8 characters). Without it the backup cannot be restored.'**
  String get backupPasswordHint;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @calls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get calls;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @captionOptional.
  ///
  /// In en, this message translates to:
  /// **'Caption (optional)'**
  String get captionOptional;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get clearChat;

  /// No description provided for @clearChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all messages in this chat on this device?'**
  String get clearChatConfirm;

  /// No description provided for @commonGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups in common'**
  String get commonGroups;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @contactBlocked.
  ///
  /// In en, this message translates to:
  /// **'You blocked this contact'**
  String get contactBlocked;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact info'**
  String get contactInfo;

  /// No description provided for @contactVerified.
  ///
  /// In en, this message translates to:
  /// **'Contact verified'**
  String get contactVerified;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createId.
  ///
  /// In en, this message translates to:
  /// **'Create my ID'**
  String get createId;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// No description provided for @deleteChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'This chat and its messages will be deleted from this device.'**
  String get deleteChatConfirm;

  /// No description provided for @deleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete contact'**
  String get deleteContact;

  /// No description provided for @deleteContactConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this contact and the chat?'**
  String get deleteContactConfirm;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @deleteId.
  ///
  /// In en, this message translates to:
  /// **'Delete ID'**
  String get deleteId;

  /// No description provided for @deleteIdConfirm.
  ///
  /// In en, this message translates to:
  /// **'Your ID will be permanently revoked on the server and all data on this device deleted. This cannot be undone.'**
  String get deleteIdConfirm;

  /// No description provided for @deleteIdHint.
  ///
  /// In en, this message translates to:
  /// **'Revoke identity and erase all data'**
  String get deleteIdHint;

  /// No description provided for @dissolveGroup.
  ///
  /// In en, this message translates to:
  /// **'Dissolve group'**
  String get dissolveGroup;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @e2eNotice.
  ///
  /// In en, this message translates to:
  /// **'Messages and calls are end-to-end encrypted. Nobody outside this chat, not even the server, can read them.'**
  String get e2eNotice;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editMembers.
  ///
  /// In en, this message translates to:
  /// **'Edit members'**
  String get editMembers;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessage;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @enterId.
  ///
  /// In en, this message translates to:
  /// **'Arcana ID (8 characters)'**
  String get enterId;

  /// No description provided for @enterSends.
  ///
  /// In en, this message translates to:
  /// **'Enter key sends'**
  String get enterSends;

  /// No description provided for @errorInvalidId.
  ///
  /// In en, this message translates to:
  /// **'Invalid ID'**
  String get errorInvalidId;

  /// No description provided for @errorKeyMismatch.
  ///
  /// In en, this message translates to:
  /// **'The key does not match this ID!'**
  String get errorKeyMismatch;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'ID not found'**
  String get errorNotFound;

  /// No description provided for @errorSelf.
  ///
  /// In en, this message translates to:
  /// **'That is your own ID'**
  String get errorSelf;

  /// No description provided for @featureCalls.
  ///
  /// In en, this message translates to:
  /// **'Encrypted voice & video calls, also in groups'**
  String get featureCalls;

  /// No description provided for @featureE2E.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption for everything'**
  String get featureE2E;

  /// No description provided for @featureNoPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone number, no e-mail'**
  String get featureNoPhone;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large (max. 100 MB)'**
  String get fileTooLarge;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @groupCallActive.
  ///
  /// In en, this message translates to:
  /// **'Group call in progress'**
  String get groupCallActive;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfo;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name'**
  String get groupNameRequired;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// No description provided for @identityRevoked.
  ///
  /// In en, this message translates to:
  /// **'This ID has been revoked. Please reinstall the app to create a new ID.'**
  String get identityRevoked;

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get incomingCall;

  /// No description provided for @incomingVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get incomingVideoCall;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @keyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Key fingerprint'**
  String get keyFingerprint;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will no longer receive messages from this group.'**
  String get leaveGroupConfirm;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get messageDeleted;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @messageInfo.
  ///
  /// In en, this message translates to:
  /// **'Message info'**
  String get messageInfo;

  /// No description provided for @micPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required'**
  String get micPermission;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get mute;

  /// No description provided for @myId.
  ///
  /// In en, this message translates to:
  /// **'My ID'**
  String get myId;

  /// No description provided for @myIdHint.
  ///
  /// In en, this message translates to:
  /// **'Let others scan this code to add you securely.'**
  String get myIdHint;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @nicknameOptional.
  ///
  /// In en, this message translates to:
  /// **'Nickname (optional)'**
  String get nicknameOptional;

  /// No description provided for @noCalls.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get noCalls;

  /// No description provided for @noChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet.\nAdd a contact to start chatting.'**
  String get noChats;

  /// No description provided for @noContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get noContacts;

  /// No description provided for @notGroupMember.
  ///
  /// In en, this message translates to:
  /// **'You are no longer a member of this group'**
  String get notGroupMember;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified – scan QR code to verify'**
  String get notVerified;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordRules.
  ///
  /// In en, this message translates to:
  /// **'Passwords must match and have at least 8 characters'**
  String get passwordRules;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin chat'**
  String get pin;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @privacySummary.
  ///
  /// In en, this message translates to:
  /// **'Arcana does not collect phone numbers, e-mails or contacts. Messages are end-to-end encrypted and stored on the server only until delivered.'**
  String get privacySummary;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @readReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get readReceipts;

  /// No description provided for @readReceiptsHint.
  ///
  /// In en, this message translates to:
  /// **'Let contacts see when you read their messages'**
  String get readReceiptsHint;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get renameGroup;

  /// No description provided for @repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get repeatPassword;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore ID from backup'**
  String get restoreBackup;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @ringing.
  ///
  /// In en, this message translates to:
  /// **'Ringing…'**
  String get ringing;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQr;

  /// No description provided for @scanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scanning the QR code in person gives the highest trust level (verified).'**
  String get scanQrHint;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @selectMembers.
  ///
  /// In en, this message translates to:
  /// **'Select at least one member'**
  String get selectMembers;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendImage.
  ///
  /// In en, this message translates to:
  /// **'Send image'**
  String get sendImage;

  /// No description provided for @sender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get sender;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. Check your internet connection.'**
  String get serverUnreachable;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get statusRead;

  /// No description provided for @statusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get statusReceived;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typing;

  /// No description provided for @typingIndicators.
  ///
  /// In en, this message translates to:
  /// **'Typing indicator'**
  String get typingIndicators;

  /// No description provided for @unknownContact.
  ///
  /// In en, this message translates to:
  /// **'This sender is not in your contacts.'**
  String get unknownContact;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Arcana'**
  String get unlockReason;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute notifications'**
  String get unmute;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin chat'**
  String get unpin;

  /// No description provided for @verificationLevel.
  ///
  /// In en, this message translates to:
  /// **'Verification level'**
  String get verificationLevel;

  /// No description provided for @verifiedQr.
  ///
  /// In en, this message translates to:
  /// **'Verified by QR code'**
  String get verifiedQr;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @welcomeText.
  ///
  /// In en, this message translates to:
  /// **'Private messaging without phone number. Your ID is created on this device.'**
  String get welcomeText;

  /// No description provided for @sysYouLeft.
  ///
  /// In en, this message translates to:
  /// **'You left the group'**
  String get sysYouLeft;

  /// No description provided for @sysYouWereRemoved.
  ///
  /// In en, this message translates to:
  /// **'You were removed from the group'**
  String get sysYouWereRemoved;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String createdBy(String name);

  /// No description provided for @incomingGroupCall.
  ///
  /// In en, this message translates to:
  /// **'{name} started a group call'**
  String incomingGroupCall(String name);

  /// No description provided for @shareIdText.
  ///
  /// In en, this message translates to:
  /// **'Chat with me securely on Arcana. My ID: {id}'**
  String shareIdText(String id);

  /// No description provided for @sysGroupCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} created the group'**
  String sysGroupCreated(String name);

  /// No description provided for @sysKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'Security key of {name} changed'**
  String sysKeyChanged(String name);

  /// No description provided for @sysAddedToGroup.
  ///
  /// In en, this message translates to:
  /// **'{name} added you to the group'**
  String sysAddedToGroup(String name);

  /// No description provided for @sysMemberLeft.
  ///
  /// In en, this message translates to:
  /// **'{name} left the group'**
  String sysMemberLeft(String name);

  /// No description provided for @sysMemberAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added {member}'**
  String sysMemberAdded(String name, String member);

  /// No description provided for @sysMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed {member}'**
  String sysMemberRemoved(String name, String member);

  /// No description provided for @sysRenamed.
  ///
  /// In en, this message translates to:
  /// **'{name} renamed the group to \"{title}\"'**
  String sysRenamed(String name, String title);

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String membersCount(int count);

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}'**
  String participants(int count);
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
      <String>['de', 'en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
