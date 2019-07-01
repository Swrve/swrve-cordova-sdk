#import "SwrvePlugin.h"
#import <Cordova/CDV.h>
#import <SwrveSDK/SwrveCampaign.h>
#import <SwrveSDk/SwrveCampaignStatus.h>

#define SWRVE_WRAPPER_VERSION "1.0.0"

CDVViewController *globalViewController;

BOOL resourcesListenerReady;
BOOL mustCallResourcesListener;
BOOL pushNotificationListenerReady;
NSMutableArray *pushNotificationsQueued;

@implementation SwrvePlugin

+ (void)initWithAppID:(int)appId apiKey:(NSString *)apiKey viewController:(CDVViewController *)viewController {
    [SwrvePlugin initWithAppID:appId apiKey:apiKey config:nil viewController:viewController];
}

+ (void)initWithAppID:(int)appId apiKey:(NSString *)apiKey config:(SwrveConfig *)config viewController:(CDVViewController *)viewController {
    pushNotificationsQueued = [[NSMutableArray alloc] init];
    globalViewController = viewController;
    if (config == nil) {
        config = [[SwrveConfig alloc] init];
        config.pushEnabled = YES;
    }

    // Set a resource callback
    config.resourcesUpdatedCallback = ^() {
        if (resourcesListenerReady) {
            NSDictionary* userResources = [[SwrveSDK resourceManager] resources];
            [SwrvePlugin resourcesListenerCall:userResources];
        } else {
            mustCallResourcesListener = YES;
        }
    };
    [SwrveSDK sharedInstanceWithAppID:appId apiKey:apiKey config:config];

    // Send the wrapper version at init
    [SwrveSDK userUpdate:[[NSDictionary alloc] initWithObjectsAndKeys:@SWRVE_WRAPPER_VERSION, @"swrve.cordova_plugin_version", nil]];
}

