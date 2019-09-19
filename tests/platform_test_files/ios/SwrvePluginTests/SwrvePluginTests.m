#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "SwrvePlugin.h"

#import <SwrveSDK/Swrve.h>
#import <SwrveSDK/SwrveSDK.h>
#import <SwrveSDK/SwrveCampaign.h>
#import <SwrveSDK/SwrveCampaignStatus.h>
#import <SwrveSDKCommon/SwrveSDKCommon.h>

#import "AppDelegate.h"
#import "SwrveTestHelper.h"

@interface SwrvePluginTests : XCTestCase {
    AppDelegate *appDelegate;
    CDVViewController *controller;
    id swrveMock;
}
@end

@implementation SwrvePluginTests

#pragma mark - wait / helper functions

- (void)waitForApplicationToStart:(void(^)(NSString *))callback {
    NSDate *timerStart = [NSDate date];
    NSString *pluginState = nil;
    for (int i = 0; i < waitMedium; i++) {
        pluginState = [self runJS:@"((window !== undefined && 'plugins' in window && 'swrve' in window.plugins)? 'yes' : 'no')"];
        if (pluginState != nil && ![pluginState isEqualToString:@"no"]) {
            callback(pluginState);
            break;
        } else {
            // Wait a bit more...
            NSDate *runUntil = [NSDate dateWithTimeInterval:i sinceDate:timerStart];
            [[NSRunLoop currentRunLoop] runUntilDate:runUntil];
        }
    }
}

- (void)waitForActionReceivedForJavascript:(NSString *)javascript withCallback:(void(^)(NSString *))callback {
    BOOL responseReceived = NO;
    for(int i = 0; i < waitMedium && !responseReceived; i++) {
        NSString *response = [self runJS:javascript];
        responseReceived = (response != nil && response.length > 0);
        if (!responseReceived) {
            [self waitForSeconds:1];
        }else{
            callback(response);
            break;
        }
    }
}

- (void) waitForSeconds:(int)seconds {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeInterval:seconds sinceDate:[NSDate date]]];
}

- (NSString*) runJS:(NSString*)js {
    return [((UIWebView*)controller.webView) stringByEvaluatingJavaScriptFromString:js];
}

#pragma mark - setup / teardown

- (void)setUp {
    [super setUp];
    appDelegate = [[UIApplication sharedApplication] delegate];
    controller = appDelegate.viewController;
    swrveMock = OCMPartialMock([SwrveSDK sharedInstance]);
}

- (void)tearDown {
    [super tearDown];
    [swrveMock stopMocking];
}

#pragma mark - tests

- (void)testEvents {
    OCMExpect([(Swrve*) swrveMock event:@"levelup"]).andDo(nil);
    OCMExpect([swrveMock event:@"leveldown" payload:@{@"armor": @"disabled"}]).andDo(nil);
    
    OCMExpect([(Swrve*) swrveMock userUpdate:@{@"cordova": @"TRUE"}]).andDo(nil);
    NSString *propertyValueRaw = @"2017-01-02T16:20:00.000Z";
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
    NSDate* dateValue = [dateFormatter dateFromString:propertyValueRaw];
    OCMExpect([swrveMock userUpdate:@"last_subscribed" withDate:dateValue]).andDo(nil);
    OCMExpect([swrveMock currencyGiven:@"Gold" givenAmount:12.0]).andDo(nil);
    OCMExpect([swrveMock purchaseItem:@"sword" currency:@"Gold" cost:15 quantity:2]).andDo(nil);
    OCMExpect([swrveMock unvalidatedIap:nil localCost:99.2 localCurrency:@"USD" productId:@"iap_item" productIdQuantity:15]).andDo(nil);
    OCMExpect([swrveMock sendQueuedEvents]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        // Send all instrumented events
        [self runJS:@"window.plugins.swrve.event(\"levelup\", undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date(2016, 12, 2, 16, 20, 0, 0), undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.currencyGiven(\"Gold\", 12, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.unvalidatedIap(99.2,\"USD\",\"iap_item\", 15, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.sendEvents(function(forceCallback) { window.sendEvents =\"finished\"}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.sendEvents" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"finished");
            [self->swrveMock verify];
        }];
        
        [apploaded fulfill];
    }];
    
    /// waiting for waitForApplicationToStart
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testUserResourcesAndResourcesDiff");
        }
    }];
}

