#import <Foundation/Foundation.h>
#import <BDPointSDK/BDPLocationDelegate.h>
#import <BDPointSDK/BDPSessionDelegate.h>
#import "SwrveGeoCustomFilterDelegate.h"

@interface SwrveGeoConfig : NSObject

/*! Configure this property to delay the init of the sdk until start is called at least once. */
@property(nonatomic) BOOL delayStart;

/*! Configure this property to receive session related callbacks */
@property(nonatomic) id <BDPSessionDelegate> sessionDelegate;

/*! Configure this property to receive location related event callbacks */
@property(nonatomic) id <BDPLocationDelegate> locationDelegate;

/*! Configure this property to filter and modify the geo notifications */
@property(nonatomic) id <SwrveGeoCustomFilterDelegate> customFilterDelegate;

@end
