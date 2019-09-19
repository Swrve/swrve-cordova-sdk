#import "SwrveGeoPlugin.h"
#import <Cordova/CDV.h>
#import <SwrveGeoSDK/SwrveGeoSDK.h>

NSMutableArray *geoNotificationsQueued;

@implementation SwrveGeoPlugin

+ (void)initWithApiKey:(NSString *)geoApiKey {
    [SwrveGeoSDK initWithApiKey:geoApiKey];
}

+ (void)initWithApiKey:(NSString *)apiKey config:(SwrveGeoConfig *)config {
    [SwrveGeoSDK initWithApiKey:apiKey config:config];
}

- (void)start:(CDVInvokedUrlCommand *)command {
    @try {
        [SwrveGeoSDK start];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    @catch (NSException *e) {
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
}

- (void)stop:(CDVInvokedUrlCommand *)command {
    @try {
        [SwrveGeoSDK stop];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    @catch (NSException *e) {
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
}

@end

