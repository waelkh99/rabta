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
  String get productDescription => 'Description';

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
  String get catalogPaste => 'Paste a list';

  @override
  String get catalogPasteBody =>
      'Copy the rows from Excel or Google Sheets and paste them here. They are added to your list, not swapped for it.';

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
  String get passwordBody => 'At least 8 characters.';

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
  String get passwordTooShort => 'Use at least 8 characters.';

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
}
