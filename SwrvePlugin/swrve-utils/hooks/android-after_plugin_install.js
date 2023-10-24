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

	// Add custom properties into gradle.properties file
	androidSetupGradleProperties();
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
	let handlingGoogleServices = appConfig.getPlatformPreference('swrve.handlingGoogleServices', 'android');
	let googleServicesPath = appConfig.getPlatformPreference('swrve.googleServicesPath', 'android');
	var targetApplicationDirectory = swrveIntegration.produceTargetPathFromPackage(targetDirectory, packageName);
	const pushNotificationPermissionEvent = appConfig.getPlatformPreference('swrve.pushNotificationPermissionEvent', 'android');

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
		if(swrveUtils.isEmptyString(handlingGoogleServices) || swrveUtils.convertToBoolean(handlingGoogleServices) == false) {
			console.log(`Swrve: swrve.handlingGoogleServices is blank/false so adding SwrveFirebaseMessagingService.`);
			swrveIntegration.modifyManifestXML(manifestFilePath, true);
		} else {
			console.log(`Swrve: swrve.handlingGoogleServices is true so Firebase Messages must be forwarded in code to Swrve.`);
			swrveIntegration.modifyManifestXML(manifestFilePath, false);
		}

		// these are required image assets for notifications
		var drawableFiles = [ 'icon.png', 'material_icon.png' ];
		// Copy Drawable images for the Notifications
		swrveIntegration.copyDrawableNotificationsImages(drawableDirectory, targetDirectory, drawableFiles);
		
		// if handlingGoogleServices isn't present or it's set to false. proceed
		if(swrveUtils.isEmptyString(handlingGoogleServices) || swrveUtils.convertToBoolean(handlingGoogleServices) == false) {
			if (!swrveUtils.isEmptyString(googleServicesPath)) {
				// copy their google-services.json file to the app root directory
				swrveUtils.copyRecursiveSync(googleServicesPath, `${appDirectory}/google-services.json`);
			} else {
				console.warn(
					'Swrve: for android push you must include path to google-services.json in config.xml under "swrve.googleServicesPath"'
				);
			}
		} else {
			console.log(`Swrve: swrve.handlingGoogleServices is true so google-services needs to be added.`);
		}

		swrveIntegration.pushNotificationPermissionEvent(`${targetApplicationDirectory}${applicationFileName}`, pushNotificationPermissionEvent);
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

function androidSetupGradleProperties() {
	// Modifies the app gradle.properties file to include properties bellow
	// enableJetifier and useAndroidX are both properties necessary for Swrve Compatibility because our current Swrve native SDK use AndroidX.
	// more info at https://developer.android.com/jetpack/androidx

	let customSwrveRequiredProperties = ["android.enableJetifier=true", "android.useAndroidX=true"];
	let gradlePropertiesFilePath = path.join('platforms', 'android', 'gradle.properties');
	swrveIntegration.modifyGradlePropertiesFile(gradlePropertiesFilePath, customSwrveRequiredProperties);
}
