const fs = require('fs');
const path = require('path');
const util = require('util'); // requires Node 8.16+
const swrveUtils = require('./swrve-utils');
const sourceDir = 'plugins/cordova-plugin-swrve/swrve-utils/android/';
const appDirectory = 'platforms/android/app';
const targetDirectory = `${appDirectory}/src/main/`;
const copyFilePromisify = util.promisify(fs.copyFile);
const applicationFileName = 'Application.java';
var appConfig;

module.exports = function(context) {
	appConfig = swrveUtils.cordovaAppConfigForContext(context);

	if (!swrveUtils.isUsingSwrveHooks(appConfig, 'android')) {
		console.log('Swrve: No preferences found for android platform in config.xml');
		return;
	}

	const hasPushEnabled = appConfig.getPlatformPreference('swrve.pushEnabled', 'android');

	if (hasPushEnabled != undefined && hasPushEnabled) {
		androidSetupApplicationFirebase();
	} else {
		androidSetupApplicationWithoutPush();
	}
};

async function androidSetupApplicationWithoutPush() {
	const packageName = appConfig.packageName();
	const appId = appConfig.getPlatformPreference('swrve.appId', 'android');
	const apiKey = appConfig.getPlatformPreference('swrve.apiKey', 'android');
	const swrveStack = appConfig.getPlatformPreference('swrve.stack', 'android');
	var targetApplicationDirectory = produceTargetPathFromPackage(packageName);

	try {
		await produceApplicationFile(targetApplicationDirectory);

		fs.readFile(`${targetApplicationDirectory}${applicationFileName}`, 'utf8', function(err, data) {
			if (err) {
				return console.log(err);
			}

			// set the Application.java package to match the config package name
			var applicationJava = data.replace('package <PACKAGE_NAME>', `package ${packageName};`);

			// Add Swrve init code
			var applicationWithoutPush = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'ApplicationWithoutPush.txt')
			);
			applicationJava = applicationJava.replace('//<swrve_application_content>', applicationWithoutPush);

			// Set the AppId and API key (if present)
			if (appId != undefined) {
				applicationJava = applicationJava.replace('<SwrveAppId>', appId);
			}

			if (apiKey != undefined) {
				applicationJava = applicationJava.replace('<SwrveKey>', apiKey);
			}

			// Enable EU Swrve stack (if needed)
			if (swrveStack != undefined && swrveStack === 'EU') {
				applicationJava = applicationJava.replace(
					'// config.setSelectedStack(SwrveStack.EU);',
					'config.setSelectedStack(SwrveStack.EU);'
				);
			}

			// finally, write to the file
			fs.writeFileSync(`${targetApplicationDirectory}${applicationFileName}`, applicationJava, 'utf-8');
		});

		//modify manifest.xml
		const manifestFilePath = path.join('platforms', 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
		fs.readFile(manifestFilePath, 'utf8', function(err, data) {
			if (err) {
				return console.log(err);
			}

			if (!data.includes('android:name=".Application"')) {
				var modfiedManifest = data.replace(
					'android:supportsRtl="true">',
					'android:name=".Application" android:supportsRtl="true">'
				);
				fs.writeFileSync(manifestFilePath, modfiedManifest, 'utf-8');
			} else {
				console.log('Swrve: Manifest.xml already has .Application added to it');
			}
		});
	} catch (err) {
		console.error(err);
	}
}

