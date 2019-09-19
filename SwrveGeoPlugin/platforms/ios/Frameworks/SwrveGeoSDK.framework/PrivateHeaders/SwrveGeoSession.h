#import <Foundation/Foundation.h>
#import <BDPointSDK/BDPSessionDelegate.h>

@interface SwrveGeoSession : NSObject <BDPSessionDelegate>

- (instancetype)initWithSessionDelegate:(id <BDPSessionDelegate>)sessionDelegate;

@end
