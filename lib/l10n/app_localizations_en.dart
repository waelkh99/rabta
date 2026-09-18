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