- (void)testEvent {
    OCMExpect([(Swrve*) swrveMock event:@"my_event"]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.event(\"my_event\", undefined, function(forceCallback) { window.testEvent =\"success\"}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testEvent" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testEvent");
        }
    }];
}

- (void)testEventWithPayload {
    OCMExpect([swrveMock event:@"leveldown" payload:@{@"armor": @"disabled"}]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, function(forceCallback) { window.testEventPayload = `success`}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testEventPayload" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testEventWithPayload");
        }
    }];
}

- (void)testUserUpdate {
    OCMExpect([(Swrve*) swrveMock userUpdate:@{@"cordova": @"TRUE"}]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, function(forceCallback) { window.testUserUpdate = `success`}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testUserUpdate" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testUserUpdate");
        }
    }];
}

- (void)testUserUpdateDate {
    NSString *propertyValueRaw = @"2017-01-02T16:20:00.000Z";
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
    NSDate* dateValue = [dateFormatter dateFromString:propertyValueRaw];
    
    OCMExpect([swrveMock userUpdate:@"last_subscribed" withDate:dateValue]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date('2017-01-02T16:20:00'), function(forceCallback) { window.testUserUpdateDate = `success`}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testUserUpdateDate" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testUserUpdateDate");
        }
    }];
}

- (void)testCurrencyGiven {
    OCMExpect([swrveMock currencyGiven:@"Gold" givenAmount:20.0]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.currencyGiven(\"Gold\", 20, function(forceCallback) { window.testCurrencyGiven = `success`}, undefined);"];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testCurrencyGiven" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testCurrencyGiven");
        }
    }];
}

- (void)testPurchase {
    OCMExpect([swrveMock purchaseItem:@"sword" currency:@"Gold" cost:15 quantity:2]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, function(forceCallback) { window.testPurchase = `success`}, undefined);"];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testPurchase" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testPurchase");
        }
    }];
}

- (void)testIAP {
    OCMExpect([swrveMock unvalidatedIap:nil localCost:99.2 localCurrency:@"USD" productId:@"iap_item" productIdQuantity:15]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.unvalidatedIap(99.2,\"USD\",\"iap_item\", 15, function(forceCallback) { window.testIAP = `success`}, undefined);"];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testIAP" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        [apploaded fulfill];
    }];
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testIAP");
        }
    }];
}

- (void)testIAPWithReward {
    
    OCMExpect([swrveMock unvalidatedIap:[OCMArg isNotNil] localCost:88.2 localCurrency:@"EUR" productId:@"iap_item" productIdQuantity:20]).andDo(nil);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.unvalidatedIapWithReward(88.2,\"EUR\",\"iap_item\", 20, {\"items\":[{\"name\": \"reward.item.type1\", \"amount\":1}], \"currencies\":[]} , function(forceCallback) { window.testIAPWithReward = `success`}, undefined);"];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testIAPWithReward" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        [apploaded fulfill];
    }];
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testIAPWithReward");
        }
    }];
}

- (void)testUserResources {
    
    // Mock the Async callback for User Resources
    [[[swrveMock expect] andDo:^(NSInvocation *invocation) {
        
        // define the new resourceCallback
        void (^SwrveUserResourcesCallback)(NSDictionary *resources, NSString *resourcesAsJSON) = nil;
        
        // The block is the last argument that is passed into the given function
        [invocation getArgument:&SwrveUserResourcesCallback atIndex:[[invocation methodSignature]numberOfArguments] - 1];
        
        //populate the mocked callback with content
        SwrveUserResourcesCallback(@{@"house": @{@"uid": @"house", @"name": @"house", @"cost": @"999"}}, @"test string");
        
    }] userResources:OCMOCK_ANY];
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        // Call resources methods

        [self runJS:
         @"window.plugins.swrve.getUserResources(function(resources) {"
         @"window.testResources = resources;"
         @"}, function () {});"];
        
        // Give 5 seconds for the response to be received by the Javascript callbacks
        NSString *userResourcesObtainedJSON = nil;
        
        BOOL resourcesReceived = NO;
        for(int i = 0; i < waitShort && !resourcesReceived; i++) {
            userResourcesObtainedJSON = [self runJS:@"JSON.stringify(window.testResources)"];
            resourcesReceived = (userResourcesObtainedJSON != nil && ![userResourcesObtainedJSON isEqualToString:@""]);
            if (!resourcesReceived) {
                [self waitForSeconds:1];
            }
        }
        
        XCTAssertTrue(resourcesReceived);
        
        // Check user resources obtained through the plugin
        NSDictionary *userResourcesObtained = [NSJSONSerialization JSONObjectWithData:[userResourcesObtainedJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        XCTAssertEqual([[[userResourcesObtained objectForKey:@"house"] objectForKey:@"cost"] integerValue], 999);
        
        [apploaded fulfill];
    }];
    
    /// waiting for waitForApplicationToStart
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testEvents");
        }
    }];
}

