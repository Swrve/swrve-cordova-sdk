const fs = require('fs');
const path = require('path');
const swrveUtils = require('./swrve-utils');
const swrveIntegration = require('./swrve-android-integration');
const sourceDir = 'plugins/cordova-plugin-swrve/swrve-utils/android/';
const appDirectory = 'platforms/android/app';
const targetDirectory = `${appDirectory}/src/main/`;
const applicationFileName = 'Application.java';
var appConfig;

module.exports = function(context) {
	appConfig = swrveUtils.cordovaAppConfigForContext(context);

	if (!swrveUtils.isUsingSwrveHooks(appConfig, 'android')) {
		console.log('Swrve: No preferences found for android platform in config.xml');
		return;
	}

	let hasPushEnabled = appConfig.getPlatformPreference('swrve.pushEnabled', 'android');

	if (!swrveUtils.isEmptyString(hasPushEnabled) && swrveUtils.convertToBoolean(hasPushEnabled)) {
		androidSetupApplicationFirebase();
	} else {
		androidSetupApplicationWithoutPush();
	}

	// check and apply changes if need into MainActivity file
	androidSetupMainActivity();
};

async function androidSetupApplicationWithoutPush() {
	const packageName = swrveUtils.cordovaPackageNameForPlatform(appConfig, 'android');
	const appName = appConfig.name();
	const appId = appConfig.getPlatformPreference('swrve.appId', 'android');
	const apiKey = appConfig.getPlatformPreference('swrve.apiKey', 'android');
	const initMode = appConfig.getPlatformPreference('swrve.initMode', 'android');
	const managedAuto = appConfig.getPlatformPreference('swrve.managedModeAutoStartLastUser', 'android');
	const swrveStack = appConfig.getPlatformPreference('swrve.stack', 'android');
	var targetApplicationDirectory = swrveIntegration.produceTargetPathFromPackage(targetDirectory, packageName);

	try {
		await produceApplicationFile(targetApplicationDirectory);

		// modify the application file with push disabled
		swrveIntegration.modifyApplicationFile(
			`${targetApplicationDirectory}${applicationFileName}`,
			packageName,
			appName,
			false
		);

		// Enable EU Swrve stack (if needed)
		swrveIntegration.setStackPreferences(`${targetApplicationDirectory}${applicationFileName}`, swrveStack);

		// set the init mode preferences
		swrveIntegration.setInitPreferences(
			`${targetApplicationDirectory}${applicationFileName}`,
			initMode,
			managedAuto
		);

		// set AppIdandApiKey
		swrveUtils.setAppIdAndApiKey(`${targetApplicationDirectory}${applicationFileName}`, appId, apiKey);

		//modify manifest.xml
		const manifestFilePath = path.join('platforms', 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
		swrveIntegration.modifyManifestXML(manifestFilePath, false);
	} catch (err) {
		console.error(err);
	}
}

async function androidSetupApplicationFirebase() {
	const packageName = swrveUtils.cordovaPackageNameForPlatform(appConfig, 'android');
	let appName = appConfig.name();
	let appId = appConfig.getPlatformPreference('swrve.appId', 'android');
	let apiKey = appConfig.getPlatformPreference('swrve.apiKey', 'android');
	const initMode = appConfig.getPlatformPreference('swrve.initMode', 'android');
	const managedAuto = appConfig.getPlatformPreference('swrve.managedModeAutoStartLastUser', 'android');
	let swrveStack = appConfig.getPlatformPreference('swrve.stack', 'android');
	let drawableDirectory = appConfig.getPlatformPreference('swrve.drawablePath', 'android');
	let googleServicesPath = appConfig.getPlatformPreference('swrve.googleServicesPath', 'android');
	let googleServicesVersion = appConfig.getPlatformPreference('swrve.googleServicesVersion', 'android');
	var targetApplicationDirectory = swrveIntegration.produceTargetPathFromPackage(targetDirectory, packageName);

	try {
		await produceApplicationFile(targetApplicationDirectory);

		swrveIntegration.modifyApplicationFile(
			`${targetApplicationDirectory}${applicationFileName}`,
			packageName,
			appName,
			true
		);

		// Enable EU Swrve stack (if needed)
		swrveIntegration.setStackPreferences(`${targetApplicationDirectory}${applicationFileName}`, swrveStack);

		// set the init mode preferences
		swrveIntegration.setInitPreferences(
			`${targetApplicationDirectory}${applicationFileName}`,
			initMode,
			managedAuto
		);

		// modify the changed Application.java
		swrveUtils.setAppIdAndApiKey(`${targetApplicationDirectory}${applicationFileName}`, appId, apiKey);

		// Manifest.xml
		const manifestFilePath = path.join('platforms', 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
		swrveIntegration.modifyManifestXML(manifestFilePath, true);

		// these are required image assets for notifications
		var drawableFiles = [ 'icon.png', 'material_icon.png' ];
		// Copy Drawable images for the Notifications
		swrveIntegration.copyDrawableNotificationsImages(drawableDirectory, targetDirectory, drawableFiles);

		if (!swrveUtils.isEmptyString(googleServicesPath)) {
			// copy their google-services.json file to the app root directory
			swrveUtils.copyRecursiveSync(googleServicesPath, `${appDirectory}/google-services.json`);
		} else {
			console.warn(
				'Swrve: for android push you must include path to google-services.json in config.xml under "swrve.googleServicesPath"'
			);
		}

		// Modifies the app/build.gradle file to include google-services (as required by firebase)
		const gradleRootFilePath = path.join('platforms', 'android', 'app', 'build.gradle');

		if (!swrveUtils.isEmptyString(googleServicesVersion)) {
			swrveIntegration.modifyGradleFile(gradleRootFilePath, googleServicesVersion);
		} else {
			swrveIntegration.modifyGradleFile(gradleRootFilePath, '4.2.0');
		}
	} catch (err) {
		console.error(`Swrve: Something went wrong during Android Setup Application ${err}`);
	}
}

async function produceApplicationFile(path) {
	if (!fs.existsSync(`${path}${applicationFileName}`)) {
		fs.copyFileSync(`${sourceDir}${applicationFileName}`, `${path}${applicationFileName}`);
		console.log(`Swrve: Added ${applicationFileName} to ${path} directory`);
	} else {
		console.log(`Swrve: ${applicationFileName} already exists at ${path}`);
	}
}

function androidSetupMainActivity() {
	const packageName = swrveUtils.cordovaPackageNameForPlatform(appConfig, 'android');
	var targetApplicationDirectory = swrveIntegration.produceTargetPathFromPackage(targetDirectory, packageName);
	const hasAdJourneyEnabled = appConfig.getPlatformPreference('swrve.adJourneyEnabled', 'android');

	// check if we need to integrate adJourney handler code into MainActivity
	if (!swrveUtils.isEmptyString(hasAdJourneyEnabled) && swrveUtils.convertToBoolean(hasAdJourneyEnabled)) {
		console.log('Swrve: has AdJourney LinksEnabled for Android, it will inject the ad journey code for Android');

		const mainActivityPath = targetApplicationDirectory + '/MainActivity.java';
		swrveIntegration.setAdJourney(mainActivityPath);
	}
}
