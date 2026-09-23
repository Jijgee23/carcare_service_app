import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';

/// Mongolian labels for Feedback's fixed vocab — `FeedbackType` and
/// `FeedbackStatus` are closed enums straight from the Prisma schema
/// (measured at P7-F1), so a static map is enough; there is no server
/// vocab endpoint to degrade against, unlike Audit's `meta`.
String feedbackTypeLabel(FeedbackType type) => switch (type) {
  FeedbackType.bug => 'Алдаа',
  FeedbackType.suggestion => 'Санал',
  FeedbackType.other => 'Бусад',
};

IconData feedbackTypeIcon(FeedbackType type) => switch (type) {
  FeedbackType.bug => Icons.bug_report_outlined,
  FeedbackType.suggestion => Icons.lightbulb_outline,
  FeedbackType.other => Icons.chat_bubble_outline,
};

String feedbackStatusLabel(FeedbackStatus status) => switch (status) {
  FeedbackStatus.newTicket => 'Шинэ',
  FeedbackStatus.inReview => 'Хянагдаж байна',
  FeedbackStatus.resolved => 'Шийдэгдсэн',
  FeedbackStatus.dismissed => 'Хаагдсан',
  FeedbackStatus.unknown => 'Тодорхойгүй',
};

Color feedbackStatusColor(BuildContext context, FeedbackStatus status) =>
    switch (status) {
      FeedbackStatus.newTicket => context.colors.accent,
      FeedbackStatus.inReview => context.colors.warning,
      FeedbackStatus.resolved => context.colors.good,
      FeedbackStatus.dismissed => context.colors.textHint,
      FeedbackStatus.unknown => context.colors.textHint,
    };

String feedbackAuthorLabel(FeedbackAuthor author) => switch (author) {
  FeedbackAuthor.admin => 'Дэмжлэгийн баг',
  FeedbackAuthor.submitter => 'Та',
  FeedbackAuthor.unknown => 'Тодорхойгүй',
};
