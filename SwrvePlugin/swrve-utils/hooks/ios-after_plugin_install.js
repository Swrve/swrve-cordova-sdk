var fs = require('fs'),
	path = require('path'),
	swrveUtils = require('./swrve-utils');
var appConfig;

module.exports = function(context) {
	appConfig = swrveUtils.cordovaAppConfigForContext(context);

	if (!swrveUtils.isUsingSwrveHooks(appConfig, 'ios')) {
		console.log('Swrve: No preferences found for ios platform in config.xml.');
		return;
	}

	iosSetupAppDelegate();
};

function iosSetupAppDelegate() {
	const appName = appConfig.name();
	const appDelegatePath = path.join('platforms', 'ios', appName, 'Classes', 'AppDelegate.m');
	// pull added preferences
	const appId = appConfig.getPlatformPreference('swrve.appId', 'ios');
	const apiKey = appConfig.getPlatformPreference('swrve.apiKey', 'ios');
	const hasPushEnabled = appConfig.getPlatformPreference('swrve.pushEnabled', 'ios');
	const appGroupIdentifier = appConfig.getPlatformPreference('swrve.appGroupIdentifier', 'ios');
	const swrveStack = appConfig.getPlatformPreference('swrve.stack', 'ios');

	var appDelegateData = fs.readFileSync(appDelegatePath, 'utf8');
	if (!appDelegateData.includes('"SwrvePlugin.h"')) {
		// import SwrvePlugin.

		let searchForAppDelegate = [ '#import "AppDelegate.h"' ];
		let replaceWithAppDelegate = [ '#import "AppDelegate.h"\n#import "SwrvePlugin.h"' ];

		searchForAppDelegate.push('self.viewController = [[MainViewController alloc] init];');
		replaceWithAppDelegate.push(
			'self.viewController = [[MainViewController alloc] init]; \n//<Swrve_didFinishLaunchingWithOptions>'
		);

		// insert didFinishLaunchingWithOptions method SwrveSDK init code.
		const didFinishLaunchingWithOptions = fs.readFileSync(
			path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'ios', 'didFinishLaunchingWithOptions.txt')
		);

		searchForAppDelegate.push('//<Swrve_didFinishLaunchingWithOptions>');
		replaceWithAppDelegate.push(didFinishLaunchingWithOptions);

		// Set the AppId and API key (if present)
		if (!swrveUtils.isEmptyString(appId)) {
			searchForAppDelegate.push('<SwrveAppId>');
			replaceWithAppDelegate.push(appId);
		}

		if (!swrveUtils.isEmptyString(apiKey)) {
			searchForAppDelegate.push('<SwrveKey>');
			replaceWithAppDelegate.push(apiKey);
		}

		// Enable EU Swrve stack (if needed)
		if (!swrveUtils.isEmptyString(swrveStack) && swrveStack === 'EU') {
			searchForAppDelegate.push('// config.stack = SWRVE_STACK_EU;');
			replaceWithAppDelegate.push('config.stack = SWRVE_STACK_EU;');
		}

		// check if we need to integrate Push Code.
		if (!swrveUtils.isEmptyString(hasPushEnabled) && swrveUtils.convertToBoolean(hasPushEnabled)) {
			const didReceiveRemoteNotificationSwrveImplementation = fs.readFileSync(
					path.join(
						'plugins',
						'cordova-plugin-swrve',
						'swrve-utils',
						'ios',
						'didReceiveRemoteNotification.txt'
					)
				),
				didReceiveRemoteNotification = `- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {`;

			if (appDelegateData.includes(didReceiveRemoteNotification)) {
				// we need to include our integration inside the custumer "didReceiveRemoteNotification" method.
				searchForAppDelegate.push(didReceiveRemoteNotification);
				replaceWithAppDelegate.push(
					`${didReceiveRemoteNotification} \n\n//<Swrve_didReceiveRemoteNotification>`
				);
			} else {
				searchForAppDelegate.push('@end');
				replaceWithAppDelegate.push(
					`${didReceiveRemoteNotification}\n//<Swrve_didReceiveRemoteNotification> \n }\n@end`
				);
			}

			// Add the Swrve_didReceiveRemoteNotification body content.
			searchForAppDelegate.push('//<Swrve_didReceiveRemoteNotification>');
			replaceWithAppDelegate.push(didReceiveRemoteNotificationSwrveImplementation);

			// determine if we need to add appGroup information as well as modify pushEnabled
			if (!swrveUtils.isEmptyString(appGroupIdentifier)) {
				searchForAppDelegate.push('config.pushEnabled = false;');
				replaceWithAppDelegate.push(
					`config.pushEnabled = true; \n    config.appGroupIdentifier = @"${appGroupIdentifier}";`
				);
			} else {
				searchForAppDelegate.push('config.pushEnabled = false;');
				replaceWithAppDelegate.push('config.pushEnabled = true;');
			}
		}

		// finally, write to the AppDelegate.m
		swrveUtils.searchAndReplace(appDelegatePath, searchForAppDelegate, replaceWithAppDelegate);

		console.log('Swrve: Successfully added custom Swrve integration into AppDelegate file');
	} else {
		console.log('Swrve: iOS appDelegate already has Swrve Features.');
	}
}
