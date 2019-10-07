const fs = require('fs');
const path = require('path');
const xcode = require('xcode');
const swrveUtils = require('./swrve-utils');
var appConfig;

module.exports = function(context) {
	appConfig = swrveUtils.cordovaAppConfigForContext(context);

	if (!swrveUtils.isUsingSwrveHooks(appConfig, 'ios')) {
		console.log('Swrve: No preferences found for ios platform in config.xml.');
		return;
	}

	let hasPushEnabled = appConfig.getPlatformPreference('swrve.pushEnabled', 'ios');

	if (!swrveUtils.isEmptyString(hasPushEnabled) && swrveUtils.convertToBoolean(hasPushEnabled)) {
		iosSetupServiceExtension();
	}

	iosSwrveFrameworkEdit();
};

function iosSetupServiceExtension() {
	const appGroupIdentifier = appConfig.getPlatformPreference('swrve.appGroupIdentifier', 'ios');
	const appName = appConfig.name();
	const packageName = swrveUtils.cordovaPackageNameForPlatform(appConfig, 'ios');
	const iosPath = 'platforms/ios/';
	const projPath = `${iosPath}${appName}.xcodeproj/project.pbxproj`;
	const extName = 'SwrvePushExtension';
	var extFiles = [ 'NotificationService.h', 'NotificationService.m', `${extName}-Info.plist` ];

	if (!swrveUtils.isEmptyString(appGroupIdentifier)) {
		extFiles.push(`Entitlements-${extName}.plist`);
	}

	// The directory where the source extension files and common are stored
	const sourceDir = `plugins/cordova-plugin-swrve/platforms/ios/${extName}/`;
	const swrveSDKCommonDirectory = path.join(`${appName}`, 'Plugins', 'cordova-plugin-swrve');
	const proj = xcode.project(projPath);
	proj.parseSync();
	let NoServiceExtensionYet = true;

	if (!fs.existsSync(`${iosPath}${extName}`)) {
		console.log(`Adding ${extName} Push Service Extension to ${appName}...`);
		// Copy in the extension files
		fs.mkdirSync(`${iosPath}${extName}`);
	} else {
		NoServiceExtensionYet = false;
		console.log(`Swrve: ${extName} already exists at ${iosPath}`);
	}

	try {
		if (NoServiceExtensionYet) {
			extFiles.map((file) => swrveUtils.copyRecursiveSync(`${sourceDir}${file}`, `${iosPath}${extName}/${file}`));

			// Add a target for the extension
			let extTarget = proj.addTarget(extName, 'app_extension');

			// Create new PBXGroup for the extension
			let extGroup = proj.addPbxGroup(extFiles, extName, extName);

			// Add to PBXGroup under to CustomTemplate so files appear in the file explorer in Xcode
			let groups = proj.hash.project.objects['PBXGroup'];
			Object.keys(groups).forEach(function(key) {
				if (groups[key].name === 'CustomTemplate') {
					proj.addToPbxGroup(extGroup.uuid, key);
				}
			});

			// Add build phases
			proj.addBuildPhase([ 'NotificationService.m' ], 'PBXSourcesBuildPhase', 'Sources', extTarget.uuid);
			proj.addBuildPhase([], 'PBXResourcesBuildPhase', 'Resources', extTarget.uuid);
		}

		// Iterate through the entire XCBuildConfig for config of the new target PRODUCT_NAME and modify it
		var config = proj.hash.project.objects['XCBuildConfiguration'];
		for (var ref in config) {
			if (
				config[ref].buildSettings !== undefined &&
				config[ref].buildSettings.PRODUCT_NAME !== undefined &&
				config[ref].buildSettings.PRODUCT_NAME.includes(extName)
			) {
				console.log(`entered the setting: ${config[ref].buildSettings.PRODUCT_NAME} of ${ref}`);

				var INHERITED = '"$(inherited)"';
				if (
					!config[ref].buildSettings['FRAMEWORK_SEARCH_PATHS'] ||
					config[ref].buildSettings['FRAMEWORK_SEARCH_PATHS'] === INHERITED
				) {
					proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings['FRAMEWORK_SEARCH_PATHS'] = [
						INHERITED
					];
				}

				// Set entitlements
				if (!swrveUtils.isEmptyString(appGroupIdentifier)) {
					proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings[
						'CODE_SIGN_ENTITLEMENTS'
					] = `"$(PROJECT_DIR)/${extName}/Entitlements-${extName}.plist"`;
				}

				// Fix issues with the framework search paths, deployment target and bundle id
				proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings['FRAMEWORK_SEARCH_PATHS'].push(
					`"${swrveSDKCommonDirectory}"`
				);
				proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings['IPHONEOS_DEPLOYMENT_TARGET'] =
					'10.0';

				var currentBundleID =
					proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings['PRODUCT_BUNDLE_IDENTIFIER'];

				if (
					swrveUtils.isEmptyString(currentBundleID) ||
					!currentBundleID.includes(`${packageName}.NotificationService`)
				) {
					proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings[
						'PRODUCT_BUNDLE_IDENTIFIER'
					] = `${packageName}.NotificationService`;
				}

				// ensure code signing identity is pointed correctly
				proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings[
					'CODE_SIGN_IDENTITY'
				] = `"iPhone Distribution"`;

				proj.hash.project.objects['XCBuildConfiguration'][ref].buildSettings['PRODUCT_NAME'] = `${extName}`;
			}
		}

		fs.writeFileSync(projPath, proj.writeSync());
		console.log(`Successfully added ${extName} service extension to ${appName}`);

		// now that everything is setup, modify included files to config.json
		iosSetupServiceExtensionAppGroup();
	} catch (err) {
		console.error(`There was an issue creating the Swrve Service Extension: ${err}`);
	}
}