- (void)testUserResourcesDiff {
    // Mock the Async callback for User Resources
    [[[swrveMock expect] andDo:^(NSInvocation *invocation) {
        
        // define the new diffCallback
        void (^SwrveUserResourcesDiffCallback)(NSDictionary * oldResourcesValues, NSDictionary * newResourcesValues, NSString * resourcesAsJSON) = nil;
        
        // The block is the last argument that is passed into the given function
        [invocation getArgument:&SwrveUserResourcesDiffCallback atIndex:[[invocation methodSignature]numberOfArguments] - 1];
        
        //populate the mocked callback with content
        SwrveUserResourcesDiffCallback(@{@"house":@{@"cost": @"550"}}, @{@"house":@{@"cost": @"666"}}, @"test string");
        
    }] userResourcesDiff:OCMOCK_ANY];

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        // Call resources methods
        [self runJS:
         @"window.plugins.swrve.getUserResourcesDiff(function(resourcesDiff) {"
         @"window.testResourcesDiff = resourcesDiff;"
         @"}, function () {});"];
        
        // Give 15 seconds for the response to be received by the Javascript callbacks
        NSString *userResourcesDiffObtainedJSON = nil;
        
        BOOL resourcesReceived = NO;
        for(int i = 0; i < waitShort && !resourcesReceived; i++) {
            userResourcesDiffObtainedJSON = [self runJS:@"JSON.stringify(window.testResourcesDiff)"];
            resourcesReceived = ( userResourcesDiffObtainedJSON != nil && ![userResourcesDiffObtainedJSON isEqualToString:@""]);
            if (!resourcesReceived) {
                [self waitForSeconds:1];
            }
        }
        XCTAssertTrue(resourcesReceived);
        
        // Check user resources diff obtained through the plugin
        NSDictionary *userResourcesDiffObtained = [NSJSONSerialization JSONObjectWithData:[userResourcesDiffObtainedJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        XCTAssertEqual([[[[userResourcesDiffObtained objectForKey:@"new"] objectForKey:@"house"] objectForKey:@"cost"] integerValue], 666);
        XCTAssertEqual([[[[userResourcesDiffObtained objectForKey:@"old"] objectForKey:@"house"] objectForKey:@"cost"] integerValue], 550);
        [apploaded fulfill];
    }];
    
    /// waiting for waitForApplicationToStart
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testEvents");
        }
    }];
}


- (void)testUserResourcesListener {
    
    id swrveResourcesMock = OCMClassMock([SwrveResourceManager class]);
    NSDictionary *mockedUserResources = @{@"house": @{@"uid": @"house", @"name": @"house", @"cost": @"888"}};
    OCMStub([swrveResourcesMock resources]).andReturn(mockedUserResources);
    
    OCMStub([swrveMock resourceManager]).andReturn(swrveResourcesMock);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        // Call resources methods
        
        [self runJS:
         @"window.plugins.swrve.setResourcesListener(function(resources) {"
         @"window.testResourcesListener = resources;"
         @"});"];
        
        // Give 15 seconds for the response to be received by the Javascript callbacks
        NSString *userResourcesListenerObtainedJSON = nil;
        
        BOOL resourcesReceived = NO;
        for(int i = 0; i < waitShort && !resourcesReceived; i++) {
            userResourcesListenerObtainedJSON = [self runJS:@"JSON.stringify(window.testResourcesListener)"];
            resourcesReceived = (userResourcesListenerObtainedJSON != nil && ![userResourcesListenerObtainedJSON isEqualToString:@""]);
            if (!resourcesReceived) {
                [self waitForSeconds:1];
            }
        }
        XCTAssertTrue(resourcesReceived);
        
        // Check user resources obtained through the listener
        NSDictionary *userResourcesListenerObtained = [NSJSONSerialization JSONObjectWithData:[userResourcesListenerObtainedJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        XCTAssertEqual([[[userResourcesListenerObtained objectForKey:@"house"] objectForKey:@"cost"] integerValue], 888);
        
        [apploaded fulfill];
    }];
    
    /// waiting for waitForApplicationToStart
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testEvents");
        }
    }];
}


