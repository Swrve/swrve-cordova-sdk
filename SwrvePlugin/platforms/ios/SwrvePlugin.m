#import "SwrvePlugin.h"
#import "SwrvePluginPushHandler.h"
#import <Cordova/CDV.h>
#import <SwrveSDK/SwrveCampaign.h>
#import <SwrveSDk/SwrveCampaignStatus.h>

#define SWRVE_WRAPPER_VERSION "4.0.0"

CDVViewController *globalViewController;

NSString *const SwrveSilentPushPayloadKey = @"_s.SilentPayload";
BOOL resourcesListenerReady;
BOOL mustCallResourcesListener;
BOOL pushNotificationListenerReady;
BOOL silentPushNotificationListenerReady;
NSMutableArray *pushNotificationsQueued;
NSMutableArray *silentPushNotificationsQueued;
SwrvePluginPushHandler *swrvePushHandler;

@implementation SwrvePlugin

+ (void)initWithAppID:(int)appId apiKey:(NSString *)apiKey viewController:(CDVViewController *)viewController {
    [SwrvePlugin initWithAppID:appId apiKey:apiKey config:nil viewController:viewController];
}

+ (void)initWithAppID:(int)appId apiKey:(NSString *)apiKey config:(SwrveConfig *)config viewController:(CDVViewController *)viewController {
    pushNotificationsQueued = [[NSMutableArray alloc] init];
    silentPushNotificationsQueued = [[NSMutableArray alloc] init];
    globalViewController = viewController;
    if (config == nil) {
        config = [[SwrveConfig alloc] init];
        config.pushEnabled = YES;
    }

    // if the pushResponseDelegate is already set, don't override
    if(config.pushResponseDelegate == nil){
        swrvePushHandler = [[SwrvePluginPushHandler alloc] init];
        config.pushResponseDelegate = swrvePushHandler;
    }
    
    // Apply Essential InApp and Embedded config
    SwrveInAppMessageConfig *inAppConfig = config.inAppMessageConfig;
    SwrveEmbeddedMessageConfig *embeddedConfig = config.embeddedMessageConfig;
    
    inAppConfig.dismissButtonCallback = ^(NSString *campaignSubject, NSString *buttonName){
        [SwrvePlugin dismissButtonPressed:campaignSubject withButtonName:buttonName];
    };
    
    inAppConfig.clipboardButtonCallback = ^(NSString *processedText) {
        [SwrvePlugin clipboardButtonPressed:processedText];
    };
    
    inAppConfig.customButtonCallback = ^(NSString *action) {
        [SwrvePlugin customButtonPressed:action];
    };
        
    embeddedConfig.embeddedMessageCallbackWithPersonalization = ^(SwrveEmbeddedMessage *message, NSDictionary *personalizationProperties) {
        [SwrvePlugin embeddedCallback:message withPersonalization:personalizationProperties];
    };
    
    config.embeddedMessageConfig = embeddedConfig;
    config.inAppMessageConfig = inAppConfig;
    
    // Set a resource callback
    config.resourcesUpdatedCallback = ^() {
        if (resourcesListenerReady) {
            NSDictionary *userResources = [[SwrveSDK resourceManager] resources];
            [SwrvePlugin resourcesListenerCall:userResources];
        } else {
            mustCallResourcesListener = YES;
        }
    };
    [SwrveSDK sharedInstanceWithAppID:appId apiKey:apiKey config:config];

    [SwrvePlugin sendPluginVersion];
}

