const fs = require('fs');
const path = require('path');
const swrveUtils = require('./swrve-utils');

var self = (module.exports = {
	modifyApplicationFile: function(targetApplicationPath, packageName, appName, pushEnabled) {
		let searchfor = [ 'package <PACKAGE_NAME>' ];
		let replacewith = [ `package ${packageName};` ];

		if (pushEnabled) {
			var applicationImports = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'ApplicationPushImports.txt')
			);

			// Start with adding the appropriate push imports to Application.java
			searchfor.push('//<swrve_application_imports>');
			replacewith.push(applicationImports);

			// Add Swrve init code
			var applicationWithPush = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'ApplicationWithPush.txt')
			);

			searchfor.push('//<swrve_application_content>');
			replacewith.push(applicationWithPush);

			if (!swrveUtils.isEmptyString(appName)) {
				searchfor.push('<APPLICATION_NAME>');
				replacewith.push(`${appName}`);
			}
		} else {
			/** Push Not Enabled */
			var applicationWithoutPush = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'ApplicationWithoutPush.txt')
			);
			searchfor.push('//<swrve_application_content>');
			replacewith.push(applicationWithoutPush);
		}

		// Finally, write all of it to Application.java
		swrveUtils.searchAndReplace(targetApplicationPath, searchfor, replacewith);
	},

	setStackPreferences: function(applicationPath, swrveStack) {
		let searchFor = [];
		let replaceWith = [];

		// Enable EU Swrve stack (if needed)
		if (!swrveUtils.isEmptyString(swrveStack) && swrveStack === 'EU') {
			searchFor.push('// config.setSelectedStack(SwrveStack.EU);');
			replaceWith.push('config.setSelectedStack(SwrveStack.EU);');
		}

		swrveUtils.searchAndReplace(applicationPath, searchFor, replaceWith);
	},

	setInitPreferences: function(applicationPath, initMode, autoStart) {
		let searchFor = [];
		let replaceWith = [];

		// Enable Managed Mode if not empty and set to managed, otherwise it's default
		if (!swrveUtils.isEmptyString(initMode) && initMode === 'MANAGED') {
			searchFor.push('SwrveConfig config = new SwrveConfig();');
			replaceWith.push(
				'SwrveConfig config = new SwrveConfig(); \n    config.setInitMode(SwrveInitMode.MANAGED); \n'
			);

			if (!swrveUtils.isEmptyString(autoStart)) {
				var isAddingManagedSetting = swrveUtils.convertToBoolean(autoStart);

				// we only need to modify the application file if it's false, so we check here.
				if (!isAddingManagedSetting) {
					searchFor.push('config.setInitMode(SwrveInitMode.MANAGED);');
					replaceWith.push(
						'config.setInitMode(SwrveInitMode.MANAGED); \n   config.setManagedModeAutoStartLastUser(false); \n'
					);
				}
			}
		}

		swrveUtils.searchAndReplace(applicationPath, searchFor, replaceWith);
	},

	produceTargetPathFromPackage: function(targetDirectory, packageName) {
		var packagePath = packageName.replace(/\./g, '/');
		return `${targetDirectory}java/${packagePath}/`;
	},

	modifyManifestXML(manifestFilePath, pushEnabled) {
		var manifestData = fs.readFileSync(manifestFilePath, 'utf8');

		if (pushEnabled) {
			if (!manifestData.includes('com.swrve.sdk.SwrveFirebaseMessagingService')) {
				let searchForManifest = [ 'android:supportsRtl="true"' ];
				let replaceWithManifest = [ 'android:name=".Application" android:supportsRtl="true"' ];

				// Add MessagingServices
				var firebasePushManifest = fs.readFileSync(
					path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'FirebasePushManifest.txt')
				);

				searchForManifest.push('</activity>');
				replaceWithManifest.push(firebasePushManifest);

				// Finally, write all of it to the Manifest.xml
				swrveUtils.searchAndReplace(manifestFilePath, searchForManifest, replaceWithManifest);
			} else {
				console.log('Swrve: Manifest.xml already has MessagingServices added to it');
			}
		} else {
			/** Push Not Enabled */
			if (!manifestData.includes('android:name=".Application"')) {
				swrveUtils.searchAndReplace(
					manifestFilePath,
					[ 'android:supportsRtl="true"' ],
					[ 'android:name=".Application" android:supportsRtl="true"' ]
				);
			} else {
				console.log('Swrve: Manifest.xml already has .Application added to it');
			}
		}
	},

	modifyGradleFile(gradleRootFilePath, googleServicesVersion) {
		var data = fs.readFileSync(gradleRootFilePath, 'utf8');
		if (!data.includes('com.google.gms.google-services') && !swrveUtils.isEmptyString(googleServicesVersion)) {
			var modifiedBuildGradle = data + "\napply plugin: 'com.google.gms.google-services'";
			modifiedBuildGradle = modifiedBuildGradle.replace(
				'    dependencies {',
				`    dependencies { \n     classpath 'com.google.gms:google-services:${googleServicesVersion}'`
			);
			fs.writeFileSync(gradleRootFilePath, modifiedBuildGradle, 'utf-8');
		} else {
			console.log('Swrve: build.gradle already has google-services added to it');
		}
	},

	setAdJourney: function(mainActivityPath) {
		let searchFor = [];
		let replaceWith = [];

		// Add imports at top of the file:
		searchFor.push('import android.os.Bundle;');
		replaceWith.push('import android.os.Bundle;\nimport android.content.Intent;\nimport com.swrve.SwrvePlugin;\n');

		// injection code for onCreate method.
		searchFor.push('super.onCreate(savedInstanceState);');
		// insert ajJourney custom code method SwrveSDK init code.
		const adJourneyFileOnCreateData = fs.readFileSync(
			path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'adJourneyHandlerDeeplinks.txt')
		);
		replaceWith.push('super.onCreate(savedInstanceState);\n' + adJourneyFileOnCreateData);

		// insert ajJourney custom code for OnNewIntent.
		const adJourneyHandlerOnNewIntenttData = fs.readFileSync(
			path.join(
				'plugins',
				'cordova-plugin-swrve',
				'swrve-utils',
				'android',
				'adJourneyHandlerOnNewIntentCreate.txt'
			)
		);

		// use the "public class MainActivity extends CordovaActivity" as entry point for adJourneyHandlerOnNewIntenttData.txt injection.
		searchFor.push('public class MainActivity extends CordovaActivity\n{');
		replaceWith.push('public class MainActivity extends CordovaActivity\n{\n' + adJourneyHandlerOnNewIntenttData);

		// do Ad Journey MainActivity file changes
		swrveUtils.searchAndReplace(mainActivityPath, searchFor, replaceWith);
	},

	copyDrawableNotificationsImages: function(drawableDirectory, targetDirectory, drawableFiles) {
		// Copy in the extension files
		// these are required image assets for notifications
		var drawableFiles = [ 'icon.png', 'material_icon.png' ];
		if (!swrveUtils.isEmptyString(drawableDirectory)) {
			// ensure we have an '/' at the end of the path
			if (drawableDirectory.substr(drawableDirectory.length - 1) != `/`) {
				drawableDirectory = drawableDirectory + '/';
			}
			// Check if the folder already exist, if not we create it.
			if (!fs.existsSync(`${targetDirectory}/res/drawable`)) {
				fs.mkdirSync(`${targetDirectory}/res/drawable`);
			}
			drawableFiles.map((file) =>
				swrveUtils.copyRecursiveSync(`${drawableDirectory}${file}`, `${targetDirectory}/res/drawable/${file}`)
			);
		} else {
			console.warn(
				'Swrve: for android push you must include a drawable path in config.xml under "swrve.drawablePath"'
			);
		}
	}
});