- (void)testCustomButtonListener {
    NSString *expectedAction = @"custom_action_from_server";

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {

    [self runJS:@"window.plugins.swrve.setCustomButtonListener(function(action) { window.testCustomAction = action; });"];
    [self waitForSeconds:2];

    XCTAssertNotNil([self->swrveMock messaging].customButtonCallback, @"customButtonCallback should NOT be null");

    void (^testCallback)(NSString *action) = [self->swrveMock messaging].customButtonCallback;

    testCallback(expectedAction);

    XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
    [self waitForActionReceivedForJavascript:@"window.testCustomAction" withCallback:^(NSString  *response) {
        BOOL customActionReceived = [response isEqualToString:expectedAction];
        XCTAssert(customActionReceived);
        [responseReceived fulfill];
    }];

    [apploaded fulfill];
    }];

    /// waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testCustomButtonListener");
        }
    }];
}

- (void)testDismissButtonListener {
    // Mocked variables
    NSString *campaignSubjectMocked = @"mocked_campaignSubject";
    NSString *buttonNameMocked = @"mocked_buttonName";
    NSDictionary *expectedCallback = @{
                                       @"campaignSubject": campaignSubjectMocked,
                                       @"buttonName": buttonNameMocked,
                                       };

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {

        [self runJS:@"window.plugins.swrve.setDismissButtonListener(function(callback) { window.testDismissCallback = callback; });"];
        [self waitForSeconds:2];

        XCTAssertNotNil([self->swrveMock messaging].dismissButtonCallback, @"customButtonCallback should NOT be null");

        void (^testCallback)(NSString *campaignSubject, NSString *buttonName) = [self->swrveMock messaging].dismissButtonCallback;

        testCallback(campaignSubjectMocked, buttonNameMocked);

        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testDismissCallback" withCallback:^(NSString *response) {
            NSDictionary *listenerCallback = [NSJSONSerialization JSONObjectWithData:[response dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
            XCTAssertEqualObjects(listenerCallback, expectedCallback);
            XCTAssertEqualObjects([listenerCallback objectForKey:@"campaignSubject"], campaignSubjectMocked);
            XCTAssertEqualObjects([listenerCallback objectForKey:@"buttonName"], buttonNameMocked);
            [responseReceived fulfill];
        }];

        [apploaded fulfill];
    }];

    /// waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testDismissButtonListener");
        }
    }];
}


- (void)testCustomPushPayloadListener {
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        
        // Send fake remote notification to check that the custom push payload listener works
        // Inject javascript listeners
        [self runJS:@"window.testPushPayload = {};"];
        [self runJS:@"window.plugins.swrve.setPushNotificationListener(function(payload) { window.testPushPayload = payload; });"];
        [self waitForSeconds:1];
        // Mock state of the app to be in the background
        UIApplication *backgroundStateApp = OCMClassMock([UIApplication class]);
        OCMStub([backgroundStateApp applicationState]).andReturn(UIApplicationStateBackground);
        OCMStub([self->swrveMock didReceiveRemoteNotification:OCMOCK_ANY withBackgroundCompletionHandler:OCMOCK_ANY]).andReturn(YES);
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"_p", @"custom", @"custom_payload", nil];
        [self->appDelegate application:backgroundStateApp didReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
            
        }];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testPushPayload.custom_payload" withCallback:^(NSString *response) {
            BOOL customPayloadReceived = [response isEqualToString:@"custom"];
            XCTAssert(customPayloadReceived);
            [responseReceived fulfill];
        }];
        
        [apploaded fulfill];
    }];
    
    /// waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testCustomPushPayloadListener");
        }
    }];
}

