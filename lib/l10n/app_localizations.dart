import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
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
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L? of(BuildContext context) {
    return Localizations.of<L>(context, L);
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

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
    Locale('ar'),
    Locale('en'),
  ];

  /// Under the wordmark on the sign-in screen.
  ///
  /// In ar, this message translates to:
  /// **'كل رسائل زبائنك، من إنستغرام وماسنجر، في مكان واحد.'**
  String get tagline;

  /// No description provided for @emailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تسجيل الدخول'**
  String get signingIn;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// Meta's own wording is 'Invalid login credentials', which tells a non-technical seller nothing they can act on.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة.'**
  String get signInWrongCredentials;

  /// No description provided for @signInFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الدخول. {error}'**
  String signInFailed(String error);

  /// The count a seller acts on. Arabic distinguishes singular, dual, and small from large plurals, which a hand-written string cannot do correctly.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أحد ينتظر} =1{زبون واحد ينتظر} =2{زبونان ينتظران} few{{count} زبائن ينتظرون} many{{count} زبوناً ينتظرون} other{{count} زبون ينتظر}}'**
  String customersWaiting(int count);

  /// No description provided for @everyoneAnswered.
  ///
  /// In ar, this message translates to:
  /// **'تمّت الإجابة على الجميع'**
  String get everyoneAnswered;

  /// No description provided for @waitingForReply.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الرد'**
  String get waitingForReply;

  /// No description provided for @answered.
  ///
  /// In ar, this message translates to:
  /// **'تمّت الإجابة'**
  String get answered;

  /// No description provided for @customer.
  ///
  /// In ar, this message translates to:
  /// **'زبون'**
  String get customer;

  /// No description provided for @noConversationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محادثات بعد'**
  String get noConversationsTitle;

  /// No description provided for @noConversationsBody.
  ///
  /// In ar, this message translates to:
  /// **'تظهر الرسائل هنا عندما يراسلك الزبائن. أما ما أُرسل قبل ربط حسابك فيبقى في تطبيقات ميتا.'**
  String get noConversationsBody;

  /// No description provided for @longestWait.
  ///
  /// In ar, this message translates to:
  /// **'أطول انتظار'**
  String get longestWait;

  /// No description provided for @windowExplanation.
  ///
  /// In ar, this message translates to:
  /// **'تُغلق ميتا نافذة الرد بعد 24 ساعة من رسالة الزبون. بعدها لا يمكنك الرد حتى يراسلك من جديد.'**
  String get windowExplanation;

  /// No description provided for @replyWindowClosedShort.
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت نافذة الرد'**
  String get replyWindowClosedShort;

  /// No description provided for @replyWindowClosedLong.
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت نافذة الرد. يمكنك الرد مجدداً عندما يراسلك هذا الزبون.'**
  String get replyWindowClosedLong;

  /// No description provided for @replyingNotBuilt.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الردود غير متاح بعد.'**
  String get replyingNotBuilt;

  /// No description provided for @minutesLeftToReply.
  ///
  /// In ar, this message translates to:
  /// **'{count} د للرد'**
  String minutesLeftToReply(int count);

  /// No description provided for @hoursLeftToReply.
  ///
  /// In ar, this message translates to:
  /// **'{count} س للرد'**
  String hoursLeftToReply(int count);

  /// No description provided for @justNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count} د'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count} س'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count} ي'**
  String daysAgo(int count);

  /// No description provided for @weeksAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count} أ'**
  String weeksAgo(int count);

  /// No description provided for @attachmentPhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get attachmentPhoto;

  /// No description provided for @attachmentVideo.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get attachmentVideo;

  /// No description provided for @attachmentVoice.
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get attachmentVoice;

  /// No description provided for @attachmentFile.
  ///
  /// In ar, this message translates to:
  /// **'ملف'**
  String get attachmentFile;

  /// No description provided for @attachmentShare.
  ///
  /// In ar, this message translates to:
  /// **'منشور مشارَك'**
  String get attachmentShare;

  /// No description provided for @attachmentOther.
  ///
  /// In ar, this message translates to:
  /// **'مرفق'**
  String get attachmentOther;

  /// No description provided for @photoExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية هذه الصورة'**
  String get photoExpired;

  /// No description provided for @backToInbox.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى الوارد'**
  String get backToInbox;

  /// No description provided for @inboxFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الوارد'**
  String get inboxFailedTitle;

  /// No description provided for @inboxFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من اتصالك ثم أعد تحميل الصفحة.'**
  String get inboxFailedBody;

  /// No description provided for @messagesFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل هذه الرسائل'**
  String get messagesFailedTitle;

  /// No description provided for @messagesFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'أعد تحميل الصفحة للمحاولة مرة أخرى.'**
  String get messagesFailedBody;

  /// No description provided for @platformInstagram.
  ///
  /// In ar, this message translates to:
  /// **'إنستغرام'**
  String get platformInstagram;

  /// No description provided for @platformMessenger.
  ///
  /// In ar, this message translates to:
  /// **'ماسنجر'**
  String get platformMessenger;

  /// No description provided for @missingConfigurationTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات ناقصة'**
  String get missingConfigurationTitle;

  /// No description provided for @missingConfigurationBody.
  ///
  /// In ar, this message translates to:
  /// **'قيمتا SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY تُدمجان وقت البناء. شغّل التطبيق مع ‎--dart-define-from-file=env.json‎ — انظر README.md.'**
  String get missingConfigurationBody;

  /// A language names itself. Never translated.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// A language names itself. Never translated.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @pitchOne.
  ///
  /// In ar, this message translates to:
  /// **'محادثات إنستغرام وماسنجر في وارد واحد.'**
  String get pitchOne;

  /// No description provided for @pitchTwo.
  ///
  /// In ar, this message translates to:
  /// **'من ينتظر أطول يظهر في الأعلى.'**
  String get pitchTwo;

  /// No description provided for @pitchThree.
  ///
  /// In ar, this message translates to:
  /// **'تعرف كم بقي لك للرد قبل أن تكتب.'**
  String get pitchThree;

  /// No description provided for @aboutCustomer.
  ///
  /// In ar, this message translates to:
  /// **'عن الزبون'**
  String get aboutCustomer;

  /// No description provided for @detailPlatform.
  ///
  /// In ar, this message translates to:
  /// **'المنصة'**
  String get detailPlatform;

  /// No description provided for @detailFirstWrote.
  ///
  /// In ar, this message translates to:
  /// **'أول رسالة'**
  String get detailFirstWrote;

  /// No description provided for @detailMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get detailMessages;

  /// No description provided for @detailReplyWindow.
  ///
  /// In ar, this message translates to:
  /// **'نافذة الرد'**
  String get detailReplyWindow;

  /// No description provided for @messageCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا رسائل} =1{رسالة واحدة} =2{رسالتان} few{{count} رسائل} many{{count} رسالة} other{{count} رسالة}}'**
  String messageCount(int count);

  /// No description provided for @windowOpen.
  ///
  /// In ar, this message translates to:
  /// **'مفتوحة'**
  String get windowOpen;

  /// No description provided for @windowClosed.
  ///
  /// In ar, this message translates to:
  /// **'مُغلقة'**
  String get windowClosed;

  /// No description provided for @detailsHidden.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get detailsHidden;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LAr();
    case 'en':
      return LEn();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