async function androidSetupApplicationFirebase() {
	const packageName = appConfig.packageName();
	let appName = appConfig.name();
	let appId = appConfig.getPlatformPreference('swrve.appId', 'android');
	let apiKey = appConfig.getPlatformPreference('swrve.apiKey', 'android');
	let swrveStack = appConfig.getPlatformPreference('swrve.stack', 'android');
	let drawableDirectory = appConfig.getPlatformPreference('swrve.drawablePath', 'android');
	let googleServicesPath = appConfig.getPlatformPreference('swrve.googleServicesPath', 'android');
	var targetApplicationDirectory = produceTargetPathFromPackage(packageName);

	try {
		await produceApplicationFile(targetApplicationDirectory);

		fs.readFile(`${targetApplicationDirectory}${applicationFileName}`, 'utf8', function(err, data) {
			if (err) {
				return console.log(err);
			}

			// set the Application.java package to match the config package name
			var applicationJava = data.replace('package <PACKAGE_NAME>', `package ${packageName};`);
			var applicationImports = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'ApplicationPushImports.txt')
			);
			applicationJava = applicationJava.replace('//<swrve_application_imports>', applicationImports);

			// Add Swrve init code
			var applicationWithPush = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'ApplicationWithPush.txt')
			);
			applicationJava = applicationJava.replace('//<swrve_application_content>', applicationWithPush);

			// Set the AppId and API key (if present)
			if (appId != undefined) {
				applicationJava = applicationJava.replace('<SwrveAppId>', appId);
			}

			if (apiKey != undefined) {
				applicationJava = applicationJava.replace('<SwrveKey>', apiKey);
			}

			if (appName != undefined) {
				applicationJava = applicationJava.replace('<APPLICATION_NAME>', `${appName}`);
			}

			// Enable EU Swrve stack (if needed)
			if (swrveStack != undefined && swrveStack === 'EU') {
				applicationJava = applicationJava.replace(
					'// config.setSelectedStack(SwrveStack.EU);',
					'config.setSelectedStack(SwrveStack.EU);'
				);
			}

			// finally, write to the file
			fs.writeFileSync(`${targetApplicationDirectory}${applicationFileName}`, applicationJava, 'utf-8');
		});

		//modify manifest.xml
		const manifestFilePath = path.join('platforms', 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
		fs.readFile(manifestFilePath, 'utf8', function(err, data) {
			if (err) {
				return console.log(err);
			}

			if (!data.includes('com.swrve.sdk.SwrveFirebaseMessagingService')) {
				var firebasePushManifest = fs.readFileSync(
					path.join('plugins', 'cordova-plugin-swrve', 'swrve-utils', 'android', 'FirebasePushManifest.txt')
				);
				var modfiedManifest = data.replace(
					'android:supportsRtl="true">',
					'android:name=".Application" android:supportsRtl="true">'
				);
				modfiedManifest = modfiedManifest.replace('</activity>', firebasePushManifest);
				fs.writeFileSync(manifestFilePath, modfiedManifest, 'utf-8');
			} else {
				console.log('Swrve: Manifest.xml already has .Application added to it');
			}
		});

		// Copy in the extension files
		fs.mkdirSync(`${targetDirectory}/res/drawable`);

		// these are required image assets for notifications
		var drawableFiles = [ 'icon.png', 'material_icon.png' ];

		if (drawableDirectory != undefined) {
			// ensure we have an '/' at the end of the path
			if (drawableDirectory.substr(drawableDirectory.length - 1) != `/`) {
				drawableDirectory = drawableDirectory + '/';
			}

			// using a promise to ensure all files finished copying before moving on
			await Promise.all(
				drawableFiles.map((file) =>
					copyFilePromisify(`${drawableDirectory}${file}`, `${targetDirectory}/res/drawable/${file}`)
				)
			);
		} else {
			console.warn(
				'Swrve: for android push you must include a drawable path in config.xml under "swrve.drawablePath"'
			);
		}

		if (googleServicesPath != undefined) {
			// copy their google-services.json file to the app root directory
			await copyFilePromisify(googleServicesPath, `${appDirectory}/google-services.json`);
		} else {
			console.warn(
				'Swrve: for android push you must include path to google-services.json in config.xml under "swrve.googleServicesPath"'
			);
		}

		// Modifies the app/build.gradle file to include google-services (as required by firebase)
		const gradleRootFilePath = path.join('platforms', 'android', 'app', 'build.gradle');
		fs.readFile(gradleRootFilePath, 'utf8', function(err, data) {
			if (err) {
				return console.log(err);
			}

			if (!data.includes('com.google.gms.google-services')) {
				var modifiedBuildGradle = data + "\napply plugin: 'com.google.gms.google-services'";
				modifiedBuildGradle = modifiedBuildGradle.replace(
					'    dependencies {',
					"    dependencies { \n     classpath 'com.google.gms:google-services:4.2.0'"
				);
				fs.writeFileSync(gradleRootFilePath, modifiedBuildGradle, 'utf-8');
			} else {
				console.log('Swrve: build.gradle already has google-services added to it');
			}
		});
	} catch (err) {
		console.error(err);
	}
}

function produceTargetPathFromPackage(packageName) {
	// create targetApplicationDirectory
	var packagePath = packageName.replace(/\./g, '/');
	return `${targetDirectory}java/${packagePath}/`;
}

async function produceApplicationFile(path) {
	if (!fs.existsSync(`${path}${applicationFileName}`)) {
		// using a promise to ensure all files finished copying before moving on
		await copyFilePromisify(`${sourceDir}${applicationFileName}`, `${path}${applicationFileName}`);
		console.log(`Swrve: Added ${applicationFileName} to ${path} directory`);
	} else {
		console.log(`Swrve: ${applicationFileName} already exists at ${path}`);
	}
}
