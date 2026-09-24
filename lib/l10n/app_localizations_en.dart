// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get tagline =>
      'Every customer message, Instagram and Messenger, in one place.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInWrongCredentials =>
      'That email and password do not match an account.';

  @override
  String signInFailed(String error) {
    return 'Could not sign in. $error';
  }

  @override
  String customersWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers waiting',
      one: '1 customer waiting',
      zero: 'Nobody is waiting',
    );
    return '$_temp0';
  }

  @override
  String get everyoneAnswered => 'Everyone has been answered';

  @override
  String get waitingForReply => 'Waiting for a reply';

  @override
  String get answered => 'Answered';

  @override
  String get customer => 'Customer';

  @override
  String get noConversationsTitle => 'No conversations yet';

  @override
  String get noConversationsBody =>
      'Messages arrive here as customers write to you. Anything sent before you connected stays in Meta\'s apps.';

  @override
  String get longestWait => 'Longest wait';

  @override
  String get windowExplanation =>
      'Meta closes the reply window 24 hours after a customer writes. After that you cannot reply until they write again.';

  @override
  String get replyWindowClosedShort => 'The reply window has closed';

  @override
  String get replyWindowClosedLong =>
      'The reply window has closed. You can answer again once this customer writes to you.';

  @override
  String get replyingNotBuilt => 'Replying is not built yet.';

  @override
  String get menu => 'Go to';

  @override
  String get inbox => 'Inbox';

  @override
  String get shop => 'Your shop';

  @override
  String get shopCurrency => 'Currency';

  @override
  String get shopCurrencyBody =>
      'Written the way you write it to a customer, and repeated back the same way.';

  @override
  String get shopDelivery => 'Delivery';

  @override
  String get shopDeliveryBody =>
      'Where you deliver and what you charge. This is what the assistant answers \"how much is delivery\" with.';

  @override
  String get shopDeliveryEmpty => 'No areas added yet.';

  @override
  String get shopZoneAdd => 'Add an area';

  @override
  String get shopZoneName => 'Area';

  @override
  String get shopZoneFee => 'Fee';

  @override
  String get shopZoneFeeHint =>
      'Leave it empty if the fee varies. The assistant will say it depends rather than invent a number.';

  @override
  String get shopZoneNoFee => 'Depends';

  @override
  String get shopDeliveryNote => 'Other delivery rules';

  @override
  String get shopDeliveryNoteHint =>
      'Such as free over 50 dinars, or same day inside Amman.';

  @override
  String get shopLocations => 'Shop locations';

  @override
  String get shopLocationsHint =>
      'Your address or pickup point. One branch per line.';

  @override
  String get shopHours => 'Opening hours';

  @override
  String get shopHoursHint =>
      'Such as Saturday to Thursday 10am to 8pm, closed Friday.';

  @override
  String get shopAbout => 'Anything else';

  @override
  String get shopAboutBody =>
      'Whatever else you want the assistant to know: how to order, cash on delivery, returns, or anything particular to you.';

  @override
  String get shopAboutHint =>
      'The assistant reads this as you wrote it. It is also where to correct it if it keeps getting something wrong.';

  @override
  String get products => 'Products';

  @override
  String get productsBody =>
      'What you sell, so the assistant knows what to answer. A name and a price is enough.';

  @override
  String get productsEmpty => 'No products yet.';

  @override
  String get productAdd => 'Add a product';

  @override
  String get productEdit => 'Edit';

  @override
  String get productDelete => 'Delete';

  @override
  String get productSave => 'Save';

  @override
  String get productName => 'Name';

  @override
  String get productPrice => 'Price';

  @override
  String get productDescription => 'Details';

  @override
  String get productDescriptionHint =>
      'Sizes, colours, material, fit… write it the way you\'d tell a customer. The assistant will understand.';

  @override
  String get productCategory => 'Category';

  @override
  String get productCategoryHint =>
      'For example: Dresses. Optional, and useful for offers.';

  @override
  String get productPhotos => 'Photos';

  @override
  String get productPhotoAdd => 'Add photos';

  @override
  String get productPhotoCover => 'Cover';

  @override
  String get productPhotoMakeCover => 'Make this the cover';

  @override
  String get productPhotoRemove => 'Remove';

  @override
  String get productPhotosBody =>
      'The first photo is the one the assistant sends to someone who asks to see it. Up to five.';

  @override
  String get productPhotosFailed =>
      'Some photos could not be read. Try JPG or PNG.';

  @override
  String get productPhotosFull => 'Five photos at most.';

  @override
  String get productNoPhoto => 'No photo';

  @override
  String get catalogAll => 'All';

  @override
  String get catalogSearch => 'Search products';

  @override
  String get catalogNoMatch => 'No product matches.';

  @override
  String get productInStock => 'In stock';

  @override
  String get productOutOfStock => 'Out of stock';

  @override
  String get productDeleteTitle => 'Delete this product?';

  @override
  String productDeleteBody(String name) {
    return 'The assistant will stop mentioning it. $name';
  }

  @override
  String get productDeleteConfirm => 'Delete';

  @override
  String get catalogSaveFailed => 'That did not save. Try again.';

  @override
  String get catalogFailed => 'Products could not be opened';

  @override
  String get catalogFailedBody => 'Check your connection and try again.';

  @override
  String get catalogPaste => 'Import a list';

  @override
  String get catalogPasteBody =>
      'Choose the price list you already have, or copy the rows from your sheet and paste them. No need to change its columns: we find the name and the price, and anything else — colour, size — goes into the details.\n\nTo update products you added before, your file needs a \"Product code\" column. A row whose code exists updates that product; a row with no code is added as a new product and given one. The easiest way: download your list, edit it, and import it back.';

  @override
  String get catalogPasteHint => 'Paste the rows here';

  @override
  String get catalogPasteAdd => 'Add';

  @override
  String get catalogPasteNothing =>
      'No products were found in what you pasted.';

  @override
  String catalogPasteAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products added',
      one: 'One product added',
      zero: 'Nothing was added',
    );
    return '$_temp0';
  }

  @override
  String get catalogTemplateCopy => 'Copy a blank template';

  @override
  String get catalogTemplateCopied => 'Template copied. Paste it into Excel.';

  @override
  String get needsYou => 'Needs you';

  @override
  String get needsYouTitle =>
      'The assistant handed this to you — the customer is waiting';

  @override
  String get needsYouList => 'Conversations that need you';

  @override
  String get needsYouEmpty => 'Nothing needs you right now.';

  @override
  String get needsYouTooltip => 'What needs your reply';

  @override
  String get offerKindText => 'In your words';

  @override
  String get offerText => 'The offer';

  @override
  String get offerTextHint =>
      'Write it the way you would tell a customer, using product and category names exactly as they are in your list so the assistant understands it. For example: \"20% off the Dresses category\" or \"second bag half price\". Set the dates below, not in the text.';

  @override
  String get offerTextScope =>
      'Optional: if you pick categories or products, the assistant will not apply it to anything else.';

  @override
  String get escalatedNoPhoto =>
      'The customer asked to see a product that has no photo yet';

  @override
  String get productCode => 'Product code';

  @override
  String get productCodeHint =>
      'Left blank, one is given automatically. It is what links this product to its row in your Excel file when you import it again.';

  @override
  String get productCodeTaken =>
      'Another product has this code. Choose a different one.';

  @override
  String get catalogDownload => 'Download my list';

  @override
  String get catalogYes => 'yes';

  @override
  String get catalogNo => 'no';

  @override
  String catalogUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products updated',
      one: '1 product updated',
    );
    return '$_temp0';
  }

  @override
  String get categoriesEdit => 'Edit categories';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesEmpty =>
      'No categories. One is made when you type it on a product.';

  @override
  String get categoryRename => 'Rename';

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
      zero: 'No products',
    );
    return '$_temp0';
  }

  @override
  String categoryDeleteTitle(String name) {
    return 'Delete the category “$name”?';
  }

  @override
  String get categoryDeleteBody =>
      'Its products stay as they are, without a category. Offers on this category will no longer cover them.';

  @override
  String get categoryTaken => 'A category with that name already exists.';

  @override
  String get done => 'Done';

  @override
  String get offerCoversNothing => 'No longer covers anything';

  @override
  String get offers => 'Offers';

  @override
  String get offersBody =>
      'The sales you are running. The assistant mentions one when a customer asks about something it covers — once, and without pushing. If two offers cover a product, the better one for the customer applies.';

  @override
  String get offersEmpty => 'No offers yet.';

  @override
  String get offersFailed => 'Offers could not be opened';

  @override
  String get offerAdd => 'Add an offer';

  @override
  String get offerEdit => 'Edit offer';

  @override
  String get offerKindPercent => 'Percent';

  @override
  String get offerKindAmount => 'Amount';

  @override
  String get offerKindBuyGet => 'Buy & get';

  @override
  String get offerPercent => 'Percent off';

  @override
  String get offerAmount => 'Amount off';

  @override
  String get offerBuy => 'Buy';

  @override
  String get offerGet => 'Get free';

  @override
  String get offerBuyGetHint =>
      'For example: buy 2, get 1 free. The cheapest item is the free one.';

  @override
  String get offerAppliesTo => 'Applies to';

  @override
  String get offerWholeShop => 'The whole shop';

  @override
  String get offerCategories => 'Categories';

  @override
  String get offerProducts => 'Products';

  @override
  String get offerNoCategories =>
      'No categories yet. Give your products a category on the Products page.';

  @override
  String get offerStarts => 'Starts';

  @override
  String get offerEnds => 'Ends';

  @override
  String get offerStartsNow => 'Now';

  @override
  String get offerNoEnd => 'No end date';

  @override
  String get offerName => 'Offer name (optional)';

  @override
  String get offerNameHint =>
      'Such as: Eid sale. It is what the assistant calls it to customers.';

  @override
  String get offerRunning => 'Running';

  @override
  String get offerScheduled => 'Not started';

  @override
  String get offerEnded => 'Ended';

  @override
  String get offerOff => 'Off';

  @override
  String get offerDeleteTitle => 'Delete this offer?';

  @override
  String get offerDeleteBody => 'The assistant will stop mentioning it.';

  @override
  String offerSummaryPercent(String value) {
    return '$value% off';
  }

  @override
  String offerSummaryAmount(String value) {
    return '$value off';
  }

  @override
  String offerSummaryBuyGet(String buy, String get) {
    return 'Buy $buy, get $get free';
  }

  @override
  String offerUntil(String date) {
    return 'until $date';
  }

  @override
  String offerFrom(String date) {
    return 'from $date';
  }

  @override
  String get assistantTitle => 'The assistant';

  @override
  String get assistantBody =>
      'Answers your customers from your list, suggests what might suit them, and brings you anything it should not answer itself.';

  @override
  String get assistantNeedsCatalog =>
      'Add a product first. With no list, the assistant has nothing to answer from.';

  @override
  String get sentAutomatically => 'Automatic reply';

  @override
  String get answeredByAssistant => 'The assistant answered';

  @override
  String get broughtToYou => 'Handed to you';

  @override
  String get escalatedWindowClosed =>
      'The reply window closed before it could answer';

  @override
  String get escalatedAiStreak => 'It has answered several times running here';

  @override
  String get escalatedSellerPresent =>
      'You were replying yourself, so it stayed out of it';

  @override
  String get escalatedCeiling =>
      'The assistant has reached its limit for this month';

  @override
  String get escalatedUngrounded =>
      'It nearly said something you have not written down';

  @override
  String get escalatedNotSent => 'Its reply could not be sent';

  @override
  String get alertWrote => 'wrote to you';

  @override
  String get alertHandedOver => 'The assistant brought this to you';

  @override
  String get alerts => 'Alerts';

  @override
  String get alertsBody =>
      'Your browser tells you when a customer writes, or when the assistant brings you a conversation. This device only.';

  @override
  String get shopPricing => 'Price';

  @override
  String get shopPricingBody =>
      'What the assistant does when a customer asks for a better price. It only ever states what you have written down — the price from your list, and any sale once that exists.';

  @override
  String get shopPricingHandOver => 'Tell me about it';

  @override
  String get shopPricingHandOverBody =>
      'It gives the price, does not bargain, and brings the conversation to you to decide.';

  @override
  String get shopPricingFinal => 'Say the price is final';

  @override
  String get shopPricingFinalBody =>
      'It says kindly that the price is not negotiable, then offers something cheaper from your list rather than ending the conversation. It does not bring it to you.';

  @override
  String get settingsYou => 'You and this browser';

  @override
  String get settingsLanguage => 'Interface language';

  @override
  String get settingsLanguageBody => 'Saved in this browser.';

  @override
  String get password => 'Password';

  @override
  String get passwordBody =>
      'At least 10 characters, with an upper-case letter, a lower-case letter and a digit.';

  @override
  String get passwordNew => 'New password';

  @override
  String get passwordCurrent => 'Current password';

  @override
  String get passwordRepeat => 'Type it again';

  @override
  String get passwordMismatch => 'Those two do not match.';

  @override
  String get passwordWrong => 'That is not your current password.';

  @override
  String get passwordChange => 'Change password';

  @override
  String get passwordChanging => 'Saving';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get passwordFailed => 'Could not change the password. Try again.';

  @override
  String get alertsDenied => 'Alerts are blocked in your browser';

  @override
  String get alertsUnsupported => 'Alerts are not available here';

  @override
  String get invite => 'Invite';

  @override
  String get inviteTitle => 'Invite a seller';

  @override
  String get inviteBody =>
      'This creates a new Rabta account. They choose their own password from the link, so we never know it and it never travels through a chat.';

  @override
  String get inviteAction => 'Create invitation';

  @override
  String get inviteCreating => 'Creating';

  @override
  String get inviteLinkTitle => 'The link is ready';

  @override
  String inviteLinkBody(String email) {
    return 'Send it to $email. It works once, and expires within 24 hours.';
  }

  @override
  String get copyLink => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get inviteAnother => 'Invite someone else';

  @override
  String get inviteFailedNotAdmin => 'You are not allowed to create accounts.';

  @override
  String get inviteFailedExists => 'That email already has an account.';

  @override
  String get inviteFailedInvalid => 'That is not a valid email address.';

  @override
  String get inviteFailedEmpty => 'Enter an email address first.';

  @override
  String get inviteFailedOther => 'Could not create the invitation. Try again.';

  @override
  String get inviteNoEmailYet =>
      'Links are not emailed yet, so copy it and send it yourself.';

  @override
  String get setPasswordTitle => 'Choose a password';

  @override
  String get setPasswordWelcome =>
      'Welcome to Rabta. Choose a password for your account, and use it to sign in from now on.';

  @override
  String get setPasswordRenew => 'Choose a new password for your account.';

  @override
  String get newPasswordLabel => 'Password';

  @override
  String get passwordTooShort =>
      'At least 10 characters, with an upper-case letter, a lower-case letter and a digit.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get setPasswordAction => 'Save and continue';

  @override
  String get setPasswordSaving => 'Saving';

  @override
  String setPasswordFailed(String error) {
    return 'Could not save the password. $error';
  }

  @override
  String get inviteExpired =>
      'This invitation link has expired. Ask for a new one.';

  @override
  String get accounts => 'Accounts';

  @override
  String get connectTitle => 'Connect your accounts';

  @override
  String get connectBody =>
      'Instagram and Messenger messages arrive here once you connect your Page. Anything sent before you connect stays in Meta\'s apps.';

  @override
  String get connectAction => 'Connect with Meta';

  @override
  String get connectOpening => 'Opening Meta';

  @override
  String get connectAnother => 'Connect another account';

  @override
  String get noAccountsRow => 'No account connected';

  @override
  String get accountsBody => 'The accounts whose messages reach Rabta.';

  @override
  String get accountActive => 'Receiving messages';

  @override
  String get accountNeedsReconnect => 'Disconnected — reconnect it';

  @override
  String get accountDisconnected => 'Turned off';

  @override
  String get disconnect => 'Turn off';

  @override
  String get disconnectTitle => 'Turn this account off?';

  @override
  String get disconnectBody =>
      'New messages from this account will stop arriving. Past conversations stay as they are, and you can connect it again at any time.';

  @override
  String get disconnectConfirm => 'Turn it off';

  @override
  String get cancel => 'Cancel';

  @override
  String get connectFailed => 'Could not start connecting. Try again.';

  @override
  String get connectFailedSignedOut => 'Your session has ended. Sign in again.';

  @override
  String get composerHint => 'Write your reply';

  @override
  String get sendReply => 'Send';

  @override
  String get sending => 'Sending';

  @override
  String get sendFailedTooLong =>
      'This reply is longer than the platform allows. Shorten it a little.';

  @override
  String get sendFailedWindowClosed =>
      'The reply window closed while you were writing, so your reply was not sent.';

  @override
  String get sendFailedNoWindow =>
      'You cannot reply until this customer writes to you.';

  @override
  String get sendFailedDisconnected =>
      'Your account connection has expired. Reconnect it to reply.';

  @override
  String get sendFailedRejected =>
      'The platform did not accept this reply, so it was not sent.';

  @override
  String get sendFailedUnreachable =>
      'Could not reach the platform. Check your connection and try again.';

  @override
  String get sendFailedNotFound => 'This conversation is no longer available.';

  @override
  String minutesLeftToReply(int count) {
    return '${count}m left to reply';
  }

  @override
  String hoursLeftToReply(int count) {
    return '${count}h left to reply';
  }

  @override
  String get justNow => 'now';

  @override
  String minutesAgo(int count) {
    return '${count}m';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h';
  }

  @override
  String daysAgo(int count) {
    return '${count}d';
  }

  @override
  String weeksAgo(int count) {
    return '${count}w';
  }

  @override
  String get attachmentPhoto => 'Photo';

  @override
  String get attachmentVideo => 'Video';

  @override
  String get attachmentVoice => 'Voice message';

  @override
  String get attachmentFile => 'File';

  @override
  String get attachmentShare => 'Shared post';

  @override
  String get attachmentOther => 'Attachment';

  @override
  String get photoExpired => 'This photo has expired';

  @override
  String get backToInbox => 'Back to inbox';

  @override
  String get inboxFailedTitle => 'The inbox did not load';

  @override
  String get inboxFailedBody => 'Check your connection, then reload the page.';

  @override
  String get messagesFailedTitle => 'These messages did not load';

  @override
  String get messagesFailedBody => 'Reload the page to try again.';

  @override
  String get platformInstagram => 'Instagram';

  @override
  String get platformMessenger => 'Messenger';

  @override
  String get missingConfigurationTitle => 'Missing configuration';

  @override
  String get missingConfigurationBody =>
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are compiled in. Run with --dart-define-from-file=env.json — see README.md.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get language => 'Language';

  @override
  String get pitchOne => 'Instagram and Messenger in one inbox.';

  @override
  String get pitchTwo => 'Whoever waited longest comes first.';

  @override
  String get pitchThree => 'See how long you have left before you type.';

  @override
  String get aboutCustomer => 'About this customer';

  @override
  String get detailPlatform => 'Platform';

  @override
  String get detailFirstWrote => 'First message';

  @override
  String get detailMessages => 'Messages';

  @override
  String get detailReplyWindow => 'Reply window';

  @override
  String messageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
      zero: 'No messages',
    );
    return '$_temp0';
  }

  @override
  String get windowOpen => 'Open';

  @override
  String get windowClosed => 'Closed';

  @override
  String get detailsHidden => 'Details';

  @override
  String get catalogFileChoose => 'Choose an Excel file';

  @override
  String get catalogFileOr => 'Or paste the rows';

  @override
  String get catalogFileOldExcel =>
      'This is an old-style Excel file (.xls). Open it, save it as .xlsx, and choose it again.';

  @override
  String get catalogFileUnreadable =>
      'This file could not be read. Try an .xlsx or .csv file.';

  @override
  String get searchHint => 'Search by customer name or message';

  @override
  String get searchNoResults => 'No conversations match your search';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get reconnectBanner =>
      'One of your accounts has stopped receiving messages. Reconnect it so customers\' messages reach you.';

  @override
  String get reconnectAction => 'Reconnect';

  @override
  String get assistantHere => 'Assistant';

  @override
  String get assistantHereOn =>
      'The assistant replies in this conversation. Turn it off to handle it yourself.';

  @override
  String get assistantHereOff =>
      'You\'re handling this conversation. The assistant won\'t reply here until you turn it back on.';

  @override
  String get teachTitle => 'Should the assistant know this answer next time?';

  @override
  String get teachBody =>
      'Edit it if needed. It\'s added to your shop\'s information and the assistant uses it with every customer.';

  @override
  String get teachSave => 'Save';

  @override
  String get teachDismiss => 'Not now';

  @override
  String get teachSaved => 'Saved. The assistant will use it from now on.';

  @override
  String get teachFailed => 'Not saved. Try again.';

  @override
  String get outcomeOrdered => 'Ordered';

  @override
  String get outcomeNotBought => 'Didn\'t buy';

  @override
  String get outcomeJustAsking => 'Just asking';

  @override
  String get outcomeOpen => 'Still open';

  @override
  String get outcomeQuestion => 'How did it end?';

  @override
  String get outcomeSet => 'Outcome';

  @override
  String get outcomeByAssistant => 'Set by the assistant. You can change it.';

  @override
  String get outcomeBySeller => 'Set by you';

  @override
  String get outcomeWhy => 'Why';

  @override
  String get outcomeNoReason => 'No clear reason';

  @override
  String get reason_price => 'Price';

  @override
  String get reason_delivery_fee => 'Delivery fee';

  @override
  String get reason_delivery_time => 'Delivery time';

  @override
  String get reason_size_or_variant => 'Size or colour not available';

  @override
  String get reason_out_of_stock => 'Out of stock';

  @override
  String get reason_not_sold => 'Something we don\'t sell';

  @override
  String get reason_no_answer => 'Never answered';

  @override
  String get reason_unknown => 'No clear reason';

  @override
  String get results => 'Results';

  @override
  String get resultsTitle => 'Last 7 days';

  @override
  String resultsOrders(int ordered, int total) {
    return '$ordered of $total conversations ended in an order';
  }

  @override
  String get resultsNone => 'No conversations in the last 7 days.';

  @override
  String get resultsPending =>
      'A conversation is read once it has been quiet for 12 hours, so today\'s may not show yet.';

  @override
  String get resultsWhy => 'Why customers didn\'t buy';

  @override
  String get resultsProducts => 'Most asked about';

  @override
  String resultsProductLine(int asked, int ordered) {
    return 'Asked $asked · Ordered $ordered';
  }

  @override
  String get resultsAreas => 'Where customers are';

  @override
  String resultsUnanswered(int count) {
    return 'Customers whose reply window closed unanswered: $count';
  }

  @override
  String get resultsHours => 'When customers write';

  @override
  String resultsBusiest(int from, int to) {
    return 'Busiest from $from:00 to $to:00';
  }

  @override
  String resultsAccuracy(int read, int corrected) {
    return 'The assistant read $read conversations, and you changed $corrected of them.';
  }

  @override
  String get resultsFailed => 'Couldn\'t load the results. Try again.';

  @override
  String get resultsRetry => 'Try again';

  @override
  String get newVersion => 'A new version of Rabta is ready.';

  @override
  String get reload => 'Reload';

  @override
  String get admin => 'Admin';

  @override
  String get adminTitle => 'Rabta admin';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminFailed => 'Couldn\'t load the admin data.';

  @override
  String get adminHealth => 'Service health';

  @override
  String get adminAllGood => 'Everything is working.';

  @override
  String get adminProblems => 'Something needs your attention:';

  @override
  String get adminLastDelivery => 'Last message from Meta';

  @override
  String get adminNever => 'None yet';

  @override
  String get adminUnprocessed => 'Messages not processed yet';

  @override
  String get adminFailing => 'Messages that failed and will be retried';

  @override
  String get adminStuck => 'Messages that gave up after 5 tries';

  @override
  String get adminReconnect => 'Accounts that need reconnecting';

  @override
  String get adminErrors => 'Errors in the last 24 hours';

  @override
  String get adminWarnings => 'Warnings in the last 24 hours';

  @override
  String get adminClientErrors => 'Errors on sellers\' screens, last 24 hours';

  @override
  String get adminAiCost => 'Assistant cost this month';

  @override
  String get adminAiCalls => 'Assistant calls this month';

  @override
  String get adminSellers => 'Sellers';

  @override
  String get adminYou => 'Admin';

  @override
  String get adminNoAccounts => 'No accounts connected';

  @override
  String get adminConversations => 'Conversations';

  @override
  String get adminMessages7d => 'Messages, last 7 days';

  @override
  String get adminLastMessage => 'Last message';

  @override
  String get adminLastSignIn => 'Last sign-in';

  @override
  String get adminProducts => 'Products';

  @override
  String get adminAssistant => 'Assistant';

  @override
  String get adminOn => 'On';

  @override
  String get adminOff => 'Off';

  @override
  String get adminAiReplies => 'Assistant replies this month';

  @override
  String get adminHandedOver => 'Handed over, waiting';

  @override
  String get adminOrdered => 'Orders this month';

  @override
  String get adminEvents => 'Recent events';

  @override
  String get adminNoEvents => 'No events yet.';

  @override
  String get adminScreenErrors => 'Errors on sellers\' screens';

  @override
  String get adminNoScreenErrors => 'No errors.';

  @override
  String get adminInvite => 'Invite a seller';

  @override
  String get adminStatusActive => 'Active';

  @override
  String get adminStatusReconnect => 'Needs reconnect';

  @override
  String get adminStatusOff => 'Disconnected';
}