+ (void)evaluateString:(NSString *)jsString onWebView:(UIView *)webView {
    if ([webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
    } else {
        [globalViewController.commandDelegate evalJs:jsString];
    }
}

+ (NSString *)base64Encode:(NSData *)data {
    NSString *currentVersion = [[UIDevice currentDevice] systemVersion];
    if ([currentVersion compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
        return [data base64EncodedStringWithOptions:0];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [data base64Encoding];
#pragma clang diagnostic pop
}

+ (void)sendPluginVersion {
    if([SwrveSDK started]){
        [SwrveSDK userUpdate:[[NSDictionary alloc] initWithObjectsAndKeys:@SWRVE_WRAPPER_VERSION, @"swrve.cordova_plugin_version", nil]];
        [SwrveSDK sendQueuedEvents];
    }
}

// Entry point from SwrvePluginPushHandler
+ (void) didReceiveNotificationResponse:(UNNotificationResponse *)response {
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    if (userInfo) {
        NSString *base64Json = [SwrvePlugin serializeDicToJson:userInfo withKey:nil];
        if (base64Json) {
            if (pushNotificationListenerReady) {
                [SwrvePlugin notifySwrvePluginOfPushNotification:base64Json];
            } else {
                @synchronized(pushNotificationsQueued) {
                    [pushNotificationsQueued addObject:base64Json];
                }
            }
        }
    }
}

// Entry point from AppDelegate
+ (BOOL)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo withBackgroundCompletionHandler:(void (^)(UIBackgroundFetchResult, NSDictionary *))completionHandler {

    BOOL handled = [SwrveSDK didReceiveRemoteNotification:userInfo withBackgroundCompletionHandler:completionHandler];
    if (handled) {
        if ([userInfo objectForKey:SwrveSilentPushPayloadKey]) {
            NSString *base64Json = [SwrvePlugin serializeDicToJson:userInfo withKey:SwrveSilentPushPayloadKey];
            if (base64Json) {
                if (silentPushNotificationListenerReady) {
                    [SwrvePlugin notifySwrvePluginOfSilentPushNotification:base64Json];
                } else {
                    @synchronized(silentPushNotificationsQueued) {
                        [silentPushNotificationsQueued addObject:base64Json];
                    }
                }
            }
        } else {
            /** Legacy iOS Push Handling - to be deprecated soon **/
            NSString *base64Json = [SwrvePlugin serializeDicToJson:userInfo withKey:nil];
            if (base64Json) {
                if (pushNotificationListenerReady) {
                    [SwrvePlugin notifySwrvePluginOfPushNotification:base64Json];
                } else {
                    @synchronized(pushNotificationsQueued) {
                        [pushNotificationsQueued addObject:base64Json];
                    }
                }
            }
        }
    }
    return handled;
}

+ (void)handleDeeplink:(NSURL *)url {
    [SwrveSDK handleDeeplink:url];
}

+ (void)handleDeferredDeeplink:(NSURL *)url {
    [SwrveSDK handleDeferredDeeplink:url];
}

+ (void)installAction:(NSURL *)url {
    [SwrveSDK installAction:url];
}

+ (void)notifySwrvePluginOfPushNotification:(NSString *)base64Json {
    [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveProcessPushNotification !== undefined) { window.swrveProcessPushNotification('%@'); }", base64Json] onWebView:globalViewController.webView];
}

+ (void)notifySwrvePluginOfSilentPushNotification:(NSString *)base64Json {
    [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveProcessSilentPushNotification !== undefined) { window.swrveProcessSilentPushNotification('%@'); }", base64Json] onWebView:globalViewController.webView];
}

// Serrialize an entire dictionary or serrialize a key in the dic.
// This method is used to serrialize the just the "SwrveSilentPushPayloadKey" payload content.
// So we return to JS layer just the expected payload to our custumer.
+ (NSString *)serializeDicToJson:(NSDictionary *)dic withKey:(NSString *) key {
    NSError *error;
    NSData *jsonData;
    if (key != nil) {
        jsonData = [NSJSONSerialization dataWithJSONObject:[dic objectForKey:key] options:0 error:&error];
    } else {
        jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&error];
    }

    if (!jsonData) {
        NSLog(@"Could not serialize remote push notification payload: %@", error);
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    return [SwrvePlugin base64Encode:jsonData];
}

- (void)event:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    NSString *eventName = [command.arguments objectAtIndex:0];

    if (eventName != nil) {
        if ([command.arguments count] == 2) {
            NSDictionary *payload = [command.arguments objectAtIndex:1];
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

- (void)userUpdate:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    NSDictionary *attributes = [command.arguments objectAtIndex:0];

    if (attributes != nil) {
        [SwrveSDK userUpdate:attributes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Attibutes cannot be null"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)userUpdateDate:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 2) {
        NSString *propertyName = [command.arguments objectAtIndex:0];
        NSString *propertyValueRaw = [command.arguments objectAtIndex:1];

        // Parse date coming in (for example "2016-12-02T15:39:47.608Z")
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";

        NSDate *propertyValue = [dateFormatter dateFromString:propertyValueRaw];
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

- (void)currencyGiven:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 2) {
        NSString *currencyName = [command.arguments objectAtIndex:0];
        NSNumber *amount = [command.arguments objectAtIndex:1];

        [SwrveSDK currencyGiven:currencyName givenAmount:[amount doubleValue]];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough args"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)purchase:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 4) {
        NSString *itemName = [command.arguments objectAtIndex:0];
        NSString *currencyName = [command.arguments objectAtIndex:1];
        NSNumber *quantity = [command.arguments objectAtIndex:2];
        NSNumber *cost = [command.arguments objectAtIndex:3];

        [SwrveSDK purchaseItem:itemName currency:currencyName cost:[cost intValue] quantity:[quantity intValue]];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough args"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)unvalidatedIap:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    if (([command.arguments count] == 4) || ([command.arguments count] == 5)) {

        SwrveIAPRewards *reward = nil;
        NSNumber *localCost = [command.arguments objectAtIndex:0];
        NSString *localCurrency = [command.arguments objectAtIndex:1];
        NSString *productId = [command.arguments objectAtIndex:2];
        NSNumber *quantity = [command.arguments objectAtIndex:3];

        if([command.arguments count] == 5) {
            // since we could potentially have a reward, convert it for sending up
            NSDictionary *rewardsDict = [command.arguments objectAtIndex:4];
            reward = [[SwrveIAPRewards alloc] init];

            NSArray *items = [rewardsDict objectForKey:@"items"];

            if(items != nil && [items count] != 0) {
                for (NSDictionary *item in items) {
                    [reward addItem:[item objectForKey:@"name"] withQuantity:[[item objectForKey:@"amount"] longValue]];
                }
            }

            NSArray *currencies = [rewardsDict objectForKey:@"currencies"];

            if(currencies != nil && [currencies count] != 0) {
                for (NSDictionary *currency in currencies) {
                    [reward addCurrency:[currency objectForKey:@"name"] withAmount:[[currency objectForKey:@"amount"] longValue]];
                }
            }
        }

        [SwrveSDK unvalidatedIap:reward localCost:[localCost doubleValue] localCurrency:localCurrency productId:productId productIdQuantity:[quantity intValue]];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough args"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)sendEvents:(CDVInvokedUrlCommand *)command {
    @try {
        [SwrveSDK sendQueuedEvents];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

    @catch (NSException *e) {
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
}

- (void)getUserResources:(CDVInvokedUrlCommand *)command {
    [SwrveSDK userResources:^(NSDictionary *resources, NSString *resourcesAsJSON) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resources];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getUserResourcesDiff:(CDVInvokedUrlCommand *)command {
    [SwrveSDK userResourcesDiff:^(NSDictionary *oldResourcesValues, NSDictionary *newResourcesValues, NSString *resourcesAsJSON) {
        NSMutableDictionary *resourcesDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:newResourcesValues, @"new", oldResourcesValues, @"old", nil];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resourcesDictionary];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)refreshCampaignsAndResources:(CDVInvokedUrlCommand *)command {
    [SwrveSDK refreshCampaignsAndResources];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getMessageCenterCampaigns:(CDVInvokedUrlCommand *)command {
    NSArray<SwrveCampaign *> *campaigns = [SwrveSDK messageCenterCampaigns];
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

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:messageAsArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)translateCampaignStatus:(NSUInteger) status {
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

- (void)showMessageCenterCampaign:(CDVInvokedUrlCommand *) command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 1) {
        NSNumber *identifier = [command.arguments objectAtIndex:0];
        NSArray<SwrveCampaign *> *campaigns = [SwrveSDK messageCenterCampaigns];
        SwrveCampaign *candidate;

        for (SwrveCampaign *campaign in campaigns) {
            if ([campaign ID] == [identifier unsignedIntegerValue]) {
                candidate = campaign;
            }
        }

        if (candidate) {
            [SwrveSDK showMessageCenterCampaign:candidate];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No campaign with ID: %@ found.", identifier]];
        }

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)removeMessageCenterCampaign:(CDVInvokedUrlCommand *) command  {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 1) {
        NSNumber *identifier = [command.arguments objectAtIndex:0];
        NSArray<SwrveCampaign *> *campaigns = [SwrveSDK messageCenterCampaigns];
        SwrveCampaign *candidate;

        for (SwrveCampaign *campaign in campaigns) {
            if ([campaign ID] == [identifier unsignedIntegerValue]) {
                candidate = campaign;
            }
        }

        if (candidate){
            [SwrveSDK removeMessageCenterCampaign:candidate];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No campaign with ID: %@ found.", identifier]];
        }

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)markMessageCenterCampaignAsSeen:(CDVInvokedUrlCommand *) command  {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 1) {
        NSNumber *identifier = [command.arguments objectAtIndex:0];
        NSArray<SwrveCampaign *> *campaigns = [SwrveSDK messageCenterCampaigns];
        SwrveCampaign *candidate;

        for (SwrveCampaign *campaign in campaigns) {
            if ([campaign ID] == [identifier unsignedIntegerValue]) {
                candidate = campaign;
            }
        }

        if (candidate){
            [SwrveSDK markMessageCenterCampaignAsSeen:candidate];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No campaign with ID: %@ found.", identifier]];
        }

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)resourcesListenerReady:(CDVInvokedUrlCommand *)command {
    resourcesListenerReady = YES;
    if (mustCallResourcesListener) {
        NSDictionary *userResources = [[SwrveSDK resourceManager] resources];
        [SwrvePlugin resourcesListenerCall:userResources];
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

+ (void)resourcesListenerCall:(NSDictionary *)userResources {
    // Notify the Swrve JS plugin of the lates user resources
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userResources options:0 error:&error];
    if (!jsonData) {
        NSLog(@"Could not serialize latest user resources: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *base64Json = [SwrvePlugin base64Encode:jsonData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveProcessResourcesUpdated !== undefined) { swrveProcessResourcesUpdated('%@'); }", base64Json] onWebView:globalViewController.webView];
        });
    }
}

+ (void) embeddedCallback:(SwrveEmbeddedMessage *) embeddedMessage withPersonalization:(NSDictionary *) personalizationProperties {
    NSMutableDictionary *callback = [NSMutableDictionary new];
    if (embeddedMessage != nil) {
        NSMutableDictionary *message = [NSMutableDictionary new];
        [message setObject:embeddedMessage.buttons forKey:@"buttons"];
        NSString *embeddedType = (embeddedMessage.type == kSwrveEmbeddedDataTypeJson) ? @"json" : @"other";
        [message setObject:embeddedType forKey:@"type"];
        
        NSString *dataObject = [embeddedMessage.data stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        [message setObject:dataObject forKey:@"data"];
        
        [message setObject:embeddedMessage.messageID forKey:@"messageID"];
        [message setObject:[NSNumber numberWithUnsignedInteger:embeddedMessage.campaign.ID] forKey:@"campaignID"];
        [callback setObject:message forKey:@"message"];
        
        if (personalizationProperties != nil) {
            [callback setObject:personalizationProperties forKey:@"personalizationProperties"];
        }
        
        // Notify the Swrve JS plugin of the embedded call
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:callback options:0 error:&error];
        if (!jsonData) {
            NSLog(@"Could not serialize the embedded mesage %@", error);
        } else {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            dispatch_async(dispatch_get_main_queue(), ^{
                [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveEmbeddedMessageCallback !== undefined) { swrveEmbeddedMessageCallback('%@'); }", jsonString] onWebView:globalViewController.webView];
            });
        }
    }
}

+ (void) dismissButtonPressed:(NSString *)campaignSubject withButtonName:(NSString *) buttonName {
    // Check what are the available infos from our callback to return to JS layer.
    NSMutableDictionary *callback = [NSMutableDictionary new];
    if (campaignSubject != nil && ![campaignSubject isEqualToString:@""]) {
        [callback setObject:campaignSubject forKey:@"campaignSubject"];
    }
    if (buttonName != nil && ![buttonName isEqualToString:@""]) {
        [callback setObject:buttonName forKey:@"buttonName"];
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:callback options:0 error:&error];
    if (!jsonData) {
        NSLog(@"Could not serialize callback from Dismiss Button: %@", error);
    } else {
        // Notify the Swrve JS plugin of the dismiss button click
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveDismissButtonListener !== undefined) { window.swrveDismissButtonListener('%@'); }", jsonString] onWebView:globalViewController.webView];
    }
}

+ (void) customButtonPressed:(NSString *) action {
    [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveCustomButtonListener !== undefined) { window.swrveCustomButtonListener('%@'); }", action] onWebView:globalViewController.webView];
}

+ (void) clipboardButtonPressed:(NSString *) processedText {
    [SwrvePlugin evaluateString:[NSString stringWithFormat:@"if (window.swrveClipboardButtonListener !== undefined) { window.swrveClipboardButtonListener('%@'); }", processedText] onWebView:globalViewController.webView];
}

- (void)pushNotificationListenerReady:(CDVInvokedUrlCommand *)command {
    pushNotificationListenerReady = YES;
    // Send queued notifications, if any
    @synchronized(pushNotificationsQueued) {
        if ([pushNotificationsQueued count] > 0) {
            for(NSString *push64Payload in pushNotificationsQueued) {
                [SwrvePlugin notifySwrvePluginOfPushNotification:push64Payload];
            }
            [pushNotificationsQueued removeAllObjects];
        }
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)silentPushNotificationListenerReady:(CDVInvokedUrlCommand *)command {
    silentPushNotificationListenerReady = YES;
    // Send queued notifications, if any
    @synchronized(silentPushNotificationsQueued) {
        if ([silentPushNotificationsQueued count] > 0) {
            for(NSString *silentPush64Payload in silentPushNotificationsQueued) {
                [SwrvePlugin notifySwrvePluginOfSilentPushNotification:silentPush64Payload];
            }
            [silentPushNotificationsQueued removeAllObjects];
        }
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)customButtonListenerReady:(CDVInvokedUrlCommand *)command {

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setCustomPayloadForConversationInput:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    NSMutableDictionary *customPayload = [command.arguments objectAtIndex:0];
    if ([command.arguments count] == 1) {
        if (customPayload == nil || [customPayload isKindOfClass:[NSNull class]]) {
            [SwrveSDK setCustomPayloadForConversationInput:[NSMutableDictionary new]];
        } else {
            [SwrveSDK setCustomPayloadForConversationInput:customPayload];
        }
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Its necessary to provide at least 1 parameter."];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)dismissButtonListenerReady:(CDVInvokedUrlCommand *)command {
    // no longer need to register anything. the callback will work
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)clipboardButtonListenerReady:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getUserId:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[SwrveSDK userID]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getApiKey:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[SwrveSDK apiKey]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getExternalUserId:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[SwrveSDK externalUserId]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)identify:(CDVInvokedUrlCommand *)command {
    __block CDVPluginResult *pluginResult;
    if ([command.arguments count] == 1) {
        NSString *externalUserId = [command.arguments objectAtIndex:0];
        [SwrveSDK identify:externalUserId onSuccess:^(NSString * _Nonnull status, NSString * _Nonnull swrveUserId) {
            NSDictionary *identifySuccess = @{
                                     @"status": status,
                                     @"swrveId": swrveUserId,
                                     };

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:identifySuccess];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(NSInteger httpCode, NSString * _Nonnull errorMessage) {
            NSDictionary *identifyError = @{
                                     // returning the "httpCode" as responseCode for consistent for both platforms iOS/Android.
                                     @"responseCode": [NSNumber numberWithInteger:httpCode],
                                     @"errorMessage": errorMessage,
                                     };
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:identifyError];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)start:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 1) {
        NSString *userId = [command.arguments objectAtIndex:0];
        if (userId != nil && ![userId isEqualToString:@""])  {
            [SwrveSDK startWithUserId:userId];
            // Need to use dispatch_after or SDK will not be ready to send.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [SwrvePlugin sendPluginVersion];
            });
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
        }
    } else {
        [SwrveSDK start];
        // Need to use dispatch_after or SDK will not be ready to send.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [SwrvePlugin sendPluginVersion];
        });
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isStarted:(CDVInvokedUrlCommand *)command {
    NSString *isStartedString = [SwrveSDK started] ? @"true" : @"false";
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:isStartedString];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - embedded

- (void)embeddedMessageWasShownToUser:(CDVInvokedUrlCommand *) command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 1) {
        NSNumber *embeddedCampaignId = [command.arguments objectAtIndex:0];
        SwrveEmbeddedCampaign *embeddedCampaign = [self findEmbeddedCampaignByID:[embeddedCampaignId integerValue]];
        if (embeddedCampaign) {
            // Parse embedded into an actual object
            [SwrveSDK embeddedMessageWasShownToUser:[embeddedCampaign message]];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No embedded campaign with ID: %@ found.", embeddedCampaignId]];
        }

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)embeddedMessageButtonWasPressed:(CDVInvokedUrlCommand *) command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 2) {
        NSNumber *embeddedCampaignId = [command.arguments objectAtIndex:0];
        NSString *embeddedButtonId = [command.arguments objectAtIndex:1];
        
        SwrveEmbeddedCampaign *embeddedCampaign = [self findEmbeddedCampaignByID:[embeddedCampaignId integerValue]];
        if (embeddedCampaign && embeddedButtonId) {
            // Parse embedded into an actual object
            [SwrveSDK embeddedButtonWasPressed:[embeddedCampaign message] buttonName:embeddedButtonId];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No embedded campaign with ID: %@ found.", embeddedCampaignId]];
        }

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getPersonalizedEmbeddedMessageData: (CDVInvokedUrlCommand *) command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 2) {
        NSNumber *embeddedCampaignId = [command.arguments objectAtIndex:0];
        NSDictionary *personalizationProperties = [command.arguments objectAtIndex:1];

        SwrveEmbeddedCampaign *embeddedCampaign = [self findEmbeddedCampaignByID:[embeddedCampaignId integerValue]];
        if(embeddedCampaign) {
            NSString *textResult = [SwrveSDK personalizeEmbeddedMessageData:[embeddedCampaign message] withPersonalization:personalizationProperties];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:textResult];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
        }
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) getPersonalizedText: (CDVInvokedUrlCommand *) command {
    CDVPluginResult *pluginResult = nil;
    if ([command.arguments count] == 2) {
        NSString *text = [command.arguments objectAtIndex:0];
        NSDictionary *personalizationProperties = [command.arguments objectAtIndex:1];
                
        if(text && text.length > 0) {
            NSString *textResult = [SwrveSDK personalizeText:text withPersonalization:personalizationProperties];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:textResult];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Arguments"];
        }
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

#pragma mark - private functions

- (NSMutableDictionary *) getCache {
    NSString *userId = [[SwrveSDK sharedInstance] userID];
    NSData *dataFile = [NSData dataWithContentsOfFile:[SwrveLocalStorage campaignsFilePathForUserId:userId]];
    NSMutableDictionary *dictionary = [NSMutableDictionary new];

    if (dataFile != nil) {
        NSError *error;
        dictionary = [NSJSONSerialization JSONObjectWithData:dataFile
                                                   options:NSJSONReadingMutableContainers
                                                     error:&error];
        if (error) {
            NSLog(@"SwrvePlugin - Unable to read cache error: %@", [error localizedDescription]);
            return nil;
        }
    }
    return dictionary;
}

- (SwrveEmbeddedCampaign *) findEmbeddedCampaignByID:(NSInteger) campaignId {
    NSMutableDictionary *cache = [self getCache];
    NSArray *campaigns = [cache objectForKey:@"campaigns"];
    for (NSDictionary *campaign in campaigns)
    {
        if (campaignId == [[campaign valueForKey:@"id"] integerValue]) {
            SwrveEmbeddedCampaign *embeddedCampaign = [[SwrveEmbeddedCampaign alloc] initAtTime:[NSDate date] fromDictionary:campaign forController:nil];
            return embeddedCampaign;
        }
    }
    return nil;
}

@end