+ (void) evaluateString:(NSString*)jsString onWebView:(UIView*)webView
{
    if ([webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        [webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsString waitUntilDone:NO];
    } else {
        [webView performSelectorOnMainThread:@selector(evaluateJavaScript:completionHandler:) withObject:jsString waitUntilDone:NO];
    }
}

+ (NSString*)base64Encode:(NSData*)data
{
    NSString* currentVersion = [[UIDevice currentDevice] systemVersion];
    if ([currentVersion compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
        return [data base64EncodedStringWithOptions:0];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [data base64Encoding];
#pragma clang diagnostic pop
}

+ (BOOL)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo withBackgroundCompletionHandler:(void (^)(UIBackgroundFetchResult, NSDictionary *))completionHandler {
    UIApplicationState swrveState = [application applicationState];
    if (swrveState == UIApplicationStateInactive || swrveState == UIApplicationStateBackground) {
        return [SwrvePlugin didReceiveRemoteNotification:userInfo withBackgroundCompletionHandler:completionHandler];
    } else {
        return false;
    }
}

+ (void)notifySwrvePluginOfRemoteNotification:(NSString*)base64Json
{
    [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveProcessPushNotification !== undefined) { window.swrveProcessPushNotification('%@'); }", base64Json] onWebView:globalViewController.webView];
}

+ (BOOL)didReceiveRemoteNotification:(NSDictionary *)userInfo withBackgroundCompletionHandler:(void (^)(UIBackgroundFetchResult, NSDictionary *))completionHandler {
    BOOL handled = [SwrveSDK didReceiveRemoteNotification:userInfo withBackgroundCompletionHandler:completionHandler];

    // Notify the Swrve JS plugin of this remote notification
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo options:0 error:&error];
    if (!jsonData) {
        NSLog(@"Could not serialize remote push notification payload: %@", error);
    } else {
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *base64Json = [SwrvePlugin base64Encode:jsonData];
        if (pushNotificationListenerReady) {
            [SwrvePlugin notifySwrvePluginOfRemoteNotification:base64Json];
        } else {
            @synchronized(pushNotificationsQueued) {
                [pushNotificationsQueued addObject:base64Json];
            }
        }
    }
    return handled;
}

- (void)event:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* eventName = [command.arguments objectAtIndex:0];

    if (eventName != nil) {
        if ([command.arguments count] == 2) {
            NSDictionary* payload = [command.arguments objectAtIndex:1];
            [SwrveSDK event:eventName payload:payload];
        } else {
            [SwrveSDK event:eventName];
        }
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Event name was null"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)userUpdate:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSDictionary* attributes = [command.arguments objectAtIndex:0];

    if (attributes != nil) {
        [SwrveSDK userUpdate:attributes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Attributes were null"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)userUpdateDate:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    if ([command.arguments count] == 2) {
        NSString* propertyName = [command.arguments objectAtIndex:0];
        NSString* propertyValueRaw = [command.arguments objectAtIndex:1];

        // Parse date coming in (for example "2016-12-02T15:39:47.608Z")
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";

        NSDate* propertyValue = [dateFormatter dateFromString:propertyValueRaw];
        if (propertyValue != nil) {
            [SwrveSDK userUpdate:propertyName withDate:propertyValue];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not parse date"];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough args"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)currencyGiven:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    if ([command.arguments count] == 2) {
        NSString* currencyName = [command.arguments objectAtIndex:0];
        NSNumber* amount = [command.arguments objectAtIndex:1];

        [SwrveSDK currencyGiven:currencyName givenAmount:[amount doubleValue]];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough args"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)purchase:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    if ([command.arguments count] == 4) {
        NSString* itemName = [command.arguments objectAtIndex:0];
        NSString* currencyName = [command.arguments objectAtIndex:1];
        NSNumber* quantity = [command.arguments objectAtIndex:2];
        NSNumber* cost = [command.arguments objectAtIndex:3];

        [SwrveSDK purchaseItem:itemName currency:currencyName cost:[cost intValue] quantity:[quantity intValue]];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough args"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)unvalidatedIap:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    if ([command.arguments count] == 4) {
        NSNumber* localCost = [command.arguments objectAtIndex:0];
        NSString* localCurrency = [command.arguments objectAtIndex:1];
        NSString* productId = [command.arguments objectAtIndex:2];
        NSNumber* quantity = [command.arguments objectAtIndex:3];

        [SwrveSDK unvalidatedIap:nil localCost:[localCost doubleValue] localCurrency:localCurrency productId:productId productIdQuantity:[quantity intValue]];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough args"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)sendEvents:(CDVInvokedUrlCommand *)command
{
    @try {
        [SwrveSDK sendQueuedEvents];

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

    @catch ( NSException *e ) {
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
}

- (void)getUserResources:(CDVInvokedUrlCommand *)command
{
    NSDictionary* userResourcesDic = [[SwrveSDK resourceManager] resources];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userResourcesDic];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getUserResourcesDiff:(CDVInvokedUrlCommand *)command
{
    [SwrveSDK userResourcesDiff:^(NSDictionary *oldResourcesValues, NSDictionary *newResourcesValues, NSString *resourcesAsJSON) {
        NSMutableDictionary* resourcesDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:newResourcesValues, @"new", oldResourcesValues, @"old", nil];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resourcesDictionary];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)refreshCampaignsAndResources:(CDVInvokedUrlCommand *)command
{
    [SwrveSDK refreshCampaignsAndResources];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getMessageCenterCampaigns:(CDVInvokedUrlCommand *)command
{
    NSArray<SwrveCampaign *> *campaigns = [[SwrveSDK messaging] messageCenterCampaigns];
    NSMutableArray *messageAsArray = [[NSMutableArray alloc] init];
    
    for (SwrveCampaign *campaign in campaigns) {
        NSMutableDictionary *campaignDictionary = [[NSMutableDictionary alloc] init];
        [campaignDictionary setValue:[NSNumber numberWithUnsignedInteger:[campaign ID]] forKey:@"ID"];
        [campaignDictionary setValue:[NSNumber numberWithUnsignedInteger:[campaign maxImpressions]] forKey:@"maxImpressions"];
        [campaignDictionary setValue:[campaign subject] forKey:@"subject"];
        [campaignDictionary setValue:[NSNumber numberWithUnsignedInteger:[[campaign dateStart] timeIntervalSince1970]] forKey:@"dateStart"];
        [campaignDictionary setValue:@([campaign messageCenter]) forKey:@"messageCenter"];
        
        NSMutableDictionary *stateDictionary = [NSMutableDictionary dictionaryWithDictionary:[[campaign state] asDictionary]];
        
        // Remove unused ID
        [stateDictionary removeObjectForKey:@"ID"];
        
        // convert the status to a readable format so its consistent across both platforms
        NSUInteger statusNumber = [[stateDictionary objectForKey:@"status"] integerValue];
        [stateDictionary setObject:[self translateCampaignStatus:statusNumber] forKey:@"status"];
        [campaignDictionary setObject:stateDictionary forKey:@"state"];
        [messageAsArray addObject:campaignDictionary];
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:messageAsArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *) translateCampaignStatus:(NSUInteger) status {
    switch (status){
        case SWRVE_CAMPAIGN_STATUS_UNSEEN:
            return @"Unseen";
            break;
        case SWRVE_CAMPAIGN_STATUS_SEEN:
            return @"Seen";
            break;
        case SWRVE_CAMPAIGN_STATUS_DELETED:
            return @"Deleted";
            break;
        default:
            return @"Unseen";
    }
}

- (void)showMessageCenterCampaign:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    if ([command.arguments count] == 1) {
        NSNumber* identifier = [command.arguments objectAtIndex:0];
        
        NSArray<SwrveCampaign *> *campaigns = [[SwrveSDK messaging] messageCenterCampaigns];
        
        SwrveCampaign *canditiate;
        
        for (SwrveCampaign *campaign in campaigns) {
            if ([campaign ID] == [identifier unsignedIntegerValue]) {
                canditiate = campaign;
            }
        }
        
        if(canditiate){
            [[SwrveSDK messaging] showMessageCenterCampaign:canditiate];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No campaign with ID: %@ found.", identifier]];
        }
        
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)removeMessageCenterCampaign:(CDVInvokedUrlCommand*)command 
{
    CDVPluginResult* pluginResult = nil;
    if ([command.arguments count] == 1) {
        NSNumber* identifier = [command.arguments objectAtIndex:0];
        
        NSArray<SwrveCampaign *> *campaigns = [[SwrveSDK messaging] messageCenterCampaigns];
        
        SwrveCampaign *canditiate;
        
        for (SwrveCampaign *campaign in campaigns) {
            if ([campaign ID] == [identifier unsignedIntegerValue]) {
                canditiate = campaign;
            }
        }
        
        if(canditiate){
            [[SwrveSDK messaging] removeMessageCenterCampaign:canditiate];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No campaign with ID: %@ found.", identifier]];
        }
        
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)resourcesListenerReady:(CDVInvokedUrlCommand *)command
{
    resourcesListenerReady = YES;
    if (mustCallResourcesListener) {
        NSDictionary* userResources = [[SwrveSDK resourceManager] resources];
        [SwrvePlugin resourcesListenerCall:userResources];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

+(void)resourcesListenerCall:(NSDictionary*)userResources
{
    // Notify the Swrve JS plugin of the lates user resources
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userResources options:0 error:&error];
    if (!jsonData) {
        NSLog(@"Could not serialize latest user resources: %@", error);
    } else {
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *base64Json = [SwrvePlugin base64Encode:jsonData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveProcessResourcesUpdated !== undefined) { swrveProcessResourcesUpdated('%@'); }", base64Json] onWebView:globalViewController.webView];
        });
    }
}

- (void)pushNotificationListenerReady:(CDVInvokedUrlCommand *)command
{
    pushNotificationListenerReady = YES;
    // Send queued notifications, if any
    @synchronized(pushNotificationsQueued) {
        if ([pushNotificationsQueued count] > 0) {
            for(NSString* push64Payload in pushNotificationsQueued) {
                [SwrvePlugin notifySwrvePluginOfRemoteNotification:push64Payload];
            }
            [pushNotificationsQueued removeAllObjects];
        }
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)customButtonListenerReady:(CDVInvokedUrlCommand *)command
{
    // Notify the Swrve JS plugin of the IAM custom button click
    [SwrveSDK messaging].customButtonCallback = ^(NSString* action) {
        [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveCustomButtonListener !== undefined) { window.swrveCustomButtonListener('%@'); }", action] onWebView:globalViewController.webView];
    };

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getUserId:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[SwrveSDK userID]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
