const fs = require('fs');
const path = require('path');
const { execSync } = require("child_process");
const swrveUtils = require('./swrve-utils');
var appConfig;

module.exports = function(context) {
	appConfig = swrveUtils.cordovaAppConfigForContext(context);

	if (!swrveUtils.isUsingSwrveHooks(appConfig, 'ios')) {
		console.log('Swrve: No preferences found for ios platform in config.xml.');
		return;
	}

	let hasPushEnabled = appConfig.getPlatformPreference('swrve.pushEnabled', 'ios');

    // Need to ensure that we have the latest pods installed for the Service Extension target
	if (!swrveUtils.isEmptyString(hasPushEnabled) && swrveUtils.convertToBoolean(hasPushEnabled)) {
		iosSwrvePerformPodInstall();
	}
};

function iosSwrvePerformPodInstall () {
	const iosPath = path.join('platforms', 'ios');
	console.log(`Swrve: performing pod install on iOS path: ${iosPath}`);
	execSync(`cd ${iosPath} && pod install --verbose`);
}