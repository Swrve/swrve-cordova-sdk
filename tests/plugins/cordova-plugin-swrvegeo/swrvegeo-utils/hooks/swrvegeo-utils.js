const fs = require('fs');

var self = (module.exports = {
	isUsingSwrveGeoHooks: function(appConfig, platform) {
		let arrayOfKeys = [ 'swrve.geoApiKey' ];
		var found = false;
		arrayOfKeys.forEach(function(key) {
			let platformPreference = appConfig.getPlatformPreference(key, platform);
			if (!self.isEmptyString(platformPreference.toString())) {
				found = true;
			}
		});
		return found;
	},

	cordovaAppConfigForContext: function(context) {
		const cordovaCommon = context.requireCordovaModule('cordova-common');
		return new cordovaCommon.ConfigParser('config.xml');
	},

	cordovaPackageNameForPlatform: function(appConfig, platform) {
		// check for the existence of platform-specific id, if it's not there fallback to basic id
		var packageName;

		if (platform == 'ios') {
			packageName = appConfig.ios_CFBundleIdentifier();
		}

		if (platform == 'android') {
			packageName = appConfig.android_packageName();
		}

		if (self.isEmptyString(packageName)) {
			packageName = appConfig.packageName();
		}

		return packageName;
	},

	convertToBoolean: function(str) {
		if (str === undefined) {
			return false;
		}

		let canditateStr = str.toLowerCase();
		return canditateStr == 'true' ? true : false;
	},

	isEmptyString: function(str) {
		return !str || 0 === str.length;
	},
	searchAndReplace: function(filePath, arrayStringToSearch, arrayStringToReplace) {
		if (arrayStringToSearch.length != arrayStringToReplace.length) {
			throw new Error('search/replace array lengths do not match');
		}

		let data = fs.readFileSync(filePath, 'utf8');

		if (self.isEmptyString(data)) {
			throw new Error(`file at ${filePath} is empty`);
		}

		for (var i = 0; i < arrayStringToSearch.length; i++) {
			data = data.replace(arrayStringToSearch[i], arrayStringToReplace[i]);
		}

		fs.writeFileSync(filePath, data, 'utf-8');
	}
});
