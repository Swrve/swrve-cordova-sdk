const fs = require('fs');

const {
	modifyAppDelegate
} = require('./plugins/cordova-plugin-swrvegeo/swrvegeo-utils/hooks/swrvegeo-ios-integration');

// ---------- modifyAppDelegate -------------
describe('modifyAppDelegate', () => {
	beforeEach(() => {
		fs.appendFileSync('modifyAppDelegateGeo.txt', '#import "SwrvePlugin.h" \n // <Swrve_geo_placeholder>', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('modifyAppDelegateGeo.txt');
	});

	test('exists', () => {
		expect(modifyAppDelegate).toBeDefined();
	});

	test('completely modifies AppDelegate with DelayStart enabled', () => {
		var testApiKey = 'TEST_KEY';

		modifyAppDelegate('modifyAppDelegateGeo.txt', testApiKey, true);

		const filecontents = fs.readFileSync('modifyAppDelegateGeo.txt', 'utf-8');

		expect(filecontents).toContain('#import "SwrvePlugin.h"\n#import "SwrveGeoPlugin.h"');
		expect(filecontents).toContain('SwrveGeoConfig *geoConfig = [[SwrveGeoConfig alloc] init];');
		expect(filecontents).toContain('[geoConfig setDelayStart:YES];');
		expect(filecontents).toContain(`[SwrveGeoPlugin initWithApiKey:@"${testApiKey}" config:geoConfig];`);
	});

	test('completely modifies AppDelegate with DelayStart disabled', () => {
		var testApiKey = 'TEST_KEY';

		modifyAppDelegate('modifyAppDelegateGeo.txt', testApiKey, false);

		const filecontents = fs.readFileSync('modifyAppDelegateGeo.txt', 'utf-8');

		expect(filecontents).toContain('#import "SwrvePlugin.h"\n#import "SwrveGeoPlugin.h"');
		expect(filecontents).not.toContain('SwrveGeoConfig *geoConfig = [[SwrveGeoConfig alloc] init];');
		expect(filecontents).not.toContain('[geoConfig setDelayStart:YES];');
		expect(filecontents).toContain(`[SwrveGeoPlugin initWithApiKey:@"${testApiKey}"];`);
	});

	test('doesnt modify an already modified AppDelegate', () => {
		fs.writeFileSync('modifyAppDelegateGeo.txt', `#import "SwrveGeoPlugin.h"`, 'utf-8');
		modifyAppDelegate('modifyAppDelegateGeo.txt', 'TEST_KEY', false);
		const filecontents = fs.readFileSync('modifyAppDelegateGeo.txt', 'utf-8');

		// Nothing should be changed
		expect(filecontents).toBe(`#import "SwrveGeoPlugin.h"`);
	});
});
