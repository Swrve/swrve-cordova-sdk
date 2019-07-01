#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "HTTPServer.h"
#import "SwrvePlugin.h"

#import <SwrveSDK/Swrve.h>
#import <SwrveSDK/SwrveSDK.h>
#import <SwrveSDK/SwrveCampaign.h>
#import <SwrveSDK/SwrveCampaignStatus.h>

#import "AppDelegate.h"
#import "TestHTTPConnection.h"
#import "TestHTTPResponse.h"
#import "SwrveTestHelper.h"

@interface SwrvePluginTests : XCTestCase {
    HTTPServer *httpEventServer;
    HTTPServer *httpContentServer;
    NSMutableArray *lastEventBatches;
    AppDelegate *appDelegate;
    CDVViewController *controller;
}
@end

@implementation SwrvePluginTests

#pragma mark - wait / helper functions

- (void)waitForApplicationToStart:(void(^)(NSString *))callback {
    NSDate *timerStart = [NSDate date];
    NSString *pluginState = nil;
    for (int i = 0; i < 30; i++) {
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
    for(int i = 0; i < 30 && !responseReceived; i++) {
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
    
    // Setup local servers
    NSString *rootPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"UnitTestServer"];
    httpEventServer = [[HTTPServer alloc] init];
    [httpEventServer setConnectionClass:[TestHTTPConnection class]];
    [httpEventServer setPort:8085];
    [httpEventServer setDocumentRoot:rootPath];
    NSError *error = nil;
    if (![httpEventServer start:&error]) {
        NSLog(@"Error starting event HTTP Server: %@", error);
    }
    
    httpContentServer = [[HTTPServer alloc] init];
    [httpContentServer setConnectionClass:[TestHTTPConnection class]];
    [httpContentServer setPort:8083];
    [httpContentServer setDocumentRoot:rootPath];
    if (![httpContentServer start:&error]) {
        NSLog(@"Error starting content HTTP Server: %@", error);
    }
    
    // Emulate user resources and campaigns endpoints
    NSURL *path = [[NSBundle bundleForClass:[SwrvePluginTests class]] URLForResource:@"test_campaigns_and_resources" withExtension:@"json"];
    NSString *testresourcesAndCampaigns = [NSString stringWithContentsOfURL:path encoding:NSUTF8StringEncoding error:nil];
    [TestHTTPConnection setHandler:@"api/1/user_resources_and_campaigns" handler:^NSObject<HTTPResponse>*(NSString *path, HTTPMessage *request) {
        return [[TestHTTPResponse alloc] initWithString:testresourcesAndCampaigns];
    }];
    [TestHTTPConnection setHandler:@"api/1/user_resources_diff" handler:^NSObject<HTTPResponse>*(NSString *path, HTTPMessage *request) {
        NSString *testResourcesDiff = @"[{ \"uid\": \"house\", \"diff\": { \"cost\": { \"old\": \"550\", \"new\": \"666\" }}}]";
        return [[TestHTTPResponse alloc] initWithString:testResourcesDiff];
    }];
    
    // Emulate event endpoint
    lastEventBatches = [[NSMutableArray alloc] init];
    [TestHTTPConnection setHandler:@"1/batch" handler:^NSObject<HTTPResponse>*(NSString *path, HTTPMessage *request) {
        NSString *batchBody = [[NSString alloc] initWithData:request.body encoding:NSUTF8StringEncoding];
        [self->lastEventBatches addObject:batchBody];
        NSLog(@"Received event batch %@", batchBody);
        return [[TestHTTPResponse alloc] initWithData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    // Image in CDN
    [TestHTTPConnection setHandler:@"/cdn/" handler:^NSObject<HTTPResponse>*(NSString *urlPath, HTTPMessage *request) {
        NSString *fileName = [urlPath stringByReplacingOccurrencesOfString:@"/cdn/" withString:@""];
        NSURL *url = [[NSBundle bundleForClass:[SwrvePluginTests class]] URLForResource:fileName withExtension:nil];
        TestHTTPResponse *response;
        if (url != nil) {
            NSData *imageData = [[NSData alloc]initWithContentsOfURL:url options:0 error:nil];
            response = [[TestHTTPResponse alloc] initWithData:imageData];
            response.contentType = @"image/png";
        } else {
            response = [[TestHTTPResponse alloc] initWithData:[@"404 Not Found" dataUsingEncoding:NSUTF8StringEncoding]];
            response.responseStatus = 404;
        }
        return response;
    }];
    
    appDelegate = [[UIApplication sharedApplication] delegate];
    controller = appDelegate.viewController;
}

- (void)tearDown {
    [super tearDown];
    
    if (httpEventServer != nil) {
        [httpEventServer stop];
        httpEventServer = nil;
    }
    
    if (httpContentServer != nil) {
        [httpContentServer stop];
        httpContentServer = nil;
    }
    
    // clear test data on teardown
    [SwrveTestHelper removeSDKData];
}

#pragma mark - tests

- (void)testEvents {
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        
        // Send any previous events now
        [self runJS:@"window.plugins.swrve.sendEvents(undefined, undefined);"];
        [self waitForSeconds:waitShort];
        
        // Send all instrumented events
        [self runJS:@"window.plugins.swrve.event(\"levelup\", undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.userUpdate({\"phonegap\":\"TRUE\"}, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date(2016, 12, 2, 16, 20, 0, 0), undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.currencyGiven(\"Gold\", 20, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.unvalidatedIap(99.2,\"USD\",\"iap_item\", 15, undefined, undefined);"];
        [self runJS:@"window.plugins.swrve.sendEvents(undefined, undefined);"];
        
        typedef BOOL (^EventChecker)(NSDictionary *event);
        NSMutableArray *eventChecks = [[NSMutableArray alloc] init];
        // Check for event
        [eventChecks addObject:^BOOL(NSDictionary *event) {
            return [[event objectForKey:@"name"] isEqualToString:@"levelup"]
            && [[event objectForKey:@"payload"] count] == 0;
        }];
        // Check for event with payload
        [eventChecks addObject:^BOOL(NSDictionary *event) {
            return [[event objectForKey:@"name"] isEqualToString:@"leveldown"]
            && [[[event objectForKey:@"payload"] objectForKey:@"armor"] isEqualToString:@"disabled"];
        }];
        // Check for user update event
        [eventChecks addObject:^BOOL(NSDictionary *event) {
            return [[event objectForKey:@"type"] isEqualToString:@"user"]
            && [[[event objectForKey:@"attributes"] objectForKey:@"phonegap"] isEqualToString:@"TRUE"];
        }];
        // Check for currency given event
        [eventChecks addObject:^BOOL(NSDictionary *event) {
            return [[event objectForKey:@"type"] isEqualToString:@"currency_given"]
            && [[event objectForKey:@"given_amount"] longValue] == 20
            && [[event objectForKey:@"given_currency"] isEqualToString:@"Gold"];
        }];
        // Check for purchase event
        [eventChecks addObject:^BOOL(NSDictionary *event) {
            return [[event objectForKey:@"type"] isEqualToString:@"purchase"]
            && [[event objectForKey:@"quantity"] longValue] == 2
            && [[event objectForKey:@"cost"] longValue] == 15
            && [[event objectForKey:@"currency"] isEqualToString:@"Gold"]
            && [[event objectForKey:@"item"] isEqualToString:@"sword"];
        }];
        // Check for unvalidated IAP event
        [eventChecks addObject:^BOOL(NSDictionary *event) {
            return [[event objectForKey:@"type"] isEqualToString:@"iap"]
            && [[event objectForKey:@"quantity"] longValue] == 15
            && [[event objectForKey:@"cost"] doubleValue] == 99.2
            && [[event objectForKey:@"local_currency"] isEqualToString:@"USD"]
            && [[event objectForKey:@"product_id"] isEqualToString:@"iap_item"];
        }];
        
        // Check for user update event
        [eventChecks addObject:^BOOL(NSDictionary *event) {
            return [[event objectForKey:@"type"] isEqualToString:@"user"]
            && [[[event objectForKey:@"attributes"] objectForKey:@"last_subscribed"] isEqualToString:@"2017-01-02T16:20:00.000Z"];
        }];
        
        // Search for the event in all sent batches
        BOOL allChecksPass = NO;
        for(int i = 0; i < 30 && !allChecksPass; i++) {
            allChecksPass = YES;
            for(int k = 0; k < eventChecks.count; k++) {
                EventChecker check = eventChecks[k];
                BOOL checkPasses = NO;
                for (NSString *batchJSON in lastEventBatches) {
                    NSDictionary *batchDictionary = [NSJSONSerialization JSONObjectWithData:[batchJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
                    NSArray *batchEvents = [batchDictionary objectForKey:@"data"];
                    for (NSDictionary *event in batchEvents) {
                        if (check(event)) {
                            checkPasses = YES;
                            break;
                        }
                    }
                    if (checkPasses) {
                        break;
                    }
                }
                if (!checkPasses) {
                    allChecksPass = NO;
                }
            }
            
            if (!allChecksPass) {
                [self waitForSeconds:1];
            }
        }
        
        XCTAssertTrue(allChecksPass);
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
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.event(\"my_event\", undefined, function(forceCallback) { window.testEvent =\"success\"}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testEvent" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
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
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, function(forceCallback) { window.testEventPayload = `success`}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testEventPayload" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
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
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, function(forceCallback) { window.testUserUpdate = `success`}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testUserUpdate" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
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
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date(2016, 12, 2, 16, 20, 0, 0), function(forceCallback) { window.testUserUpdateDate = `success`}, undefined);"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testUserUpdateDate" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
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
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.currencyGiven(\"Gold\", 20, function(forceCallback) { window.testCurrencyGiven = `success`}, undefined);"];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testCurrencyGiven" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
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
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, function(forceCallback) { window.testPurchase = `success`}, undefined);"];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testPurchase" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
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
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.unvalidatedIap(99.2,\"USD\",\"iap_item\", 15, function(forceCallback) { window.testIAP = `success`}, undefined);"];
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testIAP" withCallback:^(NSString *response) {
            [responseReceived fulfill];
            XCTAssertEqualObjects(response, @"success");
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

- (void)testUserResourcesAndResourcesDiff {
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        // Call resources methods
        [self runJS:
         @"window.plugins.swrve.getUserResourcesDiff(function(resourcesDiff) {"
         @"window.testResourcesDiff = resourcesDiff;"
         @"}, function () {});"];
        
        [self runJS:
         @"window.plugins.swrve.getUserResources(function(resources) {"
         @"window.testResources = resources;"
         @"}, function () {});"];
        
        [self runJS:
         @"window.plugins.swrve.setResourcesListener(function(resources) {"
         @"window.testResourcesListener = resources;"
         @"});"];
        
        // Give 30 seconds for the response to be received by the Javascript callbacks
        NSString *userResourcesObtainedJSON = nil;
        NSString *userResourcesListenerObtainedJSON = nil;
        NSString *userResourcesDiffObtainedJSON = nil;
        
        BOOL resourcesReceived = NO;
        for(int i = 0; i < waitLong && !resourcesReceived; i++) {
            userResourcesObtainedJSON = [self runJS:@"JSON.stringify(window.testResources)"];
            userResourcesListenerObtainedJSON = [self runJS:@"JSON.stringify(window.testResourcesListener)"];
            userResourcesDiffObtainedJSON = [self runJS:@"JSON.stringify(window.testResourcesDiff)"];
            resourcesReceived = (userResourcesObtainedJSON != nil && ![userResourcesObtainedJSON isEqualToString:@""] && userResourcesDiffObtainedJSON != nil && ![userResourcesDiffObtainedJSON isEqualToString:@""] && userResourcesListenerObtainedJSON != nil && ![userResourcesListenerObtainedJSON isEqualToString:@""]);
            if (!resourcesReceived) {
                [self waitForSeconds:1];
            }
        }
        XCTAssertTrue(resourcesReceived);
        
        // Check user resources obtained through the plugin
        NSDictionary *userResourcesObtained = [NSJSONSerialization JSONObjectWithData:[userResourcesObtainedJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        XCTAssertEqual([[[userResourcesObtained objectForKey:@"house"] objectForKey:@"cost"] integerValue], 999);
        
        // Check user resources obtained through the listener
        NSDictionary *userResourcesListenerObtained = [NSJSONSerialization JSONObjectWithData:[userResourcesListenerObtainedJSON dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        XCTAssertEqual([[[userResourcesListenerObtained objectForKey:@"house"] objectForKey:@"cost"] integerValue], 999);
        
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

- (void)testCustomButtonListener {
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        
        // Display IAM to check that the custom button listener works
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.setCustomButtonListener(function(action) { window.testCustomAction = action; });"];
        
        UIViewController *viewController = nil;
        int retries = 10;
        while((viewController == nil || ![viewController isKindOfClass:[SwrveMessageViewController class]]) && retries-- > 0) {
            // Launch IAM campaign
            [self runJS:@"window.plugins.swrve.event('campaign_trigger', undefined, undefined);"];
            [self waitForSeconds:1];
            // Detect view controller
            viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        }
        
        SwrveMessageViewController *iamController = (SwrveMessageViewController*)viewController;
        UIView *messageView = [iamController.view.subviews firstObject];
        UIButton *customButton = [messageView.subviews firstObject];
        [iamController onButtonPressed:customButton];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        [self waitForActionReceivedForJavascript:@"window.testCustomAction" withCallback:^(NSString  *response) {
            BOOL customActionReceived = [response isEqualToString:@"custom_action_from_server"];
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

- (void)testGetUserId {
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        // Inject javascript listeners
        [self runJS:@"window.plugins.swrve.getUserId(function(userId) { window.testUserId = userId; });"];
        
        XCTestExpectation *responseReceived = [self expectationWithDescription:@"responseReceived"];
        
        [self waitForActionReceivedForJavascript:@"window.testUserId" withCallback:^(NSString  *response) {
            [responseReceived fulfill];
            XCTAssert(response != nil);
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
    
    id swrveMock = OCMPartialMock([SwrveSDK sharedInstance]);
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
    [swrveMock stopMocking];
}

- (void)testShowMessageCenterCampaign {
    
    XCTestExpectation *apploaded = [self expectationWithDescription:@"completionHandler"];
    [self waitForApplicationToStart:^(NSString  *callback) {
        
        UIViewController *viewController = nil;
        int retries = 10;
        while((viewController == nil || ![viewController isKindOfClass:[SwrveMessageViewController class]]) && retries-- > 0) {
            // Launch IAM campaign
            [self runJS:@"window.plugins.swrve.showMessageCenterCampaign(123, undefined, undefined);"];
            [self waitForSeconds:1];
            // Detect view controller
            viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        }
        
        XCTAssertTrue([viewController isKindOfClass:[SwrveMessageViewController class]], @"IAM should be appearing on screen");
        
        // press the button and close it
        SwrveMessageViewController *iamController = (SwrveMessageViewController*)viewController;
        UIView *messageView = [iamController.view.subviews firstObject];
        UIButton *customButton = [messageView.subviews firstObject];
        [iamController onButtonPressed:customButton];
        
        [apploaded fulfill];
    }];
    
    // waiting for waitForApplicationToStart & waitForActionReceivedForJavascript
    [self waitForExpectationsWithTimeout:waitLong handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Ran out of time: testShowMessageCenterCampaign");
        }
    }];
}

- (void)testRemoveMessageCenterCampaign {
    
    id swrveMessagingMock = OCMClassMock([SwrveMessageController class]);
    SwrveCampaign *campaignMock = OCMClassMock([SwrveCampaign class]);
    OCMStub([campaignMock ID]).andReturn(44);
    
    NSArray *mockList = [NSArray arrayWithObject:campaignMock];
    OCMExpect([swrveMessagingMock messageCenterCampaigns]).andReturn(mockList);
    OCMExpect([swrveMessagingMock removeMessageCenterCampaign:campaignMock]).andDo(nil);
    
    id swrveMock = OCMPartialMock([SwrveSDK sharedInstance]);
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
    [swrveMock stopMocking];
}

@end
