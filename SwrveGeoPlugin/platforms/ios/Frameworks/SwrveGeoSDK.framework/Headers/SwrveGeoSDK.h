#import <Foundation/Foundation.h>
#import <BDPointSDK/BDPointSDK.h>
#import "SwrveGeoConfig.h"
#import "SwrveGeo.h"

@interface SwrveGeoSDK : NSObject

/*! Creates and initializes the SwrveGeoSDK.
 *
 * Call this directly after SwrveSDK.sharedInstanceWithAppID
 *
 * \param apiKey The secret token for your app supplied by Swrve.
 * \returns SwrveGeo singleton instance.
 */
+ (SwrveGeo *)initWithApiKey:(NSString *)apiKey;

/*! Creates and initializes the SwrveGeoSDK.
 *
 * Call this directly after SwrveSDK.sharedInstanceWithAppID
 *
 * \param apiKey The secret token for your app supplied by Swrve.
 * \param config Optional configurations.
 * \returns SwrveGeo singleton instance.
 */
+ (SwrveGeo *)initWithApiKey:(NSString *)apiKey
                      config:(SwrveGeoConfig *)config;

/*! Start the SwrveGeoSDK when SwrveGeoConfig delayStart is YES.
 *
 * Call this only when you have configured the SwrveGeoConfig delayStart to YES. The permissions dialog will be shown
 * the first time this is called and thereafter calling this will have no affect. This will allow you to choose an
 * opportune time to show the permissions dialog to the user.
 */
+ (void)start;

/*! Stop the SwrveGeoSDK.
 */
+ (void)stop;

/*! Return the SwrveGeoSDK version.
 * \returns The version string.
 */
+ (NSString *)version;

@end
