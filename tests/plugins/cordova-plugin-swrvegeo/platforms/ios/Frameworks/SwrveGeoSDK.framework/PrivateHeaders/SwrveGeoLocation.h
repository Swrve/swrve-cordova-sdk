#import <Foundation/Foundation.h>
#import <BDPointSDK/BDPLocationDelegate.h>
#import "SwrveGeo.h"

@class SwrveGeoManager;

@interface SwrveGeoLocation : NSObject <BDPLocationDelegate>

- (instancetype)initWithGeoManager:(SwrveGeoManager *)geoManager andLocationDelegate:(id <BDPLocationDelegate>)locationDelegate;

@end
