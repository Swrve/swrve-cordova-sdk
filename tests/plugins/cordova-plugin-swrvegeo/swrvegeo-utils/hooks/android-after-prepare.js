const swrveIntegration = require('./swrvegeo-android-integration');
const swrveUtils = require('./swrvegeo-utils');

const appDirectory = 'platforms/android/app';
const targetDirectory = `${appDirectory}/src/main/`;
const applicationFileName = 'Application.java';
var appConfig;

module.exports = function(context) {
	appConfig = swrveUtils.cordovaAppConfigForContext(context);

	if (!swrveUtils.isUsingSwrveGeoHooks(appConfig, 'android')) {
		console.log('Swrve: No Geo preferences found for android platform in config.xml.');
		return;
	}

	addGeoToProject();
};

function addGeoToProject() {
	const appName = appConfig.name();
	const packageName = swrveUtils.cordovaPackageNameForPlatform(appConfig, 'android');
	var targetApplicationDirectory = swrveIntegration.produceTargetPathFromPackage(targetDirectory, packageName);
	console.log(`Swrve: Adding Geo Integration to Android Project - ${appName}`);

	const geoApiKey = appConfig.getPlatformPreference('swrve.geoApiKey', 'android');
	const geoDelayStart = appConfig.getPlatformPreference('swrve.geoDelayStart', 'android');

	swrveIntegration.modifyApplicationFile(
		`${targetApplicationDirectory}${applicationFileName}`,
		geoApiKey,
		swrveUtils.convertToBoolean(geoDelayStart)
	);
}
