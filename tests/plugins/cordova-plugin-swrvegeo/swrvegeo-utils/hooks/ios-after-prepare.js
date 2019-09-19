const path = require('path');
const swrveIntegration = require('./swrvegeo-ios-integration');
const swrveUtils = require('./swrvegeo-utils');
var appConfig;

module.exports = function(context) {
	appConfig = swrveUtils.cordovaAppConfigForContext(context);

	if (!swrveUtils.isUsingSwrveGeoHooks(appConfig, 'ios')) {
		console.log('Swrve: No Geo preferences found for ios platform in config.xml.');
		return;
	}

	addGeoToProject();
};

function addGeoToProject() {
	const appName = appConfig.name();
	console.log(`Swrve: Adding Geo Integration to iOS Project - ${appName}`);

	// Modify AppDelegate to use SwrveGeoPlugin
	const appDelegatePath = path.join('platforms', 'ios', appName, 'Classes', 'AppDelegate.m');
	const geoApiKey = appConfig.getPlatformPreference('swrve.geoApiKey', 'ios');
	const geoDelayStart = appConfig.getPlatformPreference('swrve.geoDelayStart', 'ios');

	swrveIntegration.modifyAppDelegate(appDelegatePath, geoApiKey, swrveUtils.convertToBoolean(geoDelayStart));
}
