/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

//
//  AppDelegate.m
//  UnitTests
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  Copyright ___ORGANIZATIONNAME___ ___YEAR___. All rights reserved.
//

#import "AppDelegate.h"
#import "SwrvePlugin.h"
#import "MainViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self.viewController = [[MainViewController alloc] init];
    
    /****************** SWRVE CHANGES ******************/
    // Point to local http server since this project is purely for testing purposes
    SwrveConfig *config = [[SwrveConfig alloc] init];
    config.pushEnabled = YES;
    config.eventsServer = @"http://localhost:8083";
    config.contentServer = @"http://localhost:8085";
    // Set your app id and api key here
    [SwrvePlugin initWithAppID:1111 apiKey:@"fake_api_key" config:config viewController:self.viewController];
    /****************** END OF CHANGES ******************/
    
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    BOOL handled = [SwrvePlugin application:application didReceiveRemoteNotification:userInfo withBackgroundCompletionHandler:^ (UIBackgroundFetchResult fetchResult, NSDictionary *swrvePayload) {
        // NOTE: Do not call the Swrve SDK from this context
        // Your code here to process a Swrve remote push and payload
        completionHandler(fetchResult);
    }];
    if (!handled) {
        // Your code here, it is either a non-background push received in the background or a non-Swrve remote push
        // You’ll have to process the payload on your own and call the completionHandler as normal
    }
}

@end
