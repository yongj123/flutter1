
import 'package:enough_mail/enough_mail.dart';

enum MailCategory { socialMedia, promotions, other }

class MailClassifierService {
  static final _socialMediaSenders = {
    'facebook.com',
    'twitter.com',
    'linkedin.com',
    'instagram.com',
  };

  static final _promotionKeywords = {
    'sale',
    'offer',
    'discount',
    'promotion',
    'deals',
  };

  MailCategory classify(MimeMessage email) {
    final from = email.from?.first.email.toLowerCase() ?? '';
    final subject = email.decodeSubject()?.toLowerCase() ?? '';

    if (_socialMediaSenders.any((sender) => from.contains(sender))) {
      return MailCategory.socialMedia;
    }

    if (_promotionKeywords.any((keyword) => subject.contains(keyword))) {
      return MailCategory.promotions;
    }

    return MailCategory.other;
  }
}
