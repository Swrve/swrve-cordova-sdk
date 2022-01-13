const fs = require('fs');
const path = require('path');
const swrveUtils = require('./swrve-utils');

var self = (module.exports = {
	modifyAppDelegate: function(delegatePath) {
		var appDelegateData = fs.readFileSync(delegatePath, 'utf8');

		// exit out if we already find swrve
		if (appDelegateData.includes('"SwrvePlugin.h"')) {
			return false;
		}

		// import SwrvePlugin.
		let searchFor = [ '#import "AppDelegate.h"' ];
		let replaceWith = [ '#import "AppDelegate.h"\n#import "SwrvePlugin.h"' ];

		searchFor.push('self.viewController = [[MainViewController alloc] init];');
		replaceWith.push(
			'self.viewController = [[MainViewController alloc] init]; \n//<Swrve_didFinishLaunchingWithOptions>'
		);

		// insert didFinishLaunchingWithOptions method SwrveSDK init code.
		const didFinishLaunchingWithOptions = fs.readFileSync(
			path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'ios', 'didFinishLaunchingWithOptions.txt')
		);

		searchFor.push('//<Swrve_didFinishLaunchingWithOptions>');
		replaceWith.push(didFinishLaunchingWithOptions);

		// write search / replace to the AppDelegate.m
		swrveUtils.searchAndReplace(delegatePath, searchFor, replaceWith);

		return true;
	},

	setStackPreferences: function(delegatePath, swrveStack) {
		let searchFor = [];
		let replaceWith = [];

		// Enable EU Swrve stack (if needed)
		if (!swrveUtils.isEmptyString(swrveStack) && swrveStack === 'EU') {
			searchFor.push('// config.stack = SWRVE_STACK_EU;');
			replaceWith.push('config.stack = SWRVE_STACK_EU;');
		}

		swrveUtils.searchAndReplace(delegatePath, searchFor, replaceWith);
	},

	setInitPreferences: function(delegatePath, initMode, autoStart) {
		let searchFor = [];
		let replaceWith = [];

		// Enable Managed Mode if not empty
		if (!swrveUtils.isEmptyString(initMode) && initMode === 'MANAGED') {
			searchFor.push('SwrveConfig *config = [[SwrveConfig alloc] init];');
			replaceWith.push(
				'SwrveConfig *config = [[SwrveConfig alloc] init]; \n config.initMode = SWRVE_INIT_MODE_MANAGED; \n'
			);

			if (!swrveUtils.isEmptyString(autoStart)) {
				var isAddingManagedSetting = swrveUtils.convertToBoolean(autoStart);

				// we only need to modify the appDelegate if it's false, so we check here.
				if (!isAddingManagedSetting) {
					searchFor.push('config.initMode = SWRVE_INIT_MODE_MANAGED;');
					replaceWith.push(
						'config.initMode = SWRVE_INIT_MODE_MANAGED; \n config.managedModeAutoStartLastUser = NO;'
					);
				}
			}
		}

		swrveUtils.searchAndReplace(delegatePath, searchFor, replaceWith);
	},

	setPushCapabilities: function(delegatePath, appGroupIdentifier,autoCollectDeviceToken, clearPushBadgeOnStartup ) {
		let searchFor = [];
		let replaceWith = [];
		// Read in the required data for edits
		var appDelegateData = fs.readFileSync(delegatePath, 'utf8');
		const didReceiveRemoteNotificationSwrveImplementation = fs.readFileSync(
			path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'ios', 'didReceiveRemoteNotification.txt')
		);
		const didReceiveRemoteNotification = `- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {`;

		if (appDelegateData.includes(didReceiveRemoteNotification)) {
			searchFor.push(didReceiveRemoteNotification);
			replaceWith.push(`${didReceiveRemoteNotification} \n\n//<Swrve_didReceiveRemoteNotification>`);
		} else {
			searchFor.push('@end');
			replaceWith.push(`${didReceiveRemoteNotification}\n//<Swrve_didReceiveRemoteNotification> \n }\n@end`);
		}

		// Add the Swrve_didReceiveRemoteNotification body content.
		searchFor.push('//<Swrve_didReceiveRemoteNotification>');
		replaceWith.push(didReceiveRemoteNotificationSwrveImplementation);

		// determine if we need to add appGroup information as well as modify pushEnabled
		if (!swrveUtils.isEmptyString(appGroupIdentifier)) {
			searchFor.push('config.pushEnabled = false;');
			replaceWith.push(`config.pushEnabled = true; \n    config.appGroupIdentifier = @"${appGroupIdentifier}";`);
		} else {
			searchFor.push('config.pushEnabled = false;');
			replaceWith.push('config.pushEnabled = true;');
		}

		if (clearPushBadgeOnStartup) {
			searchFor.push('config.pushEnabled = true;');
			replaceWith.push(
				`config.pushEnabled = true; \n    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;`
			);
		}

		if (!autoCollectDeviceToken) {
			searchFor.push('config.pushEnabled = true;');
			replaceWith.push(
				`config.pushEnabled = true; \n    config.autoCollectDeviceToken = false;`
			);
		}

		swrveUtils.searchAndReplace(delegatePath, searchFor, replaceWith);
	},

	setPushNotificationEvents: function(delegatePath, event, provisionalEvent) {
		let searchFor = [];
		let replaceWith = [];

		// Set the push event (if present)
		if (!swrveUtils.isEmptyString(event)) {
			let nativePushEventsLine = `config.pushEnabled = true; \n    config.pushNotificationEvents = [NSSet setWithObject:@"${event}"];`;
			searchFor.push('config.pushEnabled = true;');
			replaceWith.push(nativePushEventsLine);

			// Provisional Event should only be set if there's a standard event present
			if (!swrveUtils.isEmptyString(provisionalEvent)) {
				let nativeProvisionalAddition = `${nativePushEventsLine} \n    config.provisionalPushNotificationEvents = [NSSet setWithObject:@"${provisionalEvent}"];`;
				searchFor.push(nativePushEventsLine);
				replaceWith.push(nativeProvisionalAddition);
			}
		}
		swrveUtils.searchAndReplace(delegatePath, searchFor, replaceWith);
	},

	setAdJourney: function(delegatePath, hasAdJourneyProcessOtherLinksEnabled) {
		let searchFor = [];
		let replaceWith = [];
		let adJourneyFileName;

		// Check with integration need to be integrated
		if (hasAdJourneyProcessOtherLinksEnabled) {
			adJourneyFileName = 'adJourneyHandlerSwrveAndOthersDeeplinks.txt';
			console.log('Swrve: Integrated ad journey with option 2: Process other deeplinks in addition to Swrve');
		} else {
			adJourneyFileName = 'adJourneyHandlerSwrveDeeplinks.txt';
			console.log('Swrve: Integrated ad journey with option 1: Process Swrve deeplinks only');
		}

		// insert ajJourney custom code method SwrveSDK init code.
		const adJourneyFileData = fs.readFileSync(
			path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'ios', adJourneyFileName)
		);
		searchFor.push('// <Swrve_adJourney>');
		replaceWith.push(adJourneyFileData);

		// insert ajJourney to deeplink handler to handle when a customer has already installed the app
		const adJourneyInstalledFileData = fs.readFileSync(
			path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'ios', `adJourneyDeeplinkHandler.txt`)
		);

		searchFor.push('@end');
		replaceWith.push(adJourneyInstalledFileData + '\n @end');

		swrveUtils.searchAndReplace(delegatePath, searchFor, replaceWith);
	}
});
