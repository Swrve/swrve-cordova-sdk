#import "SwrveTestHelper.h"
#if __has_include(<OCMock/OCMock.h>)
#import <OCMock/OCMock.h>
#endif

int const waitShort = 15;
int const waitMedium = 30;
int const waitLong = 60;

@implementation SwrveTestHelper
// Wait for the condition to be true, once that happens the expectation is fulfilled. If it is not true on each delta time, it is checked again.
+ (void)waitForBlock:(float)deltaSecs conditionBlock:(BOOL (^)(void))conditionBlock expectation:(XCTestExpectation *)expectation {
    [self waitForBlock:deltaSecs conditionBlock:conditionBlock expectation:expectation checkNow:TRUE];
}

+ (void)waitForBlock:(float)deltaSecs conditionBlock:(BOOL (^)(void))conditionBlock expectation:(XCTestExpectation *)expectation checkNow:(BOOL)checkNow {
    // Check right away on first invocation
    if (checkNow) {
        if (conditionBlock()) {
            [expectation fulfill];
            return;
        }
    }
    
    // Schedule a check of the condition
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(deltaSecs * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (conditionBlock()) {
            [expectation fulfill];
        } else {
            [self waitForBlock:deltaSecs conditionBlock:conditionBlock expectation:expectation checkNow:NO];
        }
    });
}

@end
