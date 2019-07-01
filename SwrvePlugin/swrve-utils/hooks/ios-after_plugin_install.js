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

	fs.readFile(appDelegatePath, 'utf8', function(err, data) {
		if (err) {
			return console.log(err);
		}
		if (!data.includes('"SwrvePlugin.h"')) {
			// import SwrvePlugin.
			var updatedAppDelegate = data.replace(
				'#import "AppDelegate.h"',
				'#import "AppDelegate.h"\n#import "SwrvePlugin.h"'
			);

			// insert didFinishLaunchingWithOptions method SwrveSDK init code.
			const didFinishLaunchingWithOptions = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'ios', 'didFinishLaunchingWithOptions.txt')
			);
			updatedAppDelegate = updatedAppDelegate.replace(
				'self.viewController = [[MainViewController alloc] init];',
				'self.viewController = [[MainViewController alloc] init]; \n//<Swrve_didFinishLaunchingWithOptions>'
			);
			updatedAppDelegate = updatedAppDelegate.replace(
				'//<Swrve_didFinishLaunchingWithOptions>',
				didFinishLaunchingWithOptions
			);

			// Set the AppId and API key (if present)
			if (!swrveUtils.isEmptyString(appId)) {
				updatedAppDelegate = updatedAppDelegate.replace('<SwrveAppId>', appId);
			}

			if (!swrveUtils.isEmptyString(apiKey)) {
				updatedAppDelegate = updatedAppDelegate.replace('<SwrveKey>', apiKey);
			}

			// Enable EU Swrve stack (if needed)
			if (!swrveUtils.isEmptyString(swrveStack) && swrveStack === 'EU') {
				updatedAppDelegate = updatedAppDelegate.replace(
					'// config.stack = SWRVE_STACK_EU;',
					'config.stack = SWRVE_STACK_EU;'
				);
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

				if (data.includes(didReceiveRemoteNotification)) {
					// it means that we need to include our integration inside the custumer "didReceiveRemoteNotification" method.
					updatedAppDelegate = updatedAppDelegate.replace(
						didReceiveRemoteNotification,
						`${didReceiveRemoteNotification} \n\n//<Swrve_didReceiveRemoteNotification>`
					);
				} else {
					// otherwise we add all of the method in the end of the file.
					updatedAppDelegate = updatedAppDelegate.replace(
						'@end',
						`${didReceiveRemoteNotification}\n//<Swrve_didReceiveRemoteNotification> \n }\n@end`
					);
				}
				// Add the Swrve_didReceiveRemoteNotification body content.
				updatedAppDelegate = updatedAppDelegate.replace(
					'//<Swrve_didReceiveRemoteNotification>',
					didReceiveRemoteNotificationSwrveImplementation
				);

				// determine if we need to add appGroup information as well as modify pushEnabled
				if (!swrveUtils.isEmptyString(appGroupIdentifier)) {
					updatedAppDelegate = updatedAppDelegate.replace(
						'config.pushEnabled = false;',
						`config.pushEnabled = true; \n    config.appGroupIdentifier = @"${appGroupIdentifier}";`
					);
				} else {
					updatedAppDelegate = updatedAppDelegate.replace(
						'config.pushEnabled = false;',
						'config.pushEnabled = true;'
					);
				}
			}

			// finally, write to the file
			fs.writeFileSync(appDelegatePath, updatedAppDelegate, 'utf-8');
			console.log('Swrve: Successfully added custom Swrve integration into AppDelegate file');
		} else {
			console.log('Swrve: iOS appDelegate already has Swrve Features.');
		}
	});
}
