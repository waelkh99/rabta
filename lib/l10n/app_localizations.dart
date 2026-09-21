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

  /// No description provided for @menu.
  ///
  /// In ar, this message translates to:
  /// **'التنقّل'**
  String get menu;

  /// No description provided for @inbox.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get inbox;

  /// No description provided for @shop.
  ///
  /// In ar, this message translates to:
  /// **'المتجر'**
  String get shop;

  /// No description provided for @shopCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get shopCurrency;

  /// No description provided for @shopCurrencyBody.
  ///
  /// In ar, this message translates to:
  /// **'تُكتب كما تكتبها لزبونك، ويعيدها المساعد كما هي.'**
  String get shopCurrencyBody;

  /// No description provided for @shopDelivery.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل'**
  String get shopDelivery;

  /// No description provided for @shopDeliveryBody.
  ///
  /// In ar, this message translates to:
  /// **'المناطق التي توصل إليها وأجرة كل منها. هذا ما يجيب به المساعد عن «قديش التوصيل».'**
  String get shopDeliveryBody;

  /// No description provided for @shopDeliveryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تُضف أي منطقة بعد.'**
  String get shopDeliveryEmpty;

  /// No description provided for @shopZoneAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف منطقة'**
  String get shopZoneAdd;

  /// No description provided for @shopZoneName.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get shopZoneName;

  /// No description provided for @shopZoneFee.
  ///
  /// In ar, this message translates to:
  /// **'الأجرة'**
  String get shopZoneFee;

  /// No description provided for @shopZoneFeeHint.
  ///
  /// In ar, this message translates to:
  /// **'اتركها فارغة إذا كانت الأجرة تختلف. سيقول المساعد إنها تعتمد، ولن يخترع رقماً.'**
  String get shopZoneFeeHint;

  /// No description provided for @shopZoneNoFee.
  ///
  /// In ar, this message translates to:
  /// **'تعتمد'**
  String get shopZoneNoFee;

  /// No description provided for @shopDeliveryNote.
  ///
  /// In ar, this message translates to:
  /// **'قواعد أخرى للتوصيل'**
  String get shopDeliveryNote;

  /// No description provided for @shopDeliveryNoteHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: مجاني فوق 50 ديناراً، أو التوصيل داخل عمّان بنفس اليوم.'**
  String get shopDeliveryNoteHint;

  /// No description provided for @shopLocations.
  ///
  /// In ar, this message translates to:
  /// **'مواقع المتجر'**
  String get shopLocations;

  /// No description provided for @shopLocationsHint.
  ///
  /// In ar, this message translates to:
  /// **'العنوان أو مكان الاستلام. اكتب كل فرع في سطر.'**
  String get shopLocationsHint;

  /// No description provided for @shopHours.
  ///
  /// In ar, this message translates to:
  /// **'أوقات الدوام'**
  String get shopHours;

  /// No description provided for @shopHoursHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: السبت إلى الخميس من 10 صباحاً إلى 8 مساءً، الجمعة مغلق.'**
  String get shopHoursHint;

  /// No description provided for @shopAbout.
  ///
  /// In ar, this message translates to:
  /// **'معلومات أخرى'**
  String get shopAbout;

  /// No description provided for @shopAboutBody.
  ///
  /// In ar, this message translates to:
  /// **'أي شيء آخر تريد أن يعرفه المساعد: طريقة الطلب، الدفع عند الاستلام، الإرجاع، أو أي تفصيل يخصك.'**
  String get shopAboutBody;

  /// No description provided for @shopAboutHint.
  ///
  /// In ar, this message translates to:
  /// **'يقرأه المساعد كما كتبته. هذا أيضاً مكانك لتصحيحه إذا ظل يخطئ في شيء.'**
  String get shopAboutHint;

  /// No description provided for @products.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get products;

  /// No description provided for @productsBody.
  ///
  /// In ar, this message translates to:
  /// **'ما تبيعه، ليعرف المساعد بماذا يجيب. الاسم والسعر يكفيان.'**
  String get productsBody;

  /// No description provided for @productsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات بعد.'**
  String get productsEmpty;

  /// No description provided for @productAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف منتجاً'**
  String get productAdd;

  /// No description provided for @productEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get productEdit;

  /// No description provided for @productDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get productDelete;

  /// No description provided for @productSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get productSave;

  /// No description provided for @productName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get productName;

  /// No description provided for @productPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get productPrice;

  /// No description provided for @productDescription.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get productDescription;

  /// No description provided for @productInStock.
  ///
  /// In ar, this message translates to:
  /// **'متوفر'**
  String get productInStock;

  /// No description provided for @productOutOfStock.
  ///
  /// In ar, this message translates to:
  /// **'غير متوفر'**
  String get productOutOfStock;

  /// No description provided for @productDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا المنتج؟'**
  String get productDeleteTitle;

  /// No description provided for @productDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'لن يذكره المساعد بعد الآن. {name}'**
  String productDeleteBody(String name);

  /// No description provided for @productDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get productDeleteConfirm;

  /// No description provided for @catalogSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحفظ. حاول مرة أخرى.'**
  String get catalogSaveFailed;

  /// No description provided for @catalogFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح المنتجات'**
  String get catalogFailed;

  /// No description provided for @catalogFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من اتصالك ثم أعد المحاولة.'**
  String get catalogFailedBody;

  /// No description provided for @catalogPaste.
  ///
  /// In ar, this message translates to:
  /// **'لصق قائمة'**
  String get catalogPaste;

  /// No description provided for @catalogPasteBody.
  ///
  /// In ar, this message translates to:
  /// **'انسخ الصفوف من ملف إكسل أو من جدول جوجل، ثم الصقها هنا. تُضاف إلى قائمتك ولا تستبدلها.'**
  String get catalogPasteBody;

  /// No description provided for @catalogPasteHint.
  ///
  /// In ar, this message translates to:
  /// **'الصق الصفوف هنا'**
  String get catalogPasteHint;

  /// No description provided for @catalogPasteAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get catalogPasteAdd;

  /// No description provided for @catalogPasteNothing.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد أي منتج في ما لصقته.'**
  String get catalogPasteNothing;

  /// No description provided for @catalogPasteAdded.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم يُضف شيء} =1{أُضيف منتج واحد} =2{أُضيف منتجان} few{أُضيفت {count} منتجات} many{أُضيف {count} منتجاً} other{أُضيف {count} منتج}}'**
  String catalogPasteAdded(int count);

  /// No description provided for @catalogTemplateCopy.
  ///
  /// In ar, this message translates to:
  /// **'انسخ نموذجاً فارغاً'**
  String get catalogTemplateCopy;

  /// No description provided for @catalogTemplateCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ النموذج. الصقه في إكسل.'**
  String get catalogTemplateCopied;

  /// No description provided for @assistantTitle.
  ///
  /// In ar, this message translates to:
  /// **'المساعد'**
  String get assistantTitle;

  /// No description provided for @assistantBody.
  ///
  /// In ar, this message translates to:
  /// **'يرد على زبائنك من قائمتك، ويقترح عليهم ما قد يناسبهم، ويحوّل إليك كل ما لا يصح أن يجيب عنه بنفسه.'**
  String get assistantBody;

  /// No description provided for @assistantNeedsCatalog.
  ///
  /// In ar, this message translates to:
  /// **'أضف منتجاً أولاً. من دون قائمة لا يملك المساعد ما يجيب به.'**
  String get assistantNeedsCatalog;

  /// On a message the assistant sent instead of the seller. The bubble is already a different colour; this is the wording a seller who cannot tell the two colours apart relies on, so it has to say plainly who wrote it.
  ///
  /// In ar, this message translates to:
  /// **'رد تلقائي'**
  String get sentAutomatically;

  /// On a row in the inbox whose last reply was the assistant's. Not a warning — the seller may want to read what it said, and this is how they know there is something to read.
  ///
  /// In ar, this message translates to:
  /// **'أجاب المساعد'**
  String get answeredByAssistant;

  /// The general hand-over line on an inbox row, used when the assistant wrote no reason of its own or the reason is a kind the interface has not met before. Never reads as an error: handing a conversation over is a good outcome.
  ///
  /// In ar, this message translates to:
  /// **'حوّلها المساعد إليك'**
  String get broughtToYou;

  /// No description provided for @escalatedWindowClosed.
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت نافذة الرد قبل أن يجيب'**
  String get escalatedWindowClosed;

  /// No description provided for @escalatedAiStreak.
  ///
  /// In ar, this message translates to:
  /// **'أجاب مرات متتالية هنا، والدور عليك'**
  String get escalatedAiStreak;

  /// No description provided for @escalatedSellerPresent.
  ///
  /// In ar, this message translates to:
  /// **'كنت ترد بنفسك، فلم يتدخّل'**
  String get escalatedSellerPresent;

  /// No description provided for @escalatedCeiling.
  ///
  /// In ar, this message translates to:
  /// **'بلغ المساعد حدّه لهذا الشهر'**
  String get escalatedCeiling;

  /// No description provided for @escalatedUngrounded.
  ///
  /// In ar, this message translates to:
  /// **'كاد يقول ما لم تكتبه، فتوقّف'**
  String get escalatedUngrounded;

  /// The reply never reached the customer at all, which is the one of these the seller must act on fastest.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال رده'**
  String get escalatedNotSent;

  /// The body of a system notification. The customer's own words are deliberately not quoted: a notification shows on a locked screen and over a shared desk, and what a customer writes to a shop is theirs.
  ///
  /// In ar, this message translates to:
  /// **'راسلك'**
  String get alertWrote;

  /// No description provided for @alertHandedOver.
  ///
  /// In ar, this message translates to:
  /// **'حوّلها المساعد إليك'**
  String get alertHandedOver;

  /// A menu row with a switch. The switch carries on and off, so the label is a noun rather than an instruction.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get alerts;

  /// Refused once, and no browser asks a second time. Said plainly instead of leaving a switch that would do nothing.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات محظورة في المتصفّح'**
  String get alertsDenied;

  /// Safari on iPhone has no notification API for a site open in a tab — the seller has to add Rabta to the home screen first. Not the same as refused, and it must not read as an error.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات غير متاحة هنا'**
  String get alertsUnsupported;

  /// No description provided for @invite.
  ///
  /// In ar, this message translates to:
  /// **'دعوة'**
  String get invite;

  /// No description provided for @inviteTitle.
  ///
  /// In ar, this message translates to:
  /// **'دعوة بائع'**
  String get inviteTitle;

  /// No description provided for @inviteBody.
  ///
  /// In ar, this message translates to:
  /// **'يُنشئ هذا حساباً جديداً على ربطة. يختار صاحبه كلمة المرور بنفسه من الرابط، فلا نعرفها ولا تمر في محادثة.'**
  String get inviteBody;

  /// No description provided for @inviteAction.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء دعوة'**
  String get inviteAction;

  /// No description provided for @inviteCreating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإنشاء'**
  String get inviteCreating;

  /// No description provided for @inviteLinkTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرابط جاهز'**
  String get inviteLinkTitle;

  /// No description provided for @inviteLinkBody.
  ///
  /// In ar, this message translates to:
  /// **'أرسله إلى {email}. يعمل مرة واحدة، وتنتهي صلاحيته خلال 24 ساعة.'**
  String inviteLinkBody(String email);

  /// No description provided for @copyLink.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرابط'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الرابط'**
  String get linkCopied;

  /// No description provided for @inviteAnother.
  ///
  /// In ar, this message translates to:
  /// **'دعوة شخص آخر'**
  String get inviteAnother;

  /// No description provided for @inviteFailedNotAdmin.
  ///
  /// In ar, this message translates to:
  /// **'لا تملك صلاحية إنشاء الحسابات.'**
  String get inviteFailedNotAdmin;

  /// No description provided for @inviteFailedExists.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد له حساب بالفعل.'**
  String get inviteFailedExists;

  /// No description provided for @inviteFailedInvalid.
  ///
  /// In ar, this message translates to:
  /// **'هذا ليس بريداً إلكترونياً صحيحاً.'**
  String get inviteFailedInvalid;

  /// No description provided for @inviteFailedEmpty.
  ///
  /// In ar, this message translates to:
  /// **'اكتب البريد الإلكتروني أولاً.'**
  String get inviteFailedEmpty;

  /// No description provided for @inviteFailedOther.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء الدعوة. حاول مرة أخرى.'**
  String get inviteFailedOther;

  /// Custom SMTP is not configured yet, so the link is handed over rather than sent.
  ///
  /// In ar, this message translates to:
  /// **'لا يُرسل الرابط بالبريد بعد، فانسخه وأرسله بنفسك.'**
  String get inviteNoEmailYet;

  /// No description provided for @setPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر كلمة المرور'**
  String get setPasswordTitle;

  /// Arriving from an invitation. The account exists; it has no password yet.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في ربطة. اختر كلمة مرور لحسابك لتدخل بها من الآن فصاعداً.'**
  String get setPasswordWelcome;

  /// No description provided for @setPasswordRenew.
  ///
  /// In ar, this message translates to:
  /// **'اختر كلمة مرور جديدة لحسابك.'**
  String get setPasswordRenew;

  /// No description provided for @newPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get newPasswordLabel;

  /// No description provided for @passwordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور من 8 أحرف على الأقل.'**
  String get passwordTooShort;

  /// No description provided for @showPassword.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get hidePassword;

  /// No description provided for @setPasswordAction.
  ///
  /// In ar, this message translates to:
  /// **'حفظ ومتابعة'**
  String get setPasswordAction;

  /// No description provided for @setPasswordSaving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ'**
  String get setPasswordSaving;

  /// No description provided for @setPasswordFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ كلمة المرور. {error}'**
  String setPasswordFailed(String error);

  /// Invite links expire. Without saying so the seller only sees that nothing works.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية رابط الدعوة. اطلب رابطاً جديداً.'**
  String get inviteExpired;

  /// No description provided for @accounts.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات'**
  String get accounts;

  /// No description provided for @connectTitle.
  ///
  /// In ar, this message translates to:
  /// **'اربط حساباتك'**
  String get connectTitle;

  /// No description provided for @connectBody.
  ///
  /// In ar, this message translates to:
  /// **'تصل رسائل إنستغرام وماسنجر إلى هنا بعد ربط صفحتك. أما ما أُرسل قبل الربط فيبقى في تطبيقات ميتا.'**
  String get connectBody;

  /// No description provided for @connectAction.
  ///
  /// In ar, this message translates to:
  /// **'الربط مع ميتا'**
  String get connectAction;

  /// No description provided for @connectOpening.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ فتح ميتا'**
  String get connectOpening;

  /// No description provided for @connectAnother.
  ///
  /// In ar, this message translates to:
  /// **'ربط حساب آخر'**
  String get connectAnother;

  /// Where the conversation list would be, when nothing is connected yet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مربوط'**
  String get noAccountsRow;

  /// No description provided for @accountsBody.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات التي تصل رسائلها إلى ربطة.'**
  String get accountsBody;

  /// No description provided for @accountActive.
  ///
  /// In ar, this message translates to:
  /// **'يستقبل الرسائل'**
  String get accountActive;

  /// The token expired. Messages stopped arriving and nothing said so.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال، أعد الربط'**
  String get accountNeedsReconnect;

  /// No description provided for @accountDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get accountDisconnected;

  /// No description provided for @disconnect.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get disconnect;

  /// No description provided for @disconnectTitle.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف هذا الحساب؟'**
  String get disconnectTitle;

  /// No description provided for @disconnectBody.
  ///
  /// In ar, this message translates to:
  /// **'ستتوقف الرسائل الجديدة من هذا الحساب. تبقى المحادثات السابقة كما هي، ويمكنك إعادة الربط في أي وقت.'**
  String get disconnectBody;

  /// No description provided for @disconnectConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الحساب'**
  String get disconnectConfirm;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @connectFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر بدء الربط. حاول مرة أخرى.'**
  String get connectFailed;

  /// No description provided for @connectFailedSignedOut.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك. سجّل الدخول من جديد.'**
  String get connectFailedSignedOut;

  /// No description provided for @composerHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ردك'**
  String get composerHint;

  /// No description provided for @sendReply.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get sendReply;

  /// No description provided for @sending.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإرسال'**
  String get sending;

  /// Instagram accepts half of what Messenger does, so this is reachable on a reply that would have been fine on the other platform.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرد أطول مما تسمح به المنصة. اختصره قليلاً.'**
  String get sendFailedTooLong;

  /// The window closed between opening the conversation and pressing send. The reply is still in the box.
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت نافذة الرد أثناء كتابتك، ولم يُرسل ردك.'**
  String get sendFailedWindowClosed;

  /// No description provided for @sendFailedNoWindow.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك الرد قبل أن يراسلك هذا الزبون.'**
  String get sendFailedNoWindow;

  /// The access token has expired. Without this the seller sees only that nothing works, and assumes business is quiet.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية ربط حسابك. أعد ربطه لتتمكن من الرد.'**
  String get sendFailedDisconnected;

  /// No description provided for @sendFailedRejected.
  ///
  /// In ar, this message translates to:
  /// **'لم تقبل المنصة هذا الرد، ولم يُرسل.'**
  String get sendFailedRejected;

  /// No description provided for @sendFailedUnreachable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى المنصة. تحقّق من اتصالك وحاول مرة أخرى.'**
  String get sendFailedUnreachable;

  /// No description provided for @sendFailedNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم تعد هذه المحادثة متاحة.'**
  String get sendFailedNotFound;

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
