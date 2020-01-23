var fs = require('fs'),
	path = require('path'),
	swrveUtils = require('./swrve-utils'),
	swrveIntegration = require('./swrve-ios-integration');
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
	const initMode = appConfig.getPlatformPreference('swrve.initMode', 'ios');
	const managedAuto = appConfig.getPlatformPreference('swrve.managedModeAutoStartLastUser', 'ios');
	const hasAdJourneyEnabled = appConfig.getPlatformPreference('swrve.adJourneyEnabled', 'ios');
	const hasAdJourneyProcessOtherLinksEnabled = appConfig.getPlatformPreference(
		'swrve.adJourneyProcessOtherLinksEnabled',
		'ios'
	);

	const hasPushEnabled = appConfig.getPlatformPreference('swrve.pushEnabled', 'ios');
	const appGroupIdentifier = appConfig.getPlatformPreference('swrve.appGroupIdentifier', 'ios');
	const pushNotificationEvent = appConfig.getPlatformPreference('swrve.pushNotificationEvent', 'ios');
	const provisionalPushNotificationEvent = appConfig.getPlatformPreference(
		'swrve.provisionalPushNotificationEvent',
		'ios'
	);
	const swrveStack = appConfig.getPlatformPreference('swrve.stack', 'ios');
	const clearPushBadgeOnStartup = appConfig.getPlatformPreference('swrve.clearPushBadgeOnStartup', 'ios');

	// returns 'true' if the appDelegate had to be modified
	var needsModification = swrveIntegration.modifyAppDelegate(appDelegatePath);

	if (needsModification) {
		// set the correct native stack
		swrveIntegration.setStackPreferences(appDelegatePath, swrveStack);

		// set the init mode preferences
		swrveIntegration.setInitPreferences(appDelegatePath, initMode, managedAuto);

		// set appId and ApiKey
		swrveUtils.setAppIdAndApiKey(appDelegatePath, appId, apiKey);

		// check if we need to integrate Push Code.
		if (!swrveUtils.isEmptyString(hasPushEnabled) && swrveUtils.convertToBoolean(hasPushEnabled)) {
			swrveIntegration.setPushCapabilities(
				appDelegatePath,
				appGroupIdentifier,
				swrveUtils.convertToBoolean(clearPushBadgeOnStartup)
			);

			// if pushEnabled is set to true, we should try processing provisional events
			swrveIntegration.setPushNotificationEvents(
				appDelegatePath,
				pushNotificationEvent,
				provisionalPushNotificationEvent
			);
		}

		// check if we need to integrate adJourney handler code into App Delegate
		if (!swrveUtils.isEmptyString(hasAdJourneyEnabled) && swrveUtils.convertToBoolean(hasAdJourneyEnabled)) {
			swrveIntegration.setAdJourney(appDelegatePath, hasAdJourneyProcessOtherLinksEnabled);
		}

		console.log('Swrve: Successfully added custom Swrve integration into AppDelegate file');
	} else {
		console.log('Swrve: iOS appDelegate already has Swrve Features.');
	}
}