- (void)testSilentPushPayloadListener {
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {

        // Send fake remote notification to check that the custom push payload listener works
        // Inject javascript listeners
        [self runJS:@"window.testSilentPushPayload = {};"];
        [self runJS:@"window.plugins.swrve.setSilentPushNotificationListener(function(payload) { window.testSilentPushPayload = payload; });"];
        [self waitForSeconds:1];
        // Mock state of the app to be in the background
        UIApplication *backgroundStateApp = OCMClassMock([UIApplication class]);
        OCMStub([backgroundStateApp applicationState]).andReturn(UIApplicationStateBackground);
        OCMStub([self->swrveMock didReceiveRemoteNotification:OCMOCK_ANY withBackgroundCompletionHandler:OCMOCK_ANY]).andReturn(YES);

        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"_p", @{@"custom_payload": @"custom"}, @"_s.SilentPayload", nil];

        [self->appDelegate application:backgroundStateApp didReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {

        }];

        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testSilentPushPayload.custom_payload" withCallback:^(NSString *response) {
            BOOL customPayloadReceived = [response isEqualToString:@"custom"];
            XCTAssert(customPayloadReceived);
            [responseReceived fulfill];
        }];

        [apploaded fulfill];
    }];

    /// waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testSilentPushListener");
        }
    }];
}

- (void)testGetUserId {
    NSString *falseUserID = @"testUserID";
    OCMStub([swrveMock userID]).andReturn(falseUserID);

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.getUserId(function(userId) { window.testUserId = userId; });"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        
        [self waitForActionReceivedForJavascript:@"window.testUserId" withCallback:^(NSString  *response) {
            [responseReceived fulfill];
            XCTAssert(response != nil);
            XCTAssertEqualObjects(response, falseUserID);
        }];
        
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testGetUserId");
        }
    }];
}

- (void)testGetApiKey {
    NSString *falseApiKey = @"testApiKey";
    OCMStub([swrveMock apiKey]).andReturn(falseApiKey);

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.getApiKey(function(apiKey) { window.testApiKey = apiKey; });"];

        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];

        [self waitForActionReceivedForJavascript:@"window.testApiKey" withCallback:^(NSString  *response) {
            [responseReceived fulfill];
            XCTAssert(response != nil);
            XCTAssertEqualObjects(response, falseApiKey);
        }];

        [apploaded fulfill];
    }];

    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testGetApiKey");
        }
    }];
}

- (void)testGetExternalUserId {
    NSString *falseExternalUserID = @"testExternalUserID";
    OCMStub([swrveMock externalUserId]).andReturn(falseExternalUserID);

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.getExternalUserId(function(externalUserId) { window.testExternalUserId = externalUserId; });"];

        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];

        [self waitForActionReceivedForJavascript:@"window.testExternalUserId" withCallback:^(NSString  *response) {
            [responseReceived fulfill];
            XCTAssert(response != nil);
            XCTAssertEqualObjects(response, falseExternalUserID);
        }];

        [apploaded fulfill];
    }];

    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testGetExternalUserId");
        }
    }];
}

- (void)testIdentifyOnSuccess {
    // Mocked variables
    NSString *userIdMocked = @"swrveInternal";
    NSString *statusMocked = @"loaded from cache";
    NSDictionary *expectedIdentify = @{
                             @"status": statusMocked,
                             @"swrveId": userIdMocked,
                             };

    // Mock the Async callback for User identity
    [[[swrveMock expect] andDo:^(NSInvocation *invocation) {
        // define the New on Success
        void (^onSuccess)(NSString *status, NSString *swrveUserId) = nil;
        [invocation getArgument:&onSuccess atIndex:[[invocation methodSignature]numberOfArguments] - 2];
        onSuccess(statusMocked, userIdMocked);
    }] identify:OCMOCK_ANY onSuccess:OCMOCK_ANY onError:OCMOCK_ANY];

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Call identify method
        [self runJS:@"window.plugins.swrve.identify('MyExternalUserId', function(onSuccess) { window.testIdentifyOnSuccess = onSuccess; }, undefined);"];

        // Give 15 seconds for the response to be received by the Javascript callbacks
        NSString *identifyJSON = nil;
        BOOL identityReceived = NO;
        for(int i = 0; i < waitShort && !identityReceived; i++) {
            identifyJSON = [self runJS:@"JSON.stringify(window.testIdentifyOnSuccess)"];
            identityReceived = ( identifyJSON != nil && ![identifyJSON isEqualToString:@""]);
            if (!identityReceived) {
                [self waitForSeconds:1];
            }
        }
        XCTAssertTrue(identityReceived);
        // Check identity json obtained through the plugin
        NSDictionary *identityCallback = [NSJSONSerialization JSONObjectWithData:[identifyJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        XCTAssertEqualObjects(identityCallback, expectedIdentify);
        XCTAssertEqualObjects([identityCallback objectForKey:@"status"], statusMocked);
        XCTAssertEqualObjects([identityCallback objectForKey:@"swrveId"], userIdMocked);
        [apploaded fulfill];

    }];

    /// waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testIdentifyOnSuccess");
        }
    }];
}

