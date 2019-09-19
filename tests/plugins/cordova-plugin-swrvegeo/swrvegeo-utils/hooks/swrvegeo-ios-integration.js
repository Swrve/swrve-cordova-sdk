const fs = require('fs');
const path = require('path');
const swrveUtils = require('./swrvegeo-utils');

var self = (module.exports = {
	modifyAppDelegate: function(delegatePath, geoApiKey, delayStart) {
		var appDelegateData = fs.readFileSync(delegatePath, 'utf8');
		// exit out if we already find SwrveGeoPlugin
		if (appDelegateData.includes('"SwrveGeoPlugin.h"')) {
			return false;
		}

		// import SwrveGeoPlugin.
		let searchFor = [ '#import "SwrvePlugin.h"' ];
		let replaceWith = [ '#import "SwrvePlugin.h"\n#import "SwrveGeoPlugin.h"' ];

		searchFor.push('// <Swrve_geo_placeholder>');

		if (delayStart) {
			var geoInit = fs.readFileSync(
				path.join('plugins', 'cordova-plugin-swrvegeo', 'swrvegeo-utils', 'ios', 'geoInitWithConfig.txt'),
				'utf8'
			);

			geoInit = geoInit.replace('<SWRVE_GEO_API_KEY>', `${geoApiKey}`);
			replaceWith.push(geoInit);
		} else {
			replaceWith.push(`[SwrveGeoPlugin initWithApiKey:@"${geoApiKey}"];`);
		}

		// write search / replace to the AppDelegate.m
		swrveUtils.searchAndReplace(delegatePath, searchFor, replaceWith);
	}
});
