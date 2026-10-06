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
  String get productDescription => 'التفاصيل';

  @override
  String get productDescriptionHint =>
      'المقاسات، الألوان، الخامة، القَصّة… اكتبها كما تقولها للزبون، والمساعد يفهمها.';

  @override
  String get productCategory => 'القسم';

  @override
  String get productCategoryHint => 'مثل: فساتين. اختياري، ويفيد في العروض.';

  @override
  String get productPhotos => 'الصور';

  @override
  String get productPhotoAdd => 'أضف صوراً';

  @override
  String get productPhotoCover => 'الغلاف';

  @override
  String get productPhotoMakeCover => 'اجعلها الغلاف';

  @override
  String get productPhotoRemove => 'إزالة';

  @override
  String get productPhotosBody =>
      'الصورة الأولى هي التي يرسلها المساعد لمن يطلب أن يرى المنتج. حتى خمس صور.';

  @override
  String get productPhotosFailed =>
      'تعذّرت قراءة بعض الصور. جرّب صوراً بصيغة JPG أو PNG.';

  @override
  String get productPhotosFull => 'خمس صور كحد أقصى.';

  @override
  String get productNoPhoto => 'بلا صورة';

  @override
  String get catalogAll => 'الكل';

  @override
  String get catalogSearch => 'ابحث في المنتجات';

  @override
  String get catalogNoMatch => 'لا يوجد منتج يطابق.';

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
  String get catalogPaste => 'استيراد قائمة';

  @override
  String get catalogPasteBody =>
      'اختر ملف الأسعار الذي عندك، أو انسخ الصفوف من الجدول والصقها. لا داعي لتغيير أعمدته: نفهم الاسم والسعر، وما زاد عنهما — اللون، المقاس — يُضاف إلى التفاصيل.\n\nلتحديث منتجات أضفتها من قبل، يجب أن يكون في ملفك عمود «رمز المنتج». الصف الذي رمزه موجود يحدّث ذلك المنتج، والصف الذي لا رمز له يُضاف منتجاً جديداً ويُعطى رمزاً. أسهل طريقة: نزّل قائمتك، عدّلها، ثم استوردها.';

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
  String get needsYou => 'بحاجة لك';

  @override
  String get needsYouTitle => 'حوّلها المساعد إليك، والزبون بانتظار ردك';

  @override
  String get needsYouList => 'محادثات بحاجة لك';

  @override
  String get needsYouEmpty => 'لا شيء بحاجة لك الآن.';

  @override
  String get needsYouTooltip => 'ما يحتاج ردك';

  @override
  String get offerKindText => 'بكلماتك';

  @override
  String get offerText => 'العرض';

  @override
  String get offerTextHint =>
      'اكتبه كما تقوله للزبون، واستخدم أسماء المنتجات والأقسام كما هي في قائمتك ليفهمه المساعد. مثل: «خصم 20% على قسم فساتين» أو «القطعة الثانية من الشنط بنصف السعر». التاريخ تحدّده تحت، لا في النص.';

  @override
  String get offerTextScope =>
      'اختياري: إن حدّدت أقساماً أو منتجات، لن يطبّقه المساعد على غيرها.';

  @override
  String get escalatedNoPhoto => 'طلب الزبون صورة لمنتج ليس له صورة بعد';

  @override
  String get productCode => 'رمز المنتج';

  @override
  String get productCodeHint =>
      'إذا تركته فارغاً يُعطى رمزاً تلقائياً. هو ما يربط هذا المنتج بصفّه في ملف Excel عندما تستورده مرة أخرى.';

  @override
  String get productCodeTaken => 'هذا الرمز لمنتج آخر. اختر رمزاً غيره.';

  @override
  String get catalogDownload => 'تنزيل قائمتي';

  @override
  String get catalogYes => 'نعم';

  @override
  String get catalogNo => 'لا';

  @override
  String catalogUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُدّث $count منتج',
      many: 'حُدّث $count منتجاً',
      few: 'حُدّثت $count منتجات',
      two: 'حُدّث منتجان',
      one: 'حُدّث منتج واحد',
    );
    return '$_temp0';
  }

  @override
  String get categoriesEdit => 'تعديل الأقسام';

  @override
  String get categoriesTitle => 'الأقسام';

  @override
  String get categoriesEmpty => 'لا توجد أقسام. تُنشأ عندما تكتب قسماً لمنتج.';

  @override
  String get categoryRename => 'إعادة تسمية';

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجاً',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا منتجات',
    );
    return '$_temp0';
  }

  @override
  String categoryDeleteTitle(String name) {
    return 'حذف قسم «$name»؟';
  }

  @override
  String get categoryDeleteBody =>
      'تبقى منتجاته كما هي، لكن بلا قسم. والعروض على هذا القسم لن تشملها بعد الآن.';

  @override
  String get categoryTaken => 'يوجد قسم بهذا الاسم.';

  @override
  String get done => 'تم';

  @override
  String get offerCoversNothing => 'لم يعد يشمل شيئاً';

  @override
  String get offers => 'العروض';

  @override
  String get offersBody =>
      'الخصومات التي تعرضها. يذكرها المساعد للزبون عندما يسأل عن منتج يشمله العرض، مرة واحدة ودون إلحاح. إذا شمل المنتجَ عرضان، يُطبَّق الأفضل للزبون.';

  @override
  String get offersEmpty => 'لا توجد عروض بعد.';

  @override
  String get offersFailed => 'تعذّر فتح العروض';

  @override
  String get offerAdd => 'أضف عرضاً';

  @override
  String get offerEdit => 'تعديل العرض';

  @override
  String get offerKindPercent => 'نسبة';

  @override
  String get offerKindAmount => 'مبلغ';

  @override
  String get offerKindBuyGet => 'اشترِ واحصل';

  @override
  String get offerPercent => 'النسبة %';

  @override
  String get offerAmount => 'المبلغ المخصوم';

  @override
  String get offerBuy => 'عند شراء';

  @override
  String get offerGet => 'يحصل مجاناً على';

  @override
  String get offerBuyGetHint =>
      'مثل: اشترِ 2 واحصل على 1 مجاناً. القطعة الأرخص هي المجانية.';

  @override
  String get offerAppliesTo => 'يشمل';

  @override
  String get offerWholeShop => 'كل المتجر';

  @override
  String get offerCategories => 'أقسام';

  @override
  String get offerProducts => 'منتجات';

  @override
  String get offerNoCategories =>
      'لا توجد أقسام بعد. اختر قسماً لمنتجاتك من صفحة المنتجات.';

  @override
  String get offerStarts => 'يبدأ';

  @override
  String get offerEnds => 'ينتهي';

  @override
  String get offerStartsNow => 'من الآن';

  @override
  String get offerNoEnd => 'بلا تاريخ';

  @override
  String get offerName => 'اسم العرض (اختياري)';

  @override
  String get offerNameHint => 'مثل: عرض العيد. هكذا يسمّيه المساعد للزبون.';

  @override
  String get offerRunning => 'جارٍ الآن';

  @override
  String get offerScheduled => 'لم يبدأ بعد';

  @override
  String get offerEnded => 'انتهى';

  @override
  String get offerOff => 'متوقف';

  @override
  String get offerDeleteTitle => 'حذف هذا العرض؟';

  @override
  String get offerDeleteBody => 'سيتوقف المساعد عن ذكره.';

  @override
  String offerSummaryPercent(String value) {
    return 'خصم $value%';
  }

  @override
  String offerSummaryAmount(String value) {
    return 'خصم $value';
  }

  @override
  String offerSummaryBuyGet(String buy, String get) {
    return 'اشترِ $buy واحصل على $get مجاناً';
  }

  @override
  String offerUntil(String date) {
    return 'حتى $date';
  }

  @override
  String offerFrom(String date) {
    return 'من $date';
  }

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
  String get alertsBody =>
      'ينبّهك المتصفّح عند وصول رسالة أو عندما يحوّل المساعد محادثة إليك. لهذا الجهاز وحده.';

  @override
  String get shopPricing => 'السعر';

  @override
  String get shopPricingBody =>
      'ماذا يفعل المساعد عندما يطلب الزبون سعراً أفضل. لا يقول إلا ما كتبته: السعر من قائمتك، وأي تخفيض عندما يتوفّر.';

  @override
  String get shopPricingHandOver => 'أعلمني';

  @override
  String get shopPricingHandOverBody =>
      'يقول السعر، ولا يساوم، ويحوّل المحادثة إليك لتقرّر.';

  @override
  String get shopPricingFinal => 'يقول إن السعر ثابت';

  @override
  String get shopPricingFinalBody =>
      'يقول بلطف إن السعر غير قابل للتفاوض، ثم يقترح قطعة أرخص من قائمتك بدل أن ينهي المحادثة. ولا يحوّلها إليك.';

  @override
  String get settingsYou => 'أنت وهذا المتصفّح';

  @override
  String get settingsLanguage => 'لغة الواجهة';

  @override
  String get settingsLanguageBody => 'يُحفظ في هذا المتصفّح.';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordBody =>
      '10 أحرف على الأقل، وفيها حرف كبير وحرف صغير ورقم.';

  @override
  String get passwordNew => 'كلمة المرور الجديدة';

  @override
  String get passwordCurrent => 'كلمة المرور الحالية';

  @override
  String get passwordRepeat => 'أعد كتابتها';

  @override
  String get passwordMismatch => 'الكلمتان غير متطابقتين.';

  @override
  String get passwordWrong => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get passwordChange => 'تغيير كلمة المرور';

  @override
  String get passwordChanging => 'جارٍ الحفظ';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور.';

  @override
  String get passwordFailed => 'تعذّر تغيير كلمة المرور. حاول مرة أخرى.';

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
  String get passwordTooShort =>
      '10 أحرف على الأقل، وفيها حرف كبير وحرف صغير ورقم.';

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
      'تصل رسائل إنستغرام وماسنجر وواتساب إلى هنا بعد ربطها. أما ما أُرسل قبل الربط فيبقى في تطبيقات ميتا.';

  @override
  String get connectAction => 'الربط مع ميتا';

  @override
  String get connectWhatsApp => 'ربط واتساب';

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
  String get platformWhatsApp => 'واتساب';

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
  String get pitchThree =>
      'المساعد يجيب عن السعر والتوفر وأنت مشغول، ويترك لك ما عداه.';

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

  @override
  String get catalogFileChoose => 'اختر ملف Excel';

  @override
  String get catalogFileOr => 'أو الصق الصفوف';

  @override
  String get catalogFileOldExcel =>
      'هذا ملف Excel بالصيغة القديمة XLS. افتحه واحفظه بصيغة XLSX، ثم اختره مرة أخرى.';

  @override
  String get catalogFileUnreadable =>
      'تعذّرت قراءة هذا الملف. جرّب ملف XLSX أو CSV.';

  @override
  String get searchHint => 'ابحث باسم الزبون أو بنص رسالة';

  @override
  String get searchNoResults => 'لا توجد محادثات تطابق بحثك';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get reconnectBanner =>
      'توقّف أحد حساباتك عن استقبال الرسائل. أعد ربطه حتى تصلك رسائل الزبائن.';

  @override
  String get reconnectAction => 'أعد الربط';

  @override
  String get assistantHere => 'المساعد';

  @override
  String get assistantHereOn =>
      'المساعد يردّ في هذه المحادثة. أوقفه لتتولّاها بنفسك.';

  @override
  String get assistantHereOff =>
      'أنت تتولّى هذه المحادثة، والمساعد لن يردّ فيها حتى تعيد تشغيله.';

  @override
  String get teachTitle =>
      'هل تريد أن يعرف المساعد هذا الجواب في المرة القادمة؟';

  @override
  String get teachBody =>
      'عدّل النص إن لزم. يُضاف إلى معلومات متجرك، ويستخدمه المساعد مع كل الزبائن.';

  @override
  String get teachSave => 'احفظ';

  @override
  String get teachDismiss => 'ليس الآن';

  @override
  String get teachSaved => 'حُفظ. سيستخدمه المساعد من الآن.';

  @override
  String get teachFailed => 'لم يُحفظ. حاول مرة أخرى.';

  @override
  String get outcomeOrdered => 'طلب';

  @override
  String get outcomeNotBought => 'لم يشترِ';

  @override
  String get outcomeJustAsking => 'استفسار';

  @override
  String get outcomeOpen => 'لم تُحسم بعد';

  @override
  String get outcomeQuestion => 'كيف انتهت المحادثة؟';

  @override
  String get outcomeSet => 'النتيجة';

  @override
  String get outcomeByAssistant => 'حدّدها المساعد، ويمكنك تعديلها';

  @override
  String get outcomeBySeller => 'حدّدتها أنت';

  @override
  String get outcomeWhy => 'السبب';

  @override
  String get outcomeNoReason => 'بدون سبب واضح';

  @override
  String get reason_price => 'السعر';

  @override
  String get reason_delivery_fee => 'رسوم التوصيل';

  @override
  String get reason_delivery_time => 'مدة التوصيل';

  @override
  String get reason_size_or_variant => 'المقاس أو اللون غير متوفر';

  @override
  String get reason_out_of_stock => 'نفد من المخزون';

  @override
  String get reason_not_sold => 'منتج لا نبيعه';

  @override
  String get reason_no_answer => 'لم يُرَدّ عليه';

  @override
  String get reason_unknown => 'بدون سبب واضح';

  @override
  String get results => 'النتائج';

  @override
  String get resultsTitle => 'آخر 7 أيام';

  @override
  String resultsOrders(int ordered, int total) {
    return 'محادثات انتهت بطلب: $ordered من $total';
  }

  @override
  String get resultsNone => 'لا توجد محادثات في آخر 7 أيام.';

  @override
  String get resultsPending =>
      'تُقرأ المحادثة بعد أن تهدأ 12 ساعة، فقد لا تظهر محادثات اليوم بعد.';

  @override
  String get resultsWhy => 'لماذا لم يشترِ الزبائن';

  @override
  String get resultsProducts => 'الأكثر سؤالاً عنه';

  @override
  String resultsProductLine(int asked, int ordered) {
    return 'سُئل عنه $asked · طلبات $ordered';
  }

  @override
  String get resultsAreas => 'من أين يكتب الزبائن';

  @override
  String resultsUnanswered(int count) {
    return 'زبائن أُغلقت نافذة الرد قبل أن يُرَدّ عليهم: $count';
  }

  @override
  String get resultsHours => 'متى يكتب الزبائن';

  @override
  String resultsBusiest(int from, int to) {
    return 'أكثر الأوقات ازدحاماً من $from:00 إلى $to:00';
  }

  @override
  String resultsAccuracy(int read, int corrected) {
    return 'محادثات قرأها المساعد: $read، وعدّلتَ نتيجتها في: $corrected';
  }

  @override
  String get resultsFailed => 'تعذّر تحميل النتائج. حاول مرة أخرى.';

  @override
  String get resultsRetry => 'حاول مرة أخرى';

  @override
  String get newVersion => 'نسخة جديدة من ربطة جاهزة.';

  @override
  String get reload => 'إعادة التحميل';

  @override
  String get admin => 'الإدارة';

  @override
  String get adminTitle => 'إدارة ربطة';

  @override
  String get adminRefresh => 'تحديث';

  @override
  String get adminFailed => 'تعذّر تحميل بيانات الإدارة.';

  @override
  String get adminHealth => 'حالة الخدمة';

  @override
  String get adminAllGood => 'كل شيء يعمل.';

  @override
  String get adminProblems => 'هناك ما يحتاج انتباهك:';

  @override
  String get adminLastDelivery => 'آخر رسالة وصلت من ميتا';

  @override
  String get adminNever => 'لم تصل أي رسالة بعد';

  @override
  String get adminUnprocessed => 'رسائل لم تُعالَج بعد';

  @override
  String get adminFailing => 'رسائل فشلت معالجتها وستُعاد';

  @override
  String get adminStuck => 'رسائل توقفت محاولات معالجتها';

  @override
  String get adminReconnect => 'حسابات تحتاج إعادة ربط';

  @override
  String get adminErrors => 'أخطاء خلال 24 ساعة';

  @override
  String get adminWarnings => 'تحذيرات خلال 24 ساعة';

  @override
  String get adminClientErrors => 'أخطاء على شاشات البائعين خلال 24 ساعة';

  @override
  String get adminAiCost => 'تكلفة المساعد هذا الشهر';

  @override
  String get adminAiCalls => 'طلبات المساعد هذا الشهر';

  @override
  String get adminSellers => 'البائعون';

  @override
  String get adminYou => 'مدير';

  @override
  String get adminNoAccounts => 'لم يربط أي حساب';

  @override
  String get adminConversations => 'المحادثات';

  @override
  String get adminMessages7d => 'رسائل آخر 7 أيام';

  @override
  String get adminLastMessage => 'آخر رسالة';

  @override
  String get adminLastSignIn => 'آخر دخول';

  @override
  String get adminProducts => 'المنتجات';

  @override
  String get adminAssistant => 'المساعد';

  @override
  String get adminOn => 'يعمل';

  @override
  String get adminOff => 'متوقف';

  @override
  String get adminAiReplies => 'ردود المساعد هذا الشهر';

  @override
  String get adminHandedOver => 'محادثات بانتظار البائع';

  @override
  String get adminOrdered => 'طلبات هذا الشهر';

  @override
  String get adminEvents => 'آخر الأحداث';

  @override
  String get adminNoEvents => 'لا توجد أحداث بعد.';

  @override
  String get adminScreenErrors => 'أخطاء على شاشات البائعين';

  @override
  String get adminNoScreenErrors => 'لا توجد أخطاء.';

  @override
  String get adminInvite => 'دعوة بائع';

  @override
  String get adminStatusActive => 'يعمل';

  @override
  String get adminStatusReconnect => 'يحتاج إعادة ربط';

  @override
  String get adminStatusOff => 'مفصول';

  @override
  String get signInHero => 'لا زبون ينتظر حتى الصباح.';

  @override
  String get signInWelcome => 'أهلاً من جديد';

  @override
  String get signInWelcomeBody => 'سجّل الدخول لترى من ينتظرك.';

  @override
  String get inviteSentTitle => 'أُرسلت الدعوة';

  @override
  String inviteSentBody(String email) {
    return 'أرسلنا إلى $email رابطاً ليختار كلمة المرور. يعمل مرة واحدة ولفترة محدودة. إذا لم يصله، اطلب منه أن يتفقّد مجلد الرسائل غير المرغوب فيها.';
  }

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get forgotPasswordNeedEmail =>
      'اكتب بريدك الإلكتروني أولاً، ثم اضغط «نسيت كلمة المرور؟».';

  @override
  String forgotPasswordSent(String email) {
    return 'إذا كان لـ $email حساب في ربطة، فقد أرسلنا إليه رابطاً لاختيار كلمة مرور جديدة.';
  }

  @override
  String get forgotPasswordFailed =>
      'تعذّر إرسال الرابط. انتظر دقيقة ثم حاول مرة أخرى.';
}
