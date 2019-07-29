#import "AppDelegate.h"
#import "SwrvePlugin.h"
#import "MainViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self.viewController = [[MainViewController alloc] init];
    
    /****************** SWRVE CHANGES ******************/
    // Point to local http server since this project is purely for testing purposes and prevent any calls to Swrve
    SwrveConfig *config = [[SwrveConfig alloc] init];
    config.pushEnabled = YES;
    config.eventsServer = @"http://localhost:8083";
    config.contentServer = @"http://localhost:8085";
    config.identityServer = @"http://localhost:8086";
    
    // Set your app id and api key here
    [SwrvePlugin initWithAppID:1111 apiKey:@"fake_api_key" config:config viewController:self.viewController];
    /****************** END OF CHANGES ******************/
    
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
