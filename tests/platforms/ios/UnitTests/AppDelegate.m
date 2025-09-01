#import "AppDelegate.h"
#import "SwrvePlugin.h"
#import "MainViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self.viewController = [[MainViewController alloc] init];
      
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    BOOL handled = [SwrvePlugin application:application didReceiveRemoteNotification:userInfo withBackgroundCompletionHandler:^ (UIBackgroundFetchResult fetchResult, NSDictionary *swrvePayload) {
        // NOTE: Do not call the Swrve SDK from this context
        // Your code here to process a Swrve remote push and payload
        completionHandler(fetchResult);
    }];
    if (!handled) {
        // Your code here, it is either a non-background push received in the background or a non-Swrve remote push
        // You’ll have to process the payload on your own and call the completionHandler as normal
    }
}

@end
