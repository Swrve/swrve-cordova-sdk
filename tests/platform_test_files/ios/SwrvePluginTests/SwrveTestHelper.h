#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

extern int const waitShort;
extern int const waitMedium;
extern int const waitLong;

NS_ASSUME_NONNULL_BEGIN

@interface SwrveTestHelper : NSObject
+ (void)waitForBlock:(float)deltaSecs conditionBlock:(BOOL (^)(void))conditionBlock expectation:(XCTestExpectation *)expectation;

@end

NS_ASSUME_NONNULL_END
