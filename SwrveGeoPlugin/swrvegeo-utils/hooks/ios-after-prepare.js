const fs = require('fs');
const path = require('path');
const xcode = require('xcode');
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
	iosSwrveFrameworkEdit();
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

// Add Build Phase to pull in framework thinning script
function iosSwrveFrameworkEdit() {
	const appName = appConfig.name();
	const iosPath = path.join('platforms', 'ios');
	const projPath = path.join(iosPath, `${appName}.xcodeproj`, 'project.pbxproj');
	const proj = xcode.project(projPath);
	const buildPhaseComment = 'SwrveGeo-Framework-Script';
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
		path.join('plugins', 'cordova-plugin-swrvegeo', 'swrvegeo-utils', 'ios', 'framework-edit-script.txt'),
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
