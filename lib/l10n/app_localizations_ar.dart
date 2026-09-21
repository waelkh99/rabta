// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LAr extends L {
  LAr([String locale = 'ar']) : super(locale);

  @override
  String get tagline => 'كل رسائل زبائنك، من إنستغرام وماسنجر، في مكان واحد.';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signingIn => 'جارٍ تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signInWrongCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String signInFailed(String error) {
    return 'تعذّر تسجيل الدخول. $error';
  }

  @override
  String customersWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count زبون ينتظر',
      many: '$count زبوناً ينتظرون',
      few: '$count زبائن ينتظرون',
      two: 'زبونان ينتظران',
      one: 'زبون واحد ينتظر',
      zero: 'لا أحد ينتظر',
    );
    return '$_temp0';
  }

  @override
  String get everyoneAnswered => 'تمّت الإجابة على الجميع';

  @override
  String get waitingForReply => 'بانتظار الرد';

  @override
  String get answered => 'تمّت الإجابة';

  @override
  String get customer => 'زبون';

  @override
  String get noConversationsTitle => 'لا توجد محادثات بعد';

  @override
  String get noConversationsBody =>
      'تظهر الرسائل هنا عندما يراسلك الزبائن. أما ما أُرسل قبل ربط حسابك فيبقى في تطبيقات ميتا.';

  @override
  String get longestWait => 'أطول انتظار';

  @override
  String get windowExplanation =>
      'تُغلق ميتا نافذة الرد بعد 24 ساعة من رسالة الزبون. بعدها لا يمكنك الرد حتى يراسلك من جديد.';

  @override
  String get replyWindowClosedShort => 'أُغلقت نافذة الرد';

  @override
  String get replyWindowClosedLong =>
      'أُغلقت نافذة الرد. يمكنك الرد مجدداً عندما يراسلك هذا الزبون.';

  @override
  String get replyingNotBuilt => 'إرسال الردود غير متاح بعد.';

  @override
  String get menu => 'التنقّل';

  @override
  String get inbox => 'الرسائل';

  @override
  String get shop => 'المتجر';

  @override
  String get shopCurrency => 'العملة';

  @override
  String get shopCurrencyBody =>
      'تُكتب كما تكتبها لزبونك، ويعيدها المساعد كما هي.';

  @override
  String get shopDelivery => 'التوصيل';

  @override
  String get shopDeliveryBody =>
      'المناطق التي توصل إليها وأجرة كل منها. هذا ما يجيب به المساعد عن «قديش التوصيل».';

  @override
  String get shopDeliveryEmpty => 'لم تُضف أي منطقة بعد.';

  @override
  String get shopZoneAdd => 'أضف منطقة';

  @override
  String get shopZoneName => 'المنطقة';

  @override
  String get shopZoneFee => 'الأجرة';

  @override
  String get shopZoneFeeHint =>
      'اتركها فارغة إذا كانت الأجرة تختلف. سيقول المساعد إنها تعتمد، ولن يخترع رقماً.';

  @override
  String get shopZoneNoFee => 'تعتمد';

  @override
  String get shopDeliveryNote => 'قواعد أخرى للتوصيل';

  @override
  String get shopDeliveryNoteHint =>
      'مثل: مجاني فوق 50 ديناراً، أو التوصيل داخل عمّان بنفس اليوم.';

  @override
  String get shopLocations => 'مواقع المتجر';

  @override
  String get shopLocationsHint =>
      'العنوان أو مكان الاستلام. اكتب كل فرع في سطر.';

  @override
  String get shopHours => 'أوقات الدوام';

  @override
  String get shopHoursHint =>
      'مثل: السبت إلى الخميس من 10 صباحاً إلى 8 مساءً، الجمعة مغلق.';

  @override
  String get shopAbout => 'معلومات أخرى';

  @override
  String get shopAboutBody =>
      'أي شيء آخر تريد أن يعرفه المساعد: طريقة الطلب، الدفع عند الاستلام، الإرجاع، أو أي تفصيل يخصك.';

  @override
  String get shopAboutHint =>
      'يقرأه المساعد كما كتبته. هذا أيضاً مكانك لتصحيحه إذا ظل يخطئ في شيء.';

  @override
  String get products => 'المنتجات';

  @override
  String get productsBody =>
      'ما تبيعه، ليعرف المساعد بماذا يجيب. الاسم والسعر يكفيان.';

  @override
  String get productsEmpty => 'لا توجد منتجات بعد.';

  @override
  String get productAdd => 'أضف منتجاً';

  @override
  String get productEdit => 'تعديل';

  @override
  String get productDelete => 'حذف';

  @override
  String get productSave => 'حفظ';

  @override
  String get productName => 'الاسم';

  @override
  String get productPrice => 'السعر';

  @override
  String get productDescription => 'الوصف';

  @override
  String get productInStock => 'متوفر';

  @override
  String get productOutOfStock => 'غير متوفر';

  @override
  String get productDeleteTitle => 'حذف هذا المنتج؟';

  @override
  String productDeleteBody(String name) {
    return 'لن يذكره المساعد بعد الآن. $name';
  }

  @override
  String get productDeleteConfirm => 'حذف';

  @override
  String get catalogSaveFailed => 'لم يُحفظ. حاول مرة أخرى.';

  @override
  String get catalogFailed => 'تعذّر فتح المنتجات';

  @override
  String get catalogFailedBody => 'تحقق من اتصالك ثم أعد المحاولة.';

  @override
  String get catalogPaste => 'لصق قائمة';

  @override
  String get catalogPasteBody =>
      'انسخ الصفوف من ملف إكسل أو من جدول جوجل، ثم الصقها هنا. تُضاف إلى قائمتك ولا تستبدلها.';

  @override
  String get catalogPasteHint => 'الصق الصفوف هنا';

  @override
  String get catalogPasteAdd => 'إضافة';

  @override
  String get catalogPasteNothing => 'لم نجد أي منتج في ما لصقته.';

  @override
  String catalogPasteAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $count منتج',
      many: 'أُضيف $count منتجاً',
      few: 'أُضيفت $count منتجات',
      two: 'أُضيف منتجان',
      one: 'أُضيف منتج واحد',
      zero: 'لم يُضف شيء',
    );
    return '$_temp0';
  }

  @override
  String get catalogTemplateCopy => 'انسخ نموذجاً فارغاً';

  @override
  String get catalogTemplateCopied => 'نُسخ النموذج. الصقه في إكسل.';

  @override
  String get assistantTitle => 'المساعد';

  @override
  String get assistantBody =>
      'يرد على زبائنك من قائمتك، ويقترح عليهم ما قد يناسبهم، ويحوّل إليك كل ما لا يصح أن يجيب عنه بنفسه.';

  @override
  String get assistantNeedsCatalog =>
      'أضف منتجاً أولاً. من دون قائمة لا يملك المساعد ما يجيب به.';

  @override
  String get sentAutomatically => 'رد تلقائي';

  @override
  String get answeredByAssistant => 'أجاب المساعد';

  @override
  String get broughtToYou => 'حوّلها المساعد';

  @override
  String get escalatedWindowClosed => 'أُغلقت نافذة الرد قبل أن يجيب';

  @override
  String get escalatedAiStreak => 'أجاب مرات متتالية هنا، والدور عليك';

  @override
  String get escalatedSellerPresent => 'كنت ترد بنفسك، فلم يتدخّل';

  @override
  String get escalatedCeiling => 'بلغ المساعد حدّه لهذا الشهر';

  @override
  String get escalatedUngrounded => 'كاد يقول ما لم تكتبه، فتوقّف';

  @override
  String get escalatedNotSent => 'تعذّر إرسال رده';

  @override
  String get alertWrote => 'راسلك';

  @override
  String get alertHandedOver => 'حوّلها المساعد إليك';

  @override
  String get alerts => 'التنبيهات';

  @override
  String get alertsDenied => 'التنبيهات محظورة في المتصفّح';

  @override
  String get alertsUnsupported => 'التنبيهات غير متاحة هنا';

  @override
  String get invite => 'دعوة';

  @override
  String get inviteTitle => 'دعوة بائع';

  @override
  String get inviteBody =>
      'يُنشئ هذا حساباً جديداً على ربطة. يختار صاحبه كلمة المرور بنفسه من الرابط، فلا نعرفها ولا تمر في محادثة.';

  @override
  String get inviteAction => 'إنشاء دعوة';

  @override
  String get inviteCreating => 'جارٍ الإنشاء';

  @override
  String get inviteLinkTitle => 'الرابط جاهز';

  @override
  String inviteLinkBody(String email) {
    return 'أرسله إلى $email. يعمل مرة واحدة، وتنتهي صلاحيته خلال 24 ساعة.';
  }

  @override
  String get copyLink => 'نسخ الرابط';

  @override
  String get linkCopied => 'نُسخ الرابط';

  @override
  String get inviteAnother => 'دعوة شخص آخر';

  @override
  String get inviteFailedNotAdmin => 'لا تملك صلاحية إنشاء الحسابات.';

  @override
  String get inviteFailedExists => 'هذا البريد له حساب بالفعل.';

  @override
  String get inviteFailedInvalid => 'هذا ليس بريداً إلكترونياً صحيحاً.';

  @override
  String get inviteFailedEmpty => 'اكتب البريد الإلكتروني أولاً.';

  @override
  String get inviteFailedOther => 'تعذّر إنشاء الدعوة. حاول مرة أخرى.';

  @override
  String get inviteNoEmailYet =>
      'لا يُرسل الرابط بالبريد بعد، فانسخه وأرسله بنفسك.';

  @override
  String get setPasswordTitle => 'اختر كلمة المرور';

  @override
  String get setPasswordWelcome =>
      'أهلاً بك في ربطة. اختر كلمة مرور لحسابك لتدخل بها من الآن فصاعداً.';

  @override
  String get setPasswordRenew => 'اختر كلمة مرور جديدة لحسابك.';

  @override
  String get newPasswordLabel => 'كلمة المرور';

  @override
  String get passwordTooShort => 'كلمة المرور من 8 أحرف على الأقل.';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get setPasswordAction => 'حفظ ومتابعة';

  @override
  String get setPasswordSaving => 'جارٍ الحفظ';

  @override
  String setPasswordFailed(String error) {
    return 'تعذّر حفظ كلمة المرور. $error';
  }

  @override
  String get inviteExpired => 'انتهت صلاحية رابط الدعوة. اطلب رابطاً جديداً.';

  @override
  String get accounts => 'الحسابات';

  @override
  String get connectTitle => 'اربط حساباتك';

  @override
  String get connectBody =>
      'تصل رسائل إنستغرام وماسنجر إلى هنا بعد ربط صفحتك. أما ما أُرسل قبل الربط فيبقى في تطبيقات ميتا.';

  @override
  String get connectAction => 'الربط مع ميتا';

  @override
  String get connectOpening => 'جارٍ فتح ميتا';

  @override
  String get connectAnother => 'ربط حساب آخر';

  @override
  String get noAccountsRow => 'لا يوجد حساب مربوط';

  @override
  String get accountsBody => 'الحسابات التي تصل رسائلها إلى ربطة.';

  @override
  String get accountActive => 'يستقبل الرسائل';

  @override
  String get accountNeedsReconnect => 'انقطع الاتصال، أعد الربط';

  @override
  String get accountDisconnected => 'موقوف';

  @override
  String get disconnect => 'إيقاف';

  @override
  String get disconnectTitle => 'إيقاف هذا الحساب؟';

  @override
  String get disconnectBody =>
      'ستتوقف الرسائل الجديدة من هذا الحساب. تبقى المحادثات السابقة كما هي، ويمكنك إعادة الربط في أي وقت.';

  @override
  String get disconnectConfirm => 'إيقاف الحساب';

  @override
  String get cancel => 'إلغاء';

  @override
  String get connectFailed => 'تعذّر بدء الربط. حاول مرة أخرى.';

  @override
  String get connectFailedSignedOut => 'انتهت جلستك. سجّل الدخول من جديد.';

  @override
  String get composerHint => 'اكتب ردك';

  @override
  String get sendReply => 'إرسال';

  @override
  String get sending => 'جارٍ الإرسال';

  @override
  String get sendFailedTooLong =>
      'هذا الرد أطول مما تسمح به المنصة. اختصره قليلاً.';

  @override
  String get sendFailedWindowClosed =>
      'أُغلقت نافذة الرد أثناء كتابتك، ولم يُرسل ردك.';

  @override
  String get sendFailedNoWindow => 'لا يمكنك الرد قبل أن يراسلك هذا الزبون.';

  @override
  String get sendFailedDisconnected =>
      'انتهت صلاحية ربط حسابك. أعد ربطه لتتمكن من الرد.';

  @override
  String get sendFailedRejected => 'لم تقبل المنصة هذا الرد، ولم يُرسل.';

  @override
  String get sendFailedUnreachable =>
      'تعذّر الوصول إلى المنصة. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get sendFailedNotFound => 'لم تعد هذه المحادثة متاحة.';

  @override
  String minutesLeftToReply(int count) {
    return '$count د للرد';
  }

  @override
  String hoursLeftToReply(int count) {
    return '$count س للرد';
  }

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(int count) {
    return '$count د';
  }

  @override
  String hoursAgo(int count) {
    return '$count س';
  }

  @override
  String daysAgo(int count) {
    return '$count ي';
  }

  @override
  String weeksAgo(int count) {
    return '$count أ';
  }

  @override
  String get attachmentPhoto => 'صورة';

  @override
  String get attachmentVideo => 'فيديو';

  @override
  String get attachmentVoice => 'رسالة صوتية';

  @override
  String get attachmentFile => 'ملف';

  @override
  String get attachmentShare => 'منشور مشارَك';

  @override
  String get attachmentOther => 'مرفق';

  @override
  String get photoExpired => 'انتهت صلاحية هذه الصورة';

  @override
  String get backToInbox => 'العودة إلى الوارد';

  @override
  String get inboxFailedTitle => 'تعذّر تحميل الوارد';

  @override
  String get inboxFailedBody => 'تحقّق من اتصالك ثم أعد تحميل الصفحة.';

  @override
  String get messagesFailedTitle => 'تعذّر تحميل هذه الرسائل';

  @override
  String get messagesFailedBody => 'أعد تحميل الصفحة للمحاولة مرة أخرى.';

  @override
  String get platformInstagram => 'إنستغرام';

  @override
  String get platformMessenger => 'ماسنجر';

  @override
  String get missingConfigurationTitle => 'إعدادات ناقصة';

  @override
  String get missingConfigurationBody =>
      'قيمتا SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY تُدمجان وقت البناء. شغّل التطبيق مع ‎--dart-define-from-file=env.json‎ — انظر README.md.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get language => 'اللغة';

  @override
  String get pitchOne => 'محادثات إنستغرام وماسنجر في وارد واحد.';

  @override
  String get pitchTwo => 'من ينتظر أطول يظهر في الأعلى.';

  @override
  String get pitchThree => 'تعرف كم بقي لك للرد قبل أن تكتب.';

  @override
  String get aboutCustomer => 'عن الزبون';

  @override
  String get detailPlatform => 'المنصة';

  @override
  String get detailFirstWrote => 'أول رسالة';

  @override
  String get detailMessages => 'الرسائل';

  @override
  String get detailReplyWindow => 'نافذة الرد';

  @override
  String messageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
      zero: 'لا رسائل',
    );
    return '$_temp0';
  }

  @override
  String get windowOpen => 'مفتوحة';

  @override
  String get windowClosed => 'مُغلقة';

  @override
  String get detailsHidden => 'التفاصيل';
}
