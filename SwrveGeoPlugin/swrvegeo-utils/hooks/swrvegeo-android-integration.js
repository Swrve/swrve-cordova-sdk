const fs = require('fs');
const path = require('path');
const swrveUtils = require('./swrvegeo-utils');

var self = (module.exports = {
	modifyApplicationFile: function(applicationPath, geoApiKey, delayStart) {
		var appDelegateData = fs.readFileSync(applicationPath, 'utf8');
		// exit out if we already find SwrveGeoPlugin
		if (appDelegateData.includes('import com.swrve.SwrveGeoPlugin;')) {
			return;
		}

		// manage imports.
		let searchFor = [ '//<swrve_geo_imports>' ];

		var geoImports = fs.readFileSync(
			path.join('plugins', 'cordova-plugin-swrvegeo', 'swrvegeo-utils', 'android', 'geoImports.txt'),
			'utf8'
		);

		let replaceWith = [ `${geoImports}` ];

		// manage initialization code
		searchFor.push('//<swrve_geo_placeholder>');

		if (delayStart) {
			var geoInit = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrvegeo', 'swrvegeo-utils', 'android', 'geoInitWithConfig.txt'),
				'utf8'
			);

			geoInit = geoInit.replace('<SWRVE_GEO_API_KEY>', `${geoApiKey}`);
			replaceWith.push(geoInit);
		} else {
			replaceWith.push(`SwrveGeoPlugin.createInstance(this.getApplicationContext(), "${geoApiKey}");`);
		}

		swrveUtils.searchAndReplace(applicationPath, searchFor, replaceWith);
	},

	produceTargetPathFromPackage: function(targetDirectory, packageName) {
		var packagePath = packageName.replace(/\./g, '/');
		return `${targetDirectory}java/${packagePath}/`;
	}
});
