#import <Cordova/CDV.h>
#import <SwrveGeoSDK/SwrveGeoSDK.h>

@interface SwrveGeoPlugin : CDVPlugin

+ (void)initWithApiKey:(NSString *)geoApiKey;

+ (void)initWithApiKey:(NSString *)apiKey config:(SwrveGeoConfig *)config;

@end