- (void)testIdentifyOnError {
    NSInteger responseCodeMocked = 403;
    NSString *errorMsgMocked = @"Email forbidden";
    NSDictionary *expectedIdentify = @{
                                       @"responseCode": [NSNumber numberWithInteger:responseCodeMocked],
                                       @"errorMessage": errorMsgMocked,
                                       };

    // Mock the Async callback for User identity
    [[[swrveMock expect] andDo:^(NSInvocation *invocation) {
        // define the New onError.
        void (^onError)(NSInteger httpCode, NSString *errorMessage) = nil;
        [invocation getArgument:&onError atIndex:[[invocation methodSignature]numberOfArguments] - 1];
        onError(responseCodeMocked, errorMsgMocked);
    }] identify:OCMOCK_ANY onSuccess:OCMOCK_ANY onError:OCMOCK_ANY];

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Call identify method
        [self runJS:@"window.plugins.swrve.identify('MyExternalUserId', undefined, function(onError) { window.testIdentifyOnError = onError; });"];

        // Give 15 seconds for the response to be received by the Javascript callbacks
        NSString *identifyJSON = nil;
        BOOL identityReceived = NO;
        for(int i = 0; i < waitShort && !identityReceived; i++) {
            identifyJSON = [self runJS:@"JSON.stringify(window.testIdentifyOnError)"];
            identityReceived = ( identifyJSON != nil && ![identifyJSON isEqualToString:@""]);
            if (!identityReceived) {
                [self waitForSeconds:1];
            }
        }
        XCTAssertTrue(identityReceived);
        // Check identity json obtained through the plugin
        NSDictionary *identityCallback = [NSJSONSerialization JSONObjectWithData:[identifyJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        XCTAssertEqualObjects(identityCallback, expectedIdentify);
        XCTAssertEqualObjects([identityCallback objectForKey:@"responseCode"], [NSNumber numberWithInteger:responseCodeMocked]);
        XCTAssertEqualObjects([identityCallback objectForKey:@"errorMessage"], errorMsgMocked);
        [apploaded fulfill];

    }];

    /// waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testIdentifyOnError");
        }
    }];
}

