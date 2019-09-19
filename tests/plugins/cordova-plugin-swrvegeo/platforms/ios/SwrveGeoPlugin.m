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

@end

