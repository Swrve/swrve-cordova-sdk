const fs = require('fs');

module.exports = {
	searchAndReplace: function(fileUrl, arrayStringToSearch, arrayStringToReplace, fileUrldestination) {
		if (arrayStringToSearch.length != arrayStringToReplace.length) {
			return console.log(`arrayStringToSearch and arrayStringToReplace should be same size.`);
		}

		fs.readFile(fileUrl, 'utf8', function(err, data) {
			if (err) {
				console.log('file not found');
				return console.log(err);
			}

			for (var i = 0; i < arrayStringToSearch.length; i++) {
				const stringToSearch = arrayStringToSearch[i],
					stringToReplace = arrayStringToReplace[i];
				data = data.replace(stringToSearch, stringToReplace);
			}
			if (fileUrldestination == undefined) {
				fileUrldestination = fileUrl;
			}
			fs.writeFile(fileUrldestination, data, 'utf8', function(err) {
				if (err) return console.log(err);
			});
		});
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
			if (platformPreference != undefined) {
				found = true;
			}
		});
		return found;
	}
};
