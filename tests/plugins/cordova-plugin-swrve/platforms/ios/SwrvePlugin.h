#import <Cordova/CDV.h>
#import <SwrveSDK/SwrveSDK.h>

@interface SwrvePlugin : CDVPlugin

+ (void)initWithAppID:(int)appId apiKey:(NSString *)apiKey viewController:(CDVViewController *)viewController;
+ (void)initWithAppID:(int)appId apiKey:(NSString *)apiKey config:(SwrveConfig *)config viewController:(CDVViewController *)viewController;
+ (void)didReceiveNotificationResponse:(UNNotificationResponse *)response;
+ (BOOL)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo withBackgroundCompletionHandler:(void (^)(UIBackgroundFetchResult, NSDictionary *))completionHandler API_AVAILABLE(ios(7.0));

- (void)event:(CDVInvokedUrlCommand *)command;
- (void)userUpdate:(CDVInvokedUrlCommand *)command;
- (void)userUpdateDate:(CDVInvokedUrlCommand *)command;
- (void)currencyGiven:(CDVInvokedUrlCommand *)command;
- (void)purchase:(CDVInvokedUrlCommand *)command;
- (void)unvalidatedIap:(CDVInvokedUrlCommand *)command;
- (void)sendEvents:(CDVInvokedUrlCommand *)command;
- (void)getUserResources:(CDVInvokedUrlCommand *)command;
- (void)getUserResourcesDiff:(CDVInvokedUrlCommand *)command;
- (void)refreshCampaignsAndResources:(CDVInvokedUrlCommand *)command;
- (void)getMessageCenterCampaigns:(CDVInvokedUrlCommand *)command;
- (void)showMessageCenterCampaign:(CDVInvokedUrlCommand *)command;
- (void)removeMessageCenterCampaign:(CDVInvokedUrlCommand *)command;

- (void)getUserId:(CDVInvokedUrlCommand *)command;
- (void)getExternalUserId:(CDVInvokedUrlCommand *)command;
- (void)identify:(CDVInvokedUrlCommand *)command;

@end
