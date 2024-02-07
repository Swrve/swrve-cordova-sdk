#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "SwrvePlugin.h"

#import <SwrveSDK/Swrve.h>
#import <SwrveSDK/SwrveSDK.h>
#import <SwrveSDK/SwrveCampaign.h>
#import <SwrveSDK/SwrveCampaignStatus.h>
#import <SwrveSDKCommon/SwrveCommon.h>

#import <SwrveSDK/SwrveMessageController.h>

#import "AppDelegate.h"
#import "SwrveTestHelper.h"

#import <WebKit/WebKit.h>
#import <Cordova/CDVWebViewEngineProtocol.h>


@interface Swrve ()
@property(atomic) SwrveMessageController *messaging;
@end

@interface SwrvePluginTests : XCTestCase {
    AppDelegate *appDelegate;
    CDVViewController *controller;
    id swrveMock;
}
@end

@implementation SwrvePluginTests

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

#pragma mark - wait / helper functions

- (void)evaluateJS:(NSString *)js  withCompletionHandler:(void (^)(id))completionHandler  {
    [controller.webViewEngine evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"Result: %@", result);
        if (completionHandler != nil) {
            completionHandler(result);
        }
    }];
}

- (void)waitForAplicationStart {
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"ApplicationStarted"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"((window !== undefined && 'plugins' in window && 'swrve' in window.plugins)? 'yes' : 'no')"];
        [self evaluateJS:js withCompletionHandler:^(NSString * result) {
            complete = ([result isEqualToString:@"yes"]);
        }];
        return complete;
    } expectation:expectation];
    [self waitForExpectationsWithTimeout:10 handler:nil];
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
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.event(\"levelup\", undefined, undefined);" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, undefined, undefined);" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, undefined, undefined);" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date(2016, 12, 2, 16, 20, 0, 0), undefined, undefined);" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.currencyGiven(\"Gold\", 12, function(forceCallback) { window.testCurrencyGiven = `success`}, undefined);" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, undefined, undefined);" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.unvalidatedIap(99.2,\"USD\",\"iap_item\", 15, undefined, undefined);" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.sendEvents(function(forceCallback) { window.sendEvents =\"finished\"}, undefined);" withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.sendEvents"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"finished"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testEvent {
    OCMExpect([(Swrve*) swrveMock event:@"my_event"]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.event(\"my_event\", undefined, function(forceCallback) { window.testEvent =\"success\"}, undefined);"
 withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testEvent"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testEventWithPayload {
    OCMExpect([swrveMock event:@"leveldown" payload:@{@"armor": @"disabled"}]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, function(forceCallback) { window.testEventPayload = `success`}, undefined);"
 withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testEventPayload"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testUserUpdate {
    OCMExpect([(Swrve*) swrveMock userUpdate:@{@"cordova": @"TRUE"}]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, function(forceCallback) { window.testUserUpdate = `success`}, undefined);"
 withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testUserUpdate"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testUserUpdateDate {
    NSString *propertyValueRaw = @"2017-01-02T16:20:00.000Z";
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
    NSDate* dateValue = [dateFormatter dateFromString:propertyValueRaw];
    
    OCMExpect([swrveMock userUpdate:@"last_subscribed" withDate:dateValue]).andDo(nil);
    
    [self waitForAplicationStart];
    NSString *js = [NSString stringWithFormat:@"window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date('2017-01-02T16:20:00'), function(forceCallback) { window.testUserUpdateDate = `success`}, undefined);"];
    [self evaluateJS:js withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"UserUpdate"];

    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testUserUpdateDate"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
}
    
- (void)testCurrencyGiven {
    OCMExpect([swrveMock currencyGiven:@"Gold" givenAmount:20.0]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.currencyGiven(\"Gold\", 20, function(forceCallback) { window.testCurrencyGiven = `success`}, undefined);" withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testCurrencyGiven"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testPurchase {
    OCMExpect([swrveMock purchaseItem:@"sword" currency:@"Gold" cost:15 quantity:2]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, function(forceCallback) { window.testPurchase = `success`}, undefined);" withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testPurchase"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testIAP {
    OCMExpect([swrveMock unvalidatedIap:nil localCost:99.2 localCurrency:@"USD" productId:@"iap_item" productIdQuantity:15]).andDo(nil);

    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.unvalidatedIap(99.2,\"USD\",\"iap_item\", 15, function(forceCallback) { window.testIAP = `success`}, undefined);" withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testIAP"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testIAPWithReward {
    OCMExpect([swrveMock unvalidatedIap:[OCMArg isNotNil] localCost:88.2 localCurrency:@"EUR" productId:@"iap_item" productIdQuantity:20]).andDo(nil);

    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.unvalidatedIapWithReward(88.2,\"EUR\",\"iap_item\", 20, {\"items\":[{\"name\": \"reward.item.type1\", \"amount\":1}], \"currencies\":[]} , function(forceCallback) { window.testIAPWithReward = `success`}, undefined);" withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testIAPWithReward"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    OCMVerifyAllWithDelay(swrveMock, 1);
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

    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.getUserResources(function(resources) {"
     @"window.testResources = resources;"
     @"}, function () {});" withCompletionHandler:nil];

    __block bool complete = false;
    __block NSString *json = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"JSON.stringify(window.testResources)"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            json = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    // Check user resources obtained through the plugin
    NSDictionary *userResourcesObtained = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    XCTAssertEqual([[[userResourcesObtained objectForKey:@"house"] objectForKey:@"cost"] integerValue], 999);
    OCMVerifyAllWithDelay(swrveMock, 1);
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

    }] userResourcesDiffWithListener:OCMOCK_ANY];
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.getUserResourcesDiff(function(resourcesDiff) {"
     @"window.testResourcesDiff = resourcesDiff;"
     @"}, function () {});" withCompletionHandler:nil];

    __block bool complete = false;
    __block NSString *json = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"JSON.stringify(window.testResourcesDiff)"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            json = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    // Check user resources diff obtained through the plugin
    NSDictionary *userResourcesDiffObtained = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    XCTAssertEqual([[[[userResourcesDiffObtained objectForKey:@"new"] objectForKey:@"house"] objectForKey:@"cost"] integerValue], 666);
    XCTAssertEqual([[[[userResourcesDiffObtained objectForKey:@"old"] objectForKey:@"house"] objectForKey:@"cost"] integerValue], 550);
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testUserResourcesListener {
    id swrveResourcesMock = OCMClassMock([SwrveResourceManager class]);
    NSDictionary *mockedUserResources = @{@"mockedResources":
                                              @{@"uid": @"AnUUID",
                                                @"name": @"Whatever",
                                                @"cost": @888}
                                        };

    OCMStub([swrveResourcesMock resources]).andReturn(mockedUserResources);
    OCMStub([swrveMock resourceManager]).andReturn(swrveResourcesMock);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.setResourcesListener(function(resources) {"
     @"window.testResourcesListener = resources;"
     @"});" withCompletionHandler:nil];

    __block bool complete = false;
    __block NSString *json = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"JSON.stringify(window.testResourcesListener)"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            json = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    // Check user resources obtained through the listener
    XCTAssertNotNil(json);
    NSLog(@"userResourcesListenerObtainedJSON %@",json);

    // Check user resources diff obtained through the plugin
    NSDictionary *userResourcesObtained = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    
    NSDictionary *mockedResources = [userResourcesObtained objectForKey:@"mockedResources"];
    XCTAssertEqualObjects([mockedResources objectForKey:@"name"], @"Whatever");
    XCTAssertEqualObjects([mockedResources objectForKey:@"uid"], @"AnUUID");
    XCTAssertEqualObjects([mockedResources objectForKey:@"cost"], @888);
    OCMVerifyAllWithDelay(swrveMock, 1);
}

- (void)testCustomButtonListener {
    NSString *expectedAction = @"custom_action_from_server";

    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.setCustomButtonListener(function(action) { window.testCustomAction = action; });" withCompletionHandler:nil];
    
    XCTAssertNotNil([self->swrveMock messaging].customButtonCallback, @"customButtonCallback should NOT be null");

    void (^testCallback)(NSString *action, NSString *campaignName) = [self->swrveMock messaging].customButtonCallback;

    testCallback(expectedAction, @"");

    __block bool complete = false;
    __block NSString *action = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testCustomAction"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            action = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    XCTAssertEqualObjects(expectedAction, action);
}

- (void)testClipboardButtonListener {
    NSString *expectedClipboard = @"custom_clipboard";
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.setClipboardButtonListener(function(clipboard) { window.testCustomClipboard = clipboard; });"
    withCompletionHandler:nil];
    
    XCTAssertNotNil([self->swrveMock messaging].dismissButtonCallback, @"dismissButtonCallback should NOT be null");
    void (^clipboardButtonCallback)(NSString *clipboard) = [self->swrveMock messaging].clipboardButtonCallback;
    clipboardButtonCallback(expectedClipboard);

    __block bool complete = false;
    __block NSString *action = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testCustomClipboard"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            action = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    XCTAssertEqualObjects(expectedClipboard, action);
}

- (void)testDismissButtonListener {
    // Mocked variables
    NSString *campaignSubjectMocked = @"mocked_campaignSubject";
    NSString *buttonNameMocked = @"mocked_buttonName";
    NSDictionary *expectedCallback = @{
                                       @"campaignSubject": campaignSubjectMocked,
                                       @"buttonName": buttonNameMocked,
                                       };

    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.setDismissButtonListener(function(callback) { window.testDismissCallback = callback; });"
    withCompletionHandler:nil];
    
    XCTAssertNotNil([self->swrveMock messaging].dismissButtonCallback, @"customButtonCallback should NOT be null");
    void (^testCallback)(NSString *campaignSubject, NSString *buttonName, NSString *campaignName) = [self->swrveMock messaging].dismissButtonCallback;
    testCallback(campaignSubjectMocked, buttonNameMocked, @"");

    __block bool complete = false;
    __block NSString *json = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testDismissCallback"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            json = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    NSDictionary *listenerCallback = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    XCTAssertEqualObjects(listenerCallback, expectedCallback);
    XCTAssertEqualObjects([listenerCallback objectForKey:@"campaignSubject"], campaignSubjectMocked);
    XCTAssertEqualObjects([listenerCallback objectForKey:@"buttonName"], buttonNameMocked);
}


- (void)testCustomPushPayloadListener {
    [self waitForAplicationStart];
    [self evaluateJS:@"window.testPushPayload = {};" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.setPushNotificationListener(function(payload) { window.testPushPayload = payload; });" withCompletionHandler:nil];
    
    // Mock state of the app to be in the background
    UIApplication *backgroundStateApp = OCMClassMock([UIApplication class]);
    OCMStub([backgroundStateApp applicationState]).andReturn(UIApplicationStateBackground);
    OCMStub([self->swrveMock didReceiveRemoteNotification:OCMOCK_ANY withBackgroundCompletionHandler:OCMOCK_ANY]).andReturn(YES);

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"_p", @"custom", @"custom_payload", nil];
    [self->appDelegate application:backgroundStateApp didReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {

    }];

    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testPushPayload.custom_payload"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = [result isEqualToString:@"custom"];
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testSilentPushPayloadListener {
    [self waitForAplicationStart];
    [self evaluateJS:@"window.testSilentPushPayload = {};" withCompletionHandler:nil];
    [self evaluateJS:@"window.plugins.swrve.setSilentPushNotificationListener(function(payload) { window.testSilentPushPayload = payload; });" withCompletionHandler:nil];
    
    UIApplication *backgroundStateApp = OCMClassMock([UIApplication class]);
    OCMStub([backgroundStateApp applicationState]).andReturn(UIApplicationStateBackground);
    OCMStub([self->swrveMock didReceiveRemoteNotification:OCMOCK_ANY withBackgroundCompletionHandler:OCMOCK_ANY]).andReturn(YES);

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"_p", @{@"custom_payload": @"custom"}, @"_s.SilentPayload", nil];

    [self->appDelegate application:backgroundStateApp didReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
    }];


    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL() {
        NSString *js = [NSString stringWithFormat:@"window.testSilentPushPayload.custom_payload"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = [result isEqualToString:@"custom"];
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testGetUserId {
    NSString *falseUserID = @"testUserID";
    OCMStub([swrveMock userID]).andReturn(falseUserID);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.getUserId(function(userId) { window.testUserId = userId; });" withCompletionHandler:nil];

    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testUserId"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = [result isEqualToString:falseUserID];
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testGetApiKey {
    NSString *falseApiKey = @"testApiKey";
    OCMStub([swrveMock apiKey]).andReturn(falseApiKey);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.getApiKey(function(apiKey) { window.testApiKey = apiKey; });" withCompletionHandler:nil];

    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testApiKey"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = [result isEqualToString:falseApiKey];
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testGetExternalUserId {
    NSString *falseExternalUserID = @"testExternalUserID";
    OCMStub([swrveMock externalUserId]).andReturn(falseExternalUserID);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.getExternalUserId(function(externalUserId) { window.testExternalUserId = externalUserId; });" withCompletionHandler:nil];

    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testExternalUserId"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = [result isEqualToString:falseExternalUserID];
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
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
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.identify('MyExternalUserId', function(onSuccess) { window.testIdentifyOnSuccess = onSuccess; }, undefined);" withCompletionHandler:nil];
    
    __block NSString *json = nil;
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"JSON.stringify(window.testIdentifyOnSuccess)"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            json = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    // Check identity json obtained through the plugin
    NSDictionary *identityCallback = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    XCTAssertEqualObjects(identityCallback, expectedIdentify);
    XCTAssertEqualObjects([identityCallback objectForKey:@"status"], statusMocked);
    XCTAssertEqualObjects([identityCallback objectForKey:@"swrveId"], userIdMocked);
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
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.identify('MyExternalUserId', undefined, function(onError) { window.testIdentifyOnError = onError; });"
    withCompletionHandler:nil];
    
    __block NSString *json = nil;
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"JSON.stringify(window.testIdentifyOnError)"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            json = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    // Check identity json obtained through the plugin
    NSDictionary *identityCallback = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    XCTAssertEqualObjects(identityCallback, expectedIdentify);
    XCTAssertEqualObjects([identityCallback objectForKey:@"responseCode"], [NSNumber numberWithInteger:responseCodeMocked]);
    XCTAssertEqualObjects([identityCallback objectForKey:@"errorMessage"], errorMsgMocked);
}

- (void)testMessageCenterResponse {

    id swrveMessagingMock = OCMClassMock([SwrveMessageController class]);
    SwrveCampaign *campaignMock = OCMClassMock([SwrveCampaign class]);
    SwrveCampaignState *campaignStateMock = OCMClassMock([SwrveCampaignState class]);

    // Mock Campaign State
    OCMStub([campaignStateMock campaignID]).andReturn(44);
    OCMStub([campaignStateMock status]).andReturn(SWRVE_CAMPAIGN_STATUS_UNSEEN);
    OCMStub([campaignStateMock impressions]).andReturn(0);
    //OCMStub([campaignStateMock next]).andReturn(0);

    // Mock Campaign
    OCMStub([campaignMock ID]).andReturn(44);
    OCMStub([campaignMock subject]).andReturn(@"IAM subject");
    OCMStub([campaignMock messageCenter]).andReturn(true);
    OCMStub([campaignMock maxImpressions]).andReturn(11111);
    OCMStub([campaignMock dateStart]).andReturn([NSDate dateWithTimeIntervalSince1970:1362671700]);
    OCMStub([campaignStateMock status]).andReturn(campaignStateMock);

    // Mock Campaigns List
    NSArray *mockList = [NSArray arrayWithObject:campaignMock];
    OCMStub([swrveMock messageCenterCampaigns]).andReturn(mockList);
    OCMStub([swrveMock messaging]).andReturn(swrveMessagingMock);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.getMessageCenterCampaigns(function(campaigns) {"
     @"window.MCCampaigns = campaigns;"
     @"});"
 withCompletionHandler:nil];
    
    __block NSString *json = nil;
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"JSON.stringify(window.MCCampaigns)"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            json = result;
            complete = (result != nil);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    NSMutableArray *messageCentre = [NSMutableArray new];
    messageCentre = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];

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
}

- (void)testShowMessageCenterCampaign {
    SwrveCampaign *campaignMock = OCMClassMock([SwrveCampaign class]);
    OCMStub([campaignMock ID]).andReturn(88);

    NSArray *mockList = [NSArray arrayWithObject:campaignMock];
    OCMStub([swrveMock messageCenterCampaigns]).andReturn(mockList);
    OCMExpect([(Swrve *)swrveMock showMessageCenterCampaign:campaignMock]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.showMessageCenterCampaign(88, undefined, undefined);" withCompletionHandler:nil];
    OCMVerifyAllWithDelay(swrveMock, 2);
}

- (void)testRemoveMessageCenterCampaign {
    SwrveCampaign *campaignMock = OCMClassMock([SwrveCampaign class]);
    OCMStub([campaignMock ID]).andReturn(44);

    NSArray *mockList = [NSArray arrayWithObject:campaignMock];
    OCMStub([swrveMock messageCenterCampaigns]).andReturn(mockList);
    OCMExpect([(Swrve *)swrveMock removeMessageCenterCampaign:campaignMock]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.removeMessageCenterCampaign(44, undefined, undefined);" withCompletionHandler:nil];
    OCMVerifyAllWithDelay(swrveMock, 5);
}

- (void)testCustomPayloadForConversationInput {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setObject:@"someObj" forKey:@"someKey"];
    OCMExpect([swrveMock setCustomPayloadForConversationInput:dict]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.setCustomPayloadForConversationInput({\"someKey\":\"someObj\"}, function(forceCallback) { window.testCustomPayloadForConversationInput = `success`}, undefined);"
 withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testCustomPayloadForConversationInput"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    [swrveMock verify];
}

- (void)testStartWithValidUserId {
    OCMExpect([(Swrve*) swrveMock startWithUserId:@"userId"]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.start(\"userId\", function(forceCallback) { window.testStart = `success`}, undefined);"
 withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testStart"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    [swrveMock verify];
}

- (void)testStartWithNoUserId {
    OCMExpect([(Swrve*) swrveMock start]).andDo(nil);
    
    [self waitForAplicationStart];
    [self evaluateJS:@"window.plugins.swrve.start([ ], function(forceCallback) { window.testStartWithNoUserId = `success`}, undefined);"
 withCompletionHandler:nil];
    
    __block bool complete = false;
    XCTestExpectation *expectation = [self expectationWithDescription:@"responseReceived"];
    [SwrveTestHelper waitForBlock:0.005 conditionBlock:^BOOL(){
        NSString *js = [NSString stringWithFormat:@"window.testStartWithNoUserId"];
        [self evaluateJS:js withCompletionHandler:^(id result) {
            complete = ([result isEqualToString:@"success"]);
        }];
        return complete;
    } expectation:expectation];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    [swrveMock verify];
}

- (void)testNativeSDKVersion {
    XCTAssertEqualObjects(@SWRVE_SDK_VERSION, @"8.11.0");
}

@end
