#import "SwrvePluginPushHandler.h"
#import "SwrvePlugin.h"

@implementation SwrvePluginPushHandler

- (void) didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    [SwrvePlugin didReceiveNotificationResponse: response];
    if(completionHandler){
        completionHandler();
    }
}

- (void) willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    if(completionHandler) {
        completionHandler(UNNotificationPresentationOptionNone);
    }
}

@end
