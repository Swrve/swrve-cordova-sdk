#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

@protocol SwrveGeoCustomFilterDelegate <NSObject>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"

/**
 * Must be implemented as part of Custom Geo Filtering.
 * \param notification Notification triggered from a geolocation.
 * \param customProperties Set of custom properties configured on the geoplace.
 * \return The notification to be disaplyed, return nil to avoid displaying the notification.
 */
- (UNMutableNotificationContent *)filterNotification:(UNMutableNotificationContent *) notification withCustomProperties:(NSDictionary *)customProperties;

#pragma clang diagnostic pop

@end