function iosSetupServiceExtensionAppGroup() {
	const appGroupIdentifier = appConfig.getPlatformPreference('swrve.appGroupIdentifier', 'ios');

	if (!swrveUtils.isEmptyString(appGroupIdentifier)) {
		const notificationServicePath = path.join('platforms', 'ios', 'SwrvePushExtension', 'NotificationService.m');
		const notificationServiceEntitlementsPath = path.join(
			'platforms',
			'ios',
			'SwrvePushExtension',
			'Entitlements-SwrvePushExtension.plist'
		);

		// modify NotificationService.m
		var notificationServiceData = fs.readFileSync(notificationServicePath, 'utf-8');
		if (!notificationServiceData.includes(`withAppGroupIdentifier:@"${appGroupIdentifier}"`)) {
			swrveUtils.searchAndReplace(
				notificationServicePath,
				[ 'withAppGroupIdentifier:nil' ],
				[ `withAppGroupIdentifier:@"${appGroupIdentifier}"` ]
			);
		} else {
			console.log('AppGroup was already inside the NotificationService.m file');
		}

		// modify entitlements file
		var entitlementsData = fs.readFileSync(notificationServiceEntitlementsPath, 'utf-8');
		if (!entitlementsData.includes(`<string>${appGroupIdentifier}</string>`)) {
			swrveUtils.searchAndReplace(
				notificationServiceEntitlementsPath,
				[ '<string>APP_GROUP_TEMP</string>' ],
				[ `<string>${appGroupIdentifier}</string>` ]
			);
		} else {
			console.log('AppGroup was already on the entitlements file');
		}
	} else {
		console.warn('There was no appGroupIdentifier found in config.xml');
	}
}

// Add Build Phase to pull in framework thinning script
function iosSwrveFrameworkEdit() {
	const appName = appConfig.name();
	const iosPath = path.join('platforms', 'ios');
	const projPath = path.join(iosPath, `${appName}.xcodeproj`, 'project.pbxproj');
	const proj = xcode.project(projPath);
	const buildPhaseComment = 'Swrve-Framework-Script';
	proj.parseSync();

	var currentBuildPhases = proj.hash.project.objects['PBXNativeTarget'][proj.getFirstTarget().uuid]['buildPhases'];
	// Iterates through the current xcode Build Phases and checks for the existence of our script
	for (var i = 0; i < currentBuildPhases.length; i++) {
		if (currentBuildPhases[i].comment == buildPhaseComment) {
			console.log(`Swrve: ${buildPhaseComment} is already in Build Phases`);
			return;
		}
	}

	var frameworkEditScript = fs.readFileSync(
		path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'ios', 'framework-edit-script.txt'),
		'utf8'
	);

	var options = {
		shellPath: '/bin/sh',
		shellScript: frameworkEditScript,
		inputPaths: [],
		outputPaths: []
	};
	proj.addBuildPhase([], 'PBXShellScriptBuildPhase', `${buildPhaseComment}`, proj.getFirstTarget().uuid, options);
	fs.writeFileSync(projPath, proj.writeSync());
}
