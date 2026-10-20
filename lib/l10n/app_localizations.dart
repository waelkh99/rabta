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
  /// **'التفاصيل'**
  String get productDescription;

  /// No description provided for @productDescriptionHint.
  ///
  /// In ar, this message translates to:
  /// **'المقاسات، الألوان، الخامة، القَصّة… اكتبها كما تقولها للزبون، والمساعد يفهمها.'**
  String get productDescriptionHint;

  /// No description provided for @productCategory.
  ///
  /// In ar, this message translates to:
  /// **'القسم'**
  String get productCategory;

  /// No description provided for @productCategoryHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: فساتين. اختياري، ويفيد في العروض.'**
  String get productCategoryHint;

  /// No description provided for @productPhotos.
  ///
  /// In ar, this message translates to:
  /// **'الصور'**
  String get productPhotos;

  /// No description provided for @productPhotoAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف صوراً'**
  String get productPhotoAdd;

  /// No description provided for @productPhotoCover.
  ///
  /// In ar, this message translates to:
  /// **'الغلاف'**
  String get productPhotoCover;

  /// No description provided for @productPhotoMakeCover.
  ///
  /// In ar, this message translates to:
  /// **'اجعلها الغلاف'**
  String get productPhotoMakeCover;

  /// No description provided for @productPhotoRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get productPhotoRemove;

  /// No description provided for @productPhotosBody.
  ///
  /// In ar, this message translates to:
  /// **'الصورة الأولى هي التي يرسلها المساعد لمن يطلب أن يرى المنتج. حتى خمس صور.'**
  String get productPhotosBody;

  /// No description provided for @productPhotosFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة بعض الصور. جرّب صوراً بصيغة JPG أو PNG.'**
  String get productPhotosFailed;

  /// No description provided for @productPhotosFull.
  ///
  /// In ar, this message translates to:
  /// **'خمس صور كحد أقصى.'**
  String get productPhotosFull;

  /// No description provided for @productNoPhoto.
  ///
  /// In ar, this message translates to:
  /// **'بلا صورة'**
  String get productNoPhoto;

  /// No description provided for @catalogAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get catalogAll;

  /// No description provided for @catalogSearch.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المنتجات'**
  String get catalogSearch;

  /// No description provided for @catalogNoMatch.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد منتج يطابق.'**
  String get catalogNoMatch;

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
  /// **'استيراد قائمة'**
  String get catalogPaste;

  /// No description provided for @catalogPasteBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملف الأسعار الذي عندك، أو انسخ الصفوف من الجدول والصقها. لا داعي لتغيير أعمدته: نفهم الاسم والسعر، وما زاد عنهما — اللون، المقاس — يُضاف إلى التفاصيل.\n\nلتحديث منتجات أضفتها من قبل، يجب أن يكون في ملفك عمود «رمز المنتج». الصف الذي رمزه موجود يحدّث ذلك المنتج، والصف الذي لا رمز له يُضاف منتجاً جديداً ويُعطى رمزاً. أسهل طريقة: نزّل قائمتك، عدّلها، ثم استوردها.'**
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

  /// No description provided for @needsYou.
  ///
  /// In ar, this message translates to:
  /// **'بحاجة لك'**
  String get needsYou;

  /// No description provided for @needsYouTitle.
  ///
  /// In ar, this message translates to:
  /// **'حوّلها المساعد إليك، والزبون بانتظار ردك'**
  String get needsYouTitle;

  /// No description provided for @needsYouList.
  ///
  /// In ar, this message translates to:
  /// **'محادثات بحاجة لك'**
  String get needsYouList;

  /// No description provided for @needsYouEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء بحاجة لك الآن.'**
  String get needsYouEmpty;

  /// No description provided for @needsYouTooltip.
  ///
  /// In ar, this message translates to:
  /// **'ما يحتاج ردك'**
  String get needsYouTooltip;

  /// No description provided for @offerKindText.
  ///
  /// In ar, this message translates to:
  /// **'بكلماتك'**
  String get offerKindText;

  /// No description provided for @offerText.
  ///
  /// In ar, this message translates to:
  /// **'العرض'**
  String get offerText;

  /// No description provided for @offerTextHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتبه كما تقوله للزبون، واستخدم أسماء المنتجات والأقسام كما هي في قائمتك ليفهمه المساعد. مثل: «خصم 20% على قسم فساتين» أو «القطعة الثانية من الشنط بنصف السعر». التاريخ تحدّده تحت، لا في النص.'**
  String get offerTextHint;

  /// No description provided for @offerTextScope.
  ///
  /// In ar, this message translates to:
  /// **'اختياري: إن حدّدت أقساماً أو منتجات، لن يطبّقه المساعد على غيرها.'**
  String get offerTextScope;

  /// No description provided for @escalatedNoPhoto.
  ///
  /// In ar, this message translates to:
  /// **'طلب الزبون صورة لمنتج ليس له صورة بعد'**
  String get escalatedNoPhoto;

  /// No description provided for @productCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز المنتج'**
  String get productCode;

  /// No description provided for @productCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'إذا تركته فارغاً يُعطى رمزاً تلقائياً. هو ما يربط هذا المنتج بصفّه في ملف Excel عندما تستورده مرة أخرى.'**
  String get productCodeHint;

  /// No description provided for @productCodeTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرمز لمنتج آخر. اختر رمزاً غيره.'**
  String get productCodeTaken;

  /// No description provided for @catalogDownload.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل قائمتي'**
  String get catalogDownload;

  /// No description provided for @catalogYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get catalogYes;

  /// No description provided for @catalogNo.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get catalogNo;

  /// No description provided for @catalogUpdated.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حُدّث منتج واحد} =2{حُدّث منتجان} few{حُدّثت {count} منتجات} many{حُدّث {count} منتجاً} other{حُدّث {count} منتج}}'**
  String catalogUpdated(int count);

  /// No description provided for @categoriesEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الأقسام'**
  String get categoriesEdit;

  /// No description provided for @categoriesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام'**
  String get categoriesTitle;

  /// No description provided for @categoriesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أقسام. تُنشأ عندما تكتب قسماً لمنتج.'**
  String get categoriesEmpty;

  /// No description provided for @categoryRename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تسمية'**
  String get categoryRename;

  /// No description provided for @categoryCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا منتجات} =1{منتج واحد} =2{منتجان} few{{count} منتجات} many{{count} منتجاً} other{{count} منتج}}'**
  String categoryCount(int count);

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف قسم «{name}»؟'**
  String categoryDeleteTitle(String name);

  /// No description provided for @categoryDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'تبقى منتجاته كما هي، لكن بلا قسم. والعروض على هذا القسم لن تشملها بعد الآن.'**
  String get categoryDeleteBody;

  /// No description provided for @categoryTaken.
  ///
  /// In ar, this message translates to:
  /// **'يوجد قسم بهذا الاسم.'**
  String get categoryTaken;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @offerCoversNothing.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد يشمل شيئاً'**
  String get offerCoversNothing;

  /// No description provided for @offers.
  ///
  /// In ar, this message translates to:
  /// **'العروض'**
  String get offers;

  /// No description provided for @offersBody.
  ///
  /// In ar, this message translates to:
  /// **'الخصومات التي تعرضها. يذكرها المساعد للزبون عندما يسأل عن منتج يشمله العرض، مرة واحدة ودون إلحاح. إذا شمل المنتجَ عرضان، يُطبَّق الأفضل للزبون.'**
  String get offersBody;

  /// No description provided for @offersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عروض بعد.'**
  String get offersEmpty;

  /// No description provided for @offersFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح العروض'**
  String get offersFailed;

  /// No description provided for @offerAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف عرضاً'**
  String get offerAdd;

  /// No description provided for @offerEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل العرض'**
  String get offerEdit;

  /// No description provided for @offerKindPercent.
  ///
  /// In ar, this message translates to:
  /// **'نسبة'**
  String get offerKindPercent;

  /// No description provided for @offerKindAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ'**
  String get offerKindAmount;

  /// No description provided for @offerKindBuyGet.
  ///
  /// In ar, this message translates to:
  /// **'اشترِ واحصل'**
  String get offerKindBuyGet;

  /// No description provided for @offerPercent.
  ///
  /// In ar, this message translates to:
  /// **'النسبة %'**
  String get offerPercent;

  /// No description provided for @offerAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المخصوم'**
  String get offerAmount;

  /// No description provided for @offerBuy.
  ///
  /// In ar, this message translates to:
  /// **'عند شراء'**
  String get offerBuy;

  /// No description provided for @offerGet.
  ///
  /// In ar, this message translates to:
  /// **'يحصل مجاناً على'**
  String get offerGet;

  /// No description provided for @offerBuyGetHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: اشترِ 2 واحصل على 1 مجاناً. القطعة الأرخص هي المجانية.'**
  String get offerBuyGetHint;

  /// No description provided for @offerAppliesTo.
  ///
  /// In ar, this message translates to:
  /// **'يشمل'**
  String get offerAppliesTo;

  /// No description provided for @offerWholeShop.
  ///
  /// In ar, this message translates to:
  /// **'كل المتجر'**
  String get offerWholeShop;

  /// No description provided for @offerCategories.
  ///
  /// In ar, this message translates to:
  /// **'أقسام'**
  String get offerCategories;

  /// No description provided for @offerProducts.
  ///
  /// In ar, this message translates to:
  /// **'منتجات'**
  String get offerProducts;

  /// No description provided for @offerNoCategories.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أقسام بعد. اختر قسماً لمنتجاتك من صفحة المنتجات.'**
  String get offerNoCategories;

  /// No description provided for @offerStarts.
  ///
  /// In ar, this message translates to:
  /// **'يبدأ'**
  String get offerStarts;

  /// No description provided for @offerEnds.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي'**
  String get offerEnds;

  /// No description provided for @offerStartsNow.
  ///
  /// In ar, this message translates to:
  /// **'من الآن'**
  String get offerStartsNow;

  /// No description provided for @offerNoEnd.
  ///
  /// In ar, this message translates to:
  /// **'بلا تاريخ'**
  String get offerNoEnd;

  /// No description provided for @offerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم العرض (اختياري)'**
  String get offerName;

  /// No description provided for @offerNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: عرض العيد. هكذا يسمّيه المساعد للزبون.'**
  String get offerNameHint;

  /// No description provided for @offerRunning.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الآن'**
  String get offerRunning;

  /// No description provided for @offerScheduled.
  ///
  /// In ar, this message translates to:
  /// **'لم يبدأ بعد'**
  String get offerScheduled;

  /// No description provided for @offerEnded.
  ///
  /// In ar, this message translates to:
  /// **'انتهى'**
  String get offerEnded;

  /// No description provided for @offerOff.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get offerOff;

  /// No description provided for @offerDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا العرض؟'**
  String get offerDeleteTitle;

  /// No description provided for @offerDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتوقف المساعد عن ذكره.'**
  String get offerDeleteBody;

  /// No description provided for @offerSummaryPercent.
  ///
  /// In ar, this message translates to:
  /// **'خصم {value}%'**
  String offerSummaryPercent(String value);

  /// No description provided for @offerSummaryAmount.
  ///
  /// In ar, this message translates to:
  /// **'خصم {value}'**
  String offerSummaryAmount(String value);

  /// No description provided for @offerSummaryBuyGet.
  ///
  /// In ar, this message translates to:
  /// **'اشترِ {buy} واحصل على {get} مجاناً'**
  String offerSummaryBuyGet(String buy, String get);

  /// No description provided for @offerUntil.
  ///
  /// In ar, this message translates to:
  /// **'حتى {date}'**
  String offerUntil(String date);

  /// No description provided for @offerFrom.
  ///
  /// In ar, this message translates to:
  /// **'من {date}'**
  String offerFrom(String date);

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
  /// **'حوّلها المساعد'**
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

  /// On the settings screen. It says 'this device' because the choice is stored in the browser, not on the account, and a seller who turns it on at the shop should not be surprised that it is off at home.
  ///
  /// In ar, this message translates to:
  /// **'ينبّهك المتصفّح عند وصول رسالة أو عندما يحوّل المساعد محادثة إليك. لهذا الجهاز وحده.'**
  String get alertsBody;

  /// No description provided for @shopPricing.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get shopPricing;

  /// No description provided for @shopPricingBody.
  ///
  /// In ar, this message translates to:
  /// **'ماذا يفعل المساعد عندما يطلب الزبون سعراً أفضل. لا يقول إلا ما كتبته: السعر من قائمتك، وأي تخفيض عندما يتوفّر.'**
  String get shopPricingBody;

  /// No description provided for @shopPricingHandOver.
  ///
  /// In ar, this message translates to:
  /// **'أعلمني'**
  String get shopPricingHandOver;

  /// No description provided for @shopPricingHandOverBody.
  ///
  /// In ar, this message translates to:
  /// **'يقول السعر، ولا يساوم، ويحوّل المحادثة إليك لتقرّر.'**
  String get shopPricingHandOverBody;

  /// No description provided for @shopPricingFinal.
  ///
  /// In ar, this message translates to:
  /// **'يقول إن السعر ثابت'**
  String get shopPricingFinal;

  /// The consequence worth stating: choosing this stops these conversations reaching the seller at all.
  ///
  /// In ar, this message translates to:
  /// **'يقول بلطف إن السعر غير قابل للتفاوض، ثم يقترح قطعة أرخص من قائمتك بدل أن ينهي المحادثة. ولا يحوّلها إليك.'**
  String get shopPricingFinalBody;

  /// The divider between what the assistant tells customers and what belongs to the seller and this browser.
  ///
  /// In ar, this message translates to:
  /// **'أنت وهذا المتصفّح'**
  String get settingsYou;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'لغة الواجهة'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageBody.
  ///
  /// In ar, this message translates to:
  /// **'يُحفظ في هذا المتصفّح.'**
  String get settingsLanguageBody;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @passwordBody.
  ///
  /// In ar, this message translates to:
  /// **'10 أحرف على الأقل، وفيها حرف كبير وحرف صغير ورقم.'**
  String get passwordBody;

  /// No description provided for @passwordNew.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get passwordNew;

  /// No description provided for @passwordCurrent.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية'**
  String get passwordCurrent;

  /// No description provided for @passwordRepeat.
  ///
  /// In ar, this message translates to:
  /// **'أعد كتابتها'**
  String get passwordRepeat;

  /// No description provided for @passwordMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الكلمتان غير متطابقتين.'**
  String get passwordMismatch;

  /// No description provided for @passwordWrong.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية غير صحيحة.'**
  String get passwordWrong;

  /// No description provided for @passwordChange.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get passwordChange;

  /// No description provided for @passwordChanging.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ'**
  String get passwordChanging;

  /// No description provided for @passwordChanged.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور.'**
  String get passwordChanged;

  /// No description provided for @passwordFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تغيير كلمة المرور. حاول مرة أخرى.'**
  String get passwordFailed;

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
  /// **'10 أحرف على الأقل، وفيها حرف كبير وحرف صغير ورقم.'**
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
  /// **'تصل رسائل إنستغرام وماسنجر وواتساب إلى هنا بعد ربطها. أما ما أُرسل قبل الربط فيبقى في تطبيقات ميتا.'**
  String get connectBody;

  /// No description provided for @connectAction.
  ///
  /// In ar, this message translates to:
  /// **'الربط مع ميتا'**
  String get connectAction;

  /// No description provided for @connectWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'ربط واتساب'**
  String get connectWhatsApp;

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

  /// No description provided for @platformWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get platformWhatsApp;

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
  /// **'المساعد يجيب عن السعر والتوفر وأنت مشغول، ويترك لك ما عداه.'**
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

  /// No description provided for @catalogFileChoose.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملف Excel'**
  String get catalogFileChoose;

  /// No description provided for @catalogFileOr.
  ///
  /// In ar, this message translates to:
  /// **'أو الصق الصفوف'**
  String get catalogFileOr;

  /// No description provided for @catalogFileOldExcel.
  ///
  /// In ar, this message translates to:
  /// **'هذا ملف Excel بالصيغة القديمة XLS. افتحه واحفظه بصيغة XLSX، ثم اختره مرة أخرى.'**
  String get catalogFileOldExcel;

  /// No description provided for @catalogFileUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة هذا الملف. جرّب ملف XLSX أو CSV.'**
  String get catalogFileUnreadable;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم الزبون أو بنص رسالة'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محادثات تطابق بحثك'**
  String get searchNoResults;

  /// No description provided for @clearSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get clearSearch;

  /// No description provided for @reconnectBanner.
  ///
  /// In ar, this message translates to:
  /// **'توقّف أحد حساباتك عن استقبال الرسائل. أعد ربطه حتى تصلك رسائل الزبائن.'**
  String get reconnectBanner;

  /// No description provided for @reconnectAction.
  ///
  /// In ar, this message translates to:
  /// **'أعد الربط'**
  String get reconnectAction;

  /// No description provided for @assistantHere.
  ///
  /// In ar, this message translates to:
  /// **'المساعد'**
  String get assistantHere;

  /// No description provided for @assistantHereOn.
  ///
  /// In ar, this message translates to:
  /// **'المساعد يردّ في هذه المحادثة. أوقفه لتتولّاها بنفسك.'**
  String get assistantHereOn;

  /// No description provided for @assistantHereOff.
  ///
  /// In ar, this message translates to:
  /// **'أنت تتولّى هذه المحادثة، والمساعد لن يردّ فيها حتى تعيد تشغيله.'**
  String get assistantHereOff;

  /// No description provided for @teachTitle.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد أن يعرف المساعد هذا الجواب في المرة القادمة؟'**
  String get teachTitle;

  /// No description provided for @teachBody.
  ///
  /// In ar, this message translates to:
  /// **'عدّل النص إن لزم. يُضاف إلى معلومات متجرك، ويستخدمه المساعد مع كل الزبائن.'**
  String get teachBody;

  /// No description provided for @teachSave.
  ///
  /// In ar, this message translates to:
  /// **'احفظ'**
  String get teachSave;

  /// No description provided for @teachDismiss.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get teachDismiss;

  /// No description provided for @teachSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ. سيستخدمه المساعد من الآن.'**
  String get teachSaved;

  /// No description provided for @teachFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحفظ. حاول مرة أخرى.'**
  String get teachFailed;

  /// No description provided for @outcomeOrdered.
  ///
  /// In ar, this message translates to:
  /// **'طلب'**
  String get outcomeOrdered;

  /// No description provided for @outcomeNotBought.
  ///
  /// In ar, this message translates to:
  /// **'لم يشترِ'**
  String get outcomeNotBought;

  /// No description provided for @outcomeJustAsking.
  ///
  /// In ar, this message translates to:
  /// **'استفسار'**
  String get outcomeJustAsking;

  /// No description provided for @outcomeOpen.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحسم بعد'**
  String get outcomeOpen;

  /// No description provided for @outcomeQuestion.
  ///
  /// In ar, this message translates to:
  /// **'كيف انتهت المحادثة؟'**
  String get outcomeQuestion;

  /// No description provided for @outcomeSet.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get outcomeSet;

  /// No description provided for @outcomeByAssistant.
  ///
  /// In ar, this message translates to:
  /// **'حدّدها المساعد، ويمكنك تعديلها'**
  String get outcomeByAssistant;

  /// No description provided for @outcomeBySeller.
  ///
  /// In ar, this message translates to:
  /// **'حدّدتها أنت'**
  String get outcomeBySeller;

  /// No description provided for @outcomeWhy.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get outcomeWhy;

  /// No description provided for @outcomeNoReason.
  ///
  /// In ar, this message translates to:
  /// **'بدون سبب واضح'**
  String get outcomeNoReason;

  /// No description provided for @reason_price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get reason_price;

  /// No description provided for @reason_delivery_fee.
  ///
  /// In ar, this message translates to:
  /// **'رسوم التوصيل'**
  String get reason_delivery_fee;

  /// No description provided for @reason_delivery_time.
  ///
  /// In ar, this message translates to:
  /// **'مدة التوصيل'**
  String get reason_delivery_time;

  /// No description provided for @reason_size_or_variant.
  ///
  /// In ar, this message translates to:
  /// **'المقاس أو اللون غير متوفر'**
  String get reason_size_or_variant;

  /// No description provided for @reason_out_of_stock.
  ///
  /// In ar, this message translates to:
  /// **'نفد من المخزون'**
  String get reason_out_of_stock;

  /// No description provided for @reason_not_sold.
  ///
  /// In ar, this message translates to:
  /// **'منتج لا نبيعه'**
  String get reason_not_sold;

  /// No description provided for @reason_no_answer.
  ///
  /// In ar, this message translates to:
  /// **'لم يُرَدّ عليه'**
  String get reason_no_answer;

  /// No description provided for @reason_unknown.
  ///
  /// In ar, this message translates to:
  /// **'بدون سبب واضح'**
  String get reason_unknown;

  /// No description provided for @results.
  ///
  /// In ar, this message translates to:
  /// **'النتائج'**
  String get results;

  /// No description provided for @resultsTitle.
  ///
  /// In ar, this message translates to:
  /// **'آخر 7 أيام'**
  String get resultsTitle;

  /// No description provided for @resultsOrders.
  ///
  /// In ar, this message translates to:
  /// **'محادثات انتهت بطلب: {ordered} من {total}'**
  String resultsOrders(int ordered, int total);

  /// No description provided for @resultsNone.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محادثات في آخر 7 أيام.'**
  String get resultsNone;

  /// No description provided for @resultsPending.
  ///
  /// In ar, this message translates to:
  /// **'تُقرأ المحادثة بعد أن تهدأ 12 ساعة، فقد لا تظهر محادثات اليوم بعد.'**
  String get resultsPending;

  /// No description provided for @resultsWhy.
  ///
  /// In ar, this message translates to:
  /// **'لماذا لم يشترِ الزبائن'**
  String get resultsWhy;

  /// No description provided for @resultsProducts.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر سؤالاً عنه'**
  String get resultsProducts;

  /// No description provided for @resultsProductLine.
  ///
  /// In ar, this message translates to:
  /// **'سُئل عنه {asked} · طلبات {ordered}'**
  String resultsProductLine(int asked, int ordered);

  /// No description provided for @resultsAreas.
  ///
  /// In ar, this message translates to:
  /// **'من أين يكتب الزبائن'**
  String get resultsAreas;

  /// No description provided for @resultsUnanswered.
  ///
  /// In ar, this message translates to:
  /// **'زبائن أُغلقت نافذة الرد قبل أن يُرَدّ عليهم: {count}'**
  String resultsUnanswered(int count);

  /// No description provided for @resultsHours.
  ///
  /// In ar, this message translates to:
  /// **'متى يكتب الزبائن'**
  String get resultsHours;

  /// No description provided for @resultsBusiest.
  ///
  /// In ar, this message translates to:
  /// **'أكثر الأوقات ازدحاماً من {from}:00 إلى {to}:00'**
  String resultsBusiest(int from, int to);

  /// No description provided for @resultsAccuracy.
  ///
  /// In ar, this message translates to:
  /// **'محادثات قرأها المساعد: {read}، وعدّلتَ نتيجتها في: {corrected}'**
  String resultsAccuracy(int read, int corrected);

  /// No description provided for @resultsFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل النتائج. حاول مرة أخرى.'**
  String get resultsFailed;

  /// No description provided for @resultsRetry.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get resultsRetry;

  /// No description provided for @newVersion.
  ///
  /// In ar, this message translates to:
  /// **'نسخة جديدة من ربطة جاهزة.'**
  String get newVersion;

  /// No description provided for @reload.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التحميل'**
  String get reload;

  /// No description provided for @admin.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة'**
  String get admin;

  /// No description provided for @adminTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة ربطة'**
  String get adminTitle;

  /// No description provided for @adminRefresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get adminRefresh;

  /// No description provided for @adminFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات الإدارة.'**
  String get adminFailed;

  /// No description provided for @adminHealth.
  ///
  /// In ar, this message translates to:
  /// **'حالة الخدمة'**
  String get adminHealth;

  /// No description provided for @adminAllGood.
  ///
  /// In ar, this message translates to:
  /// **'كل شيء يعمل.'**
  String get adminAllGood;

  /// No description provided for @adminProblems.
  ///
  /// In ar, this message translates to:
  /// **'هناك ما يحتاج انتباهك:'**
  String get adminProblems;

  /// No description provided for @adminLastDelivery.
  ///
  /// In ar, this message translates to:
  /// **'آخر رسالة وصلت من ميتا'**
  String get adminLastDelivery;

  /// No description provided for @adminNever.
  ///
  /// In ar, this message translates to:
  /// **'لم تصل أي رسالة بعد'**
  String get adminNever;

  /// No description provided for @adminUnprocessed.
  ///
  /// In ar, this message translates to:
  /// **'رسائل لم تُعالَج بعد'**
  String get adminUnprocessed;

  /// No description provided for @adminFailing.
  ///
  /// In ar, this message translates to:
  /// **'رسائل فشلت معالجتها وستُعاد'**
  String get adminFailing;

  /// No description provided for @adminStuck.
  ///
  /// In ar, this message translates to:
  /// **'رسائل توقفت محاولات معالجتها'**
  String get adminStuck;

  /// No description provided for @adminReconnect.
  ///
  /// In ar, this message translates to:
  /// **'حسابات تحتاج إعادة ربط'**
  String get adminReconnect;

  /// No description provided for @adminErrors.
  ///
  /// In ar, this message translates to:
  /// **'أخطاء خلال 24 ساعة'**
  String get adminErrors;

  /// No description provided for @adminWarnings.
  ///
  /// In ar, this message translates to:
  /// **'تحذيرات خلال 24 ساعة'**
  String get adminWarnings;

  /// No description provided for @adminClientErrors.
  ///
  /// In ar, this message translates to:
  /// **'أخطاء على شاشات البائعين خلال 24 ساعة'**
  String get adminClientErrors;

  /// No description provided for @adminAiCost.
  ///
  /// In ar, this message translates to:
  /// **'تكلفة المساعد هذا الشهر'**
  String get adminAiCost;

  /// No description provided for @adminAiCalls.
  ///
  /// In ar, this message translates to:
  /// **'طلبات المساعد هذا الشهر'**
  String get adminAiCalls;

  /// No description provided for @adminSellers.
  ///
  /// In ar, this message translates to:
  /// **'البائعون'**
  String get adminSellers;

  /// No description provided for @adminYou.
  ///
  /// In ar, this message translates to:
  /// **'مدير'**
  String get adminYou;

  /// No description provided for @adminNoAccounts.
  ///
  /// In ar, this message translates to:
  /// **'لم يربط أي حساب'**
  String get adminNoAccounts;

  /// No description provided for @adminConversations.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات'**
  String get adminConversations;

  /// No description provided for @adminMessages7d.
  ///
  /// In ar, this message translates to:
  /// **'رسائل آخر 7 أيام'**
  String get adminMessages7d;

  /// No description provided for @adminLastMessage.
  ///
  /// In ar, this message translates to:
  /// **'آخر رسالة'**
  String get adminLastMessage;

  /// No description provided for @adminLastSignIn.
  ///
  /// In ar, this message translates to:
  /// **'آخر دخول'**
  String get adminLastSignIn;

  /// No description provided for @adminProducts.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get adminProducts;

  /// No description provided for @adminAssistant.
  ///
  /// In ar, this message translates to:
  /// **'المساعد'**
  String get adminAssistant;

  /// No description provided for @adminOn.
  ///
  /// In ar, this message translates to:
  /// **'يعمل'**
  String get adminOn;

  /// No description provided for @adminOff.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get adminOff;

  /// No description provided for @adminAiReplies.
  ///
  /// In ar, this message translates to:
  /// **'ردود المساعد هذا الشهر'**
  String get adminAiReplies;

  /// No description provided for @adminHandedOver.
  ///
  /// In ar, this message translates to:
  /// **'محادثات بانتظار البائع'**
  String get adminHandedOver;

  /// No description provided for @adminOrdered.
  ///
  /// In ar, this message translates to:
  /// **'طلبات هذا الشهر'**
  String get adminOrdered;

  /// No description provided for @adminEvents.
  ///
  /// In ar, this message translates to:
  /// **'آخر الأحداث'**
  String get adminEvents;

  /// No description provided for @adminNoEvents.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أحداث بعد.'**
  String get adminNoEvents;

  /// No description provided for @adminScreenErrors.
  ///
  /// In ar, this message translates to:
  /// **'أخطاء على شاشات البائعين'**
  String get adminScreenErrors;

  /// No description provided for @adminNoScreenErrors.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أخطاء.'**
  String get adminNoScreenErrors;

  /// No description provided for @adminInvite.
  ///
  /// In ar, this message translates to:
  /// **'دعوة بائع'**
  String get adminInvite;

  /// No description provided for @adminStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'يعمل'**
  String get adminStatusActive;

  /// No description provided for @adminStatusReconnect.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج إعادة ربط'**
  String get adminStatusReconnect;

  /// No description provided for @adminStatusOff.
  ///
  /// In ar, this message translates to:
  /// **'مفصول'**
  String get adminStatusOff;

  /// No description provided for @signInHero.
  ///
  /// In ar, this message translates to:
  /// **'لا زبون ينتظر حتى الصباح.'**
  String get signInHero;

  /// No description provided for @signInWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً من جديد'**
  String get signInWelcome;

  /// No description provided for @signInWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لترى من ينتظرك.'**
  String get signInWelcomeBody;

  /// No description provided for @inviteSentTitle.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت الدعوة'**
  String get inviteSentTitle;

  /// No description provided for @inviteSentBody.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا إلى {email} رابطاً ليختار كلمة المرور. يعمل مرة واحدة ولفترة محدودة. إذا لم يصله، اطلب منه أن يتفقّد مجلد الرسائل غير المرغوب فيها.'**
  String inviteSentBody(String email);

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @dataDeletion.
  ///
  /// In ar, this message translates to:
  /// **'حذف البيانات'**
  String get dataDeletion;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordNeedEmail.
  ///
  /// In ar, this message translates to:
  /// **'اكتب بريدك الإلكتروني أولاً، ثم اضغط «نسيت كلمة المرور؟».'**
  String get forgotPasswordNeedEmail;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In ar, this message translates to:
  /// **'إذا كان لـ {email} حساب في ربطة، فقد أرسلنا إليه رابطاً لاختيار كلمة مرور جديدة.'**
  String forgotPasswordSent(String email);

  /// No description provided for @forgotPasswordFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال الرابط. انتظر دقيقة ثم حاول مرة أخرى.'**
  String get forgotPasswordFailed;
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
