const fs = require('fs');

var self = (module.exports = {
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
	},

	copyFileFrom: function(fileUrl, destination) {
		fs.readFile(fileUrl, 'utf8', function(err, data) {
			if (err) {
				console.log('file not found');
				return console.log(err);
			}
			// save file into destination
			fs.writeFile(destination, data, 'utf8', function(err) {
				if (err) return console.log(err);
			});
		});
	},

	cordovaAppConfigForContext: function(context) {
		const cordovaCommon = context.requireCordovaModule('cordova-common');
		return new cordovaCommon.ConfigParser('config.xml');
	},

	isUsingSwrveHooks: function(appConfig, platform) {
		// Common properties between all platform
		let arrayOfKeys = [ 'swrve.appId', 'swrve.apiKey', 'swrve.pushEnabled' ];
		var found = false;
		arrayOfKeys.forEach(function(key) {
			let platformPreference = appConfig.getPlatformPreference(key, platform);
			if (!self.isEmptyString(platformPreference.toString())) {
				found = true;
			}
		});
		return found;
	},

	isEmptyString: function(str) {
		return !str || 0 === str.length;
	},

	convertToBoolean: function(str) {
		if (str === undefined) {
			return false;
		}

		let canditateStr = str.toLowerCase();
		return canditateStr == 'true' ? true : false;
	}
});
