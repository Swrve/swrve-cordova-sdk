const fs = require('fs');
const {
	modifyApplicationFile
} = require('./plugins/cordova-plugin-swrvegeo/swrvegeo-utils/hooks/swrvegeo-android-integration');

// ---------- modifyApplicationFile -------------
describe('modifyApplicationFile', () => {
	beforeEach(() => {
		fs.appendFileSync(
			'modifyApplicationFileGeo.txt',
			'//<swrve_geo_imports> \n //<swrve_geo_placeholder> \n ',
			'utf-8'
		);
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('modifyApplicationFileGeo.txt');
	});

	test('exists', () => {
		expect(modifyApplicationFile).toBeDefined();
	});

	test('completely modifies Application.java with DelayStart enabled', () => {
		const expectedImports = fs.readFileSync(
			'./plugins/cordova-plugin-swrvegeo/swrvegeo-utils/android/geoImports.txt'
		);

		var testApiKey = 'TEST_KEY';

		modifyApplicationFile('modifyApplicationFileGeo.txt', testApiKey, true);
		const filecontents = fs.readFileSync('modifyApplicationFileGeo.txt', 'utf-8');

		expect(filecontents).toContain(expectedImports);
		expect(filecontents).toContain('SwrveGeoConfig geoConfig = new SwrveGeoConfig();');
		expect(filecontents).toContain('geoConfig.setDelayStart(true);');
		expect(filecontents).toContain(
			`SwrveGeoPlugin.createInstance(this.getApplicationContext(), "${testApiKey}", geoConfig);`
		);
	});

	test('completely modifies Application.java with DelayStart disabled', () => {
		const expectedImports = fs.readFileSync(
			'./plugins/cordova-plugin-swrvegeo/swrvegeo-utils/android/geoImports.txt'
		);

		var testApiKey = 'TEST_KEY';

		modifyApplicationFile('modifyApplicationFileGeo.txt', testApiKey, false);
		const filecontents = fs.readFileSync('modifyApplicationFileGeo.txt', 'utf-8');

		expect(filecontents).toContain(expectedImports);
		expect(filecontents).not.toContain('SwrveGeoConfig geoConfig = new SwrveGeoConfig();');
		expect(filecontents).not.toContain('geoConfig.setDelayStart(true);');
		expect(filecontents).toContain(`SwrveGeoPlugin.createInstance(this.getApplicationContext(), "${testApiKey}");`);
	});

	test('doesnt modify an already modified Application.java', () => {
		fs.writeFileSync('modifyApplicationFileGeo.txt', `import com.swrve.SwrveGeoPlugin;`, 'utf-8');
		modifyApplicationFile('modifyApplicationFileGeo.txt', 'TEST_KEY', false);
		const filecontents = fs.readFileSync('modifyApplicationFileGeo.txt', 'utf-8');

		// Nothing should be changed
		expect(filecontents).toBe(`import com.swrve.SwrveGeoPlugin;`);
	});
});