- (void)testMessageCenterResponse {
    
    id swrveMessagingMock = OCMClassMock([SwrveMessageController class]);
    SwrveCampaign *campaignMock = OCMClassMock([SwrveCampaign class]);
    SwrveCampaignState *campaignStateMock = OCMClassMock([SwrveCampaignState class]);
    
    // Mock Campaign State
    OCMStub([campaignStateMock campaignID]).andReturn(44);
    OCMStub([campaignStateMock status]).andReturn(SWRVE_CAMPAIGN_STATUS_UNSEEN);
    OCMStub([campaignStateMock impressions]).andReturn(0);
    OCMStub([campaignStateMock next]).andReturn(0);
    
    // Mock Campaign
    OCMStub([campaignMock ID]).andReturn(44);
    OCMStub([campaignMock subject]).andReturn(@"IAM subject");
    OCMStub([campaignMock messageCenter]).andReturn(true);
    OCMStub([campaignMock maxImpressions]).andReturn(11111);
    OCMStub([campaignMock dateStart]).andReturn([NSDate dateWithTimeIntervalSince1970:1362671700]);
    OCMStub([campaignStateMock status]).andReturn(campaignStateMock);
    
    // Mock Campaigns List
    NSArray *mockList = [NSArray arrayWithObject:campaignMock];
    OCMExpect([swrveMessagingMock messageCenterCampaigns]).andReturn(mockList);
    
    OCMStub([swrveMock messaging]).andReturn(swrveMessagingMock);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        [self runJS:
         @"window.plugins.swrve.getMessageCenterCampaigns(function(campaigns) {"
         @"window.MCCampaigns = campaigns;"
         @"});"];;
        
        [self waitForSeconds:1];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"JSON.stringify(window.MCCampaigns)" withCallback:^(NSString  *response) {
            XCTAssertNotNil(response, @"response should not be null");
            NSMutableArray *messageCentre = [[NSMutableArray alloc] init];
            messageCentre = [NSJSONSerialization JSONObjectWithData:[response dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
            
            NSDictionary *firstCampaign = [messageCentre firstObject];
            XCTAssertNotNil(firstCampaign, @"Campaign from Message Center should not be null");
            XCTAssertEqualObjects([firstCampaign objectForKey:@"subject"], @"IAM subject");
            XCTAssertEqual([[firstCampaign objectForKey:@"ID"] integerValue], 44);
            XCTAssertTrue([firstCampaign objectForKey:@"messageCenter"], @"messageCenter should be true");
            XCTAssertEqual([[firstCampaign objectForKey:@"maxImpressions"] integerValue], 11111);
            XCTAssertEqual([[firstCampaign objectForKey:@"dateStart"] integerValue], 1362671700);
            
            NSDictionary *firstCampaignState = [firstCampaign objectForKey:@"state"];
            XCTAssertEqual([[firstCampaignState objectForKey:@"next"] integerValue], 0);
            XCTAssertEqualObjects([firstCampaignState objectForKey:@"status"], @"Unseen");
            XCTAssertEqual([[firstCampaignState objectForKey:@"impressions"] integerValue], 0);
            
            [responseReceived fulfill];
        }];
        
        [swrveMessagingMock verify];
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testMessageCenterResponse");
        }
    }];
    
    [swrveMessagingMock stopMocking];
}

- (void)testShowMessageCenterCampaign {
    
    id swrveMessagingMock = OCMClassMock([SwrveMessageController class]);
    SwrveCampaign *campaignMock = OCMClassMock([SwrveCampaign class]);
    OCMStub([campaignMock ID]).andReturn(88);
    
    NSArray *mockList = [NSArray arrayWithObject:campaignMock];
    OCMExpect([swrveMessagingMock messageCenterCampaigns]).andReturn(mockList);
    OCMExpect([(SwrveMessageController*) swrveMessagingMock showMessageCenterCampaign:campaignMock]).andDo(nil);
    
    OCMStub([swrveMock messaging]).andReturn(swrveMessagingMock);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        [self runJS:@"window.plugins.swrve.showMessageCenterCampaign(88, undefined, undefined);"];
        [self waitForSeconds:1];
        [swrveMessagingMock verify];
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testShowMessageCenterCampaign");
        }
    }];
    [swrveMessagingMock stopMocking];
}

- (void)testRemoveMessageCenterCampaign {
    
    id swrveMessagingMock = OCMClassMock([SwrveMessageController class]);
    SwrveCampaign *campaignMock = OCMClassMock([SwrveCampaign class]);
    OCMStub([campaignMock ID]).andReturn(44);
    
    NSArray *mockList = [NSArray arrayWithObject:campaignMock];
    OCMExpect([swrveMessagingMock messageCenterCampaigns]).andReturn(mockList);
    OCMExpect([(SwrveMessageController*) swrveMessagingMock removeMessageCenterCampaign:campaignMock]).andDo(nil);
    
    OCMStub([swrveMock messaging]).andReturn(swrveMessagingMock);
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        [self runJS:@"window.plugins.swrve.removeMessageCenterCampaign(44, undefined, undefined);"];
        [self waitForSeconds:1];
        [swrveMessagingMock verify];
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testRemoveMessageCenterCampaign");
        }
    }];
    [swrveMessagingMock stopMocking];
}

- (void)testCustomPayloadForConversationInput {

    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setObject:@"someObj" forKey:@"someKey"];
    OCMExpect([swrveMock setCustomPayloadForConversationInput:dict]).andDo(nil);

    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.setCustomPayloadForConversationInput({\"someKey\":\"someObj\"}, function(forceCallback) { window.testCustomPayloadForConversationInput = `success`}, undefined);"];

        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testCustomPayloadForConversationInput" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
            [self->swrveMock verify];
        }];
        [apploaded fulfill];
    }];

    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testCustomPayloadForConversationInput");
        }
    }];
}

@end
