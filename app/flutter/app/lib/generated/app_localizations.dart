import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('ru'),
    Locale('uz')
  ];

  /// No description provided for @appTitle.
  ///
  /// In uz, this message translates to:
  /// **'TexERP'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get loginTitle;

  /// No description provided for @phoneNumber.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqam'**
  String get phoneNumber;

  /// No description provided for @pinLabel.
  ///
  /// In uz, this message translates to:
  /// **'PIN kod'**
  String get pinLabel;

  /// No description provided for @loginButton.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get loginButton;

  /// No description provided for @forgotPin.
  ///
  /// In uz, this message translates to:
  /// **'PIN kodini unutdingizmi?'**
  String get forgotPin;

  /// No description provided for @wrongPin.
  ///
  /// In uz, this message translates to:
  /// **'Noto\'g\'ri PIN kod'**
  String get wrongPin;

  /// No description provided for @accountLocked.
  ///
  /// In uz, this message translates to:
  /// **'Hisob 15 daqiqaga bloklandi'**
  String get accountLocked;

  /// No description provided for @phoneNotFound.
  ///
  /// In uz, this message translates to:
  /// **'Bu raqam ro\'yxatdan o\'tmagan'**
  String get phoneNotFound;

  /// No description provided for @profile.
  ///
  /// In uz, this message translates to:
  /// **'Profilim'**
  String get profile;

  /// No description provided for @fullName.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq ism'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In uz, this message translates to:
  /// **'Telefon'**
  String get phone;

  /// No description provided for @workerCode.
  ///
  /// In uz, this message translates to:
  /// **'Ishchi kodi'**
  String get workerCode;

  /// No description provided for @role.
  ///
  /// In uz, this message translates to:
  /// **'Rol'**
  String get role;

  /// No description provided for @department.
  ///
  /// In uz, this message translates to:
  /// **'Bo\'lim'**
  String get department;

  /// No description provided for @foreman.
  ///
  /// In uz, this message translates to:
  /// **'Brigadir'**
  String get foreman;

  /// No description provided for @changePin.
  ///
  /// In uz, this message translates to:
  /// **'PIN kodni o\'zgartirish'**
  String get changePin;

  /// No description provided for @language.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Chiqasizmi?'**
  String get logoutConfirm;

  /// No description provided for @logoutMessage.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingizdan chiqasiz. Oflayn saqlangan yozuvlar yo\'qolmaydi.'**
  String get logoutMessage;

  /// No description provided for @cancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get cancel;

  /// No description provided for @confirmLogout.
  ///
  /// In uz, this message translates to:
  /// **'Ha, chiqish'**
  String get confirmLogout;

  /// No description provided for @worker.
  ///
  /// In uz, this message translates to:
  /// **'Ishchi'**
  String get worker;

  /// No description provided for @foreman_role.
  ///
  /// In uz, this message translates to:
  /// **'Brigadir'**
  String get foreman_role;

  /// No description provided for @accountant.
  ///
  /// In uz, this message translates to:
  /// **'Buxgalter'**
  String get accountant;

  /// No description provided for @director.
  ///
  /// In uz, this message translates to:
  /// **'Direktor'**
  String get director;

  /// No description provided for @home.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa'**
  String get home;

  /// No description provided for @currentPin.
  ///
  /// In uz, this message translates to:
  /// **'Joriy PIN kodingizni kiriting'**
  String get currentPin;

  /// No description provided for @newPin.
  ///
  /// In uz, this message translates to:
  /// **'Yangi PIN kodni kiriting'**
  String get newPin;

  /// No description provided for @confirmNewPin.
  ///
  /// In uz, this message translates to:
  /// **'Yangi PIN kodni tasdiqlang'**
  String get confirmNewPin;

  /// No description provided for @pinChanged.
  ///
  /// In uz, this message translates to:
  /// **'PIN kod muvaffaqiyatli o\'zgartirildi'**
  String get pinChanged;

  /// No description provided for @pinMismatch.
  ///
  /// In uz, this message translates to:
  /// **'PIN kodlar mos emas'**
  String get pinMismatch;

  /// No description provided for @simplePinWarning.
  ///
  /// In uz, this message translates to:
  /// **'Oddiy PIN koddan foydalanmang'**
  String get simplePinWarning;

  /// No description provided for @version.
  ///
  /// In uz, this message translates to:
  /// **'Versiya'**
  String get version;

  /// No description provided for @submit.
  ///
  /// In uz, this message translates to:
  /// **'Kiritish'**
  String get submit;

  /// No description provided for @history.
  ///
  /// In uz, this message translates to:
  /// **'Tarix'**
  String get history;

  /// No description provided for @queue.
  ///
  /// In uz, this message translates to:
  /// **'Navbat'**
  String get queue;

  /// No description provided for @team.
  ///
  /// In uz, this message translates to:
  /// **'Jamoa'**
  String get team;

  /// No description provided for @periods.
  ///
  /// In uz, this message translates to:
  /// **'Davr'**
  String get periods;

  /// No description provided for @records.
  ///
  /// In uz, this message translates to:
  /// **'Yozuvlar'**
  String get records;

  /// No description provided for @workers.
  ///
  /// In uz, this message translates to:
  /// **'Ishchilar'**
  String get workers;

  /// No description provided for @departments.
  ///
  /// In uz, this message translates to:
  /// **'Bo\'limlar'**
  String get departments;

  /// No description provided for @catalog.
  ///
  /// In uz, this message translates to:
  /// **'Katalog'**
  String get catalog;

  /// No description provided for @comingSoon.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada'**
  String get comingSoon;

  /// No description provided for @offlineMessage.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasi yo\'q. Iltimos, ulanishni tekshiring.'**
  String get offlineMessage;

  /// No description provided for @retry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get retry;

  /// No description provided for @unknownError.
  ///
  /// In uz, this message translates to:
  /// **'Noma\'lum xatolik'**
  String get unknownError;

  /// No description provided for @invalidPhone.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqam noto\'g\'ri'**
  String get invalidPhone;

  /// No description provided for @pinLengthError.
  ///
  /// In uz, this message translates to:
  /// **'PIN kod 4 ta raqamdan iborat bo\'lishi kerak'**
  String get pinLengthError;

  /// No description provided for @currentPinIncorrect.
  ///
  /// In uz, this message translates to:
  /// **'Joriy PIN kod noto\'g\'ri'**
  String get currentPinIncorrect;

  /// No description provided for @languageUz.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekcha'**
  String get languageUz;

  /// No description provided for @languageRu.
  ///
  /// In uz, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @notifications.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get notifications;

  /// No description provided for @noNetwork.
  ///
  /// In uz, this message translates to:
  /// **'Tarmoq aloqasi yo\'q'**
  String get noNetwork;

  /// No description provided for @settings.
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalar'**
  String get settings;
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
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
