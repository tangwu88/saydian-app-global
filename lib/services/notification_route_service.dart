import 'notification_models.dart';
import '../domain/ios_wellness_policy.dart';

enum NotificationRouteTarget {
  careInvitationReview,
  healthWarningHistory,
  notificationInbox,
}

final class NotificationRouteIntent {
  const NotificationRouteIntent({
    required this.target,
    required this.eventId,
    this.entityId,
  });

  final NotificationRouteTarget target;
  final String eventId;
  final String? entityId;
}

final class NotificationRouteService {
  const NotificationRouteService();

  NotificationRouteIntent resolve(NotificationEvent event) =>
      NotificationRouteIntent(
        target: switch (event.type) {
          NotificationEventType.careInvitation =>
            NotificationRouteTarget.careInvitationReview,
          NotificationEventType.healthWarning =>
            IosWellnessPolicy.current.enabled
                ? NotificationRouteTarget.notificationInbox
                : NotificationRouteTarget.healthWarningHistory,
          NotificationEventType.system =>
            NotificationRouteTarget.notificationInbox,
        },
        eventId: event.eventId,
        entityId: event.entityId,
      );
}
