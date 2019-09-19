const fs = require('fs');
const {
	modifyApplicationFile,
	setStackPreferences,
	produceTargetPathFromPackage,
	modifyManifestXML,
	modifyGradleFile,
	setAdJourney,
	copyDrawableNotificationsImages
} = require('./plugins/cordova-plugin-swrve/swrve-utils/hooks/swrve-android-integration');

// ---------- modifyApplicationFile -------------
describe('modifyApplicationFile', () => {
	beforeEach(() => {
		fs.appendFileSync(
			'modifyApplicationFile.txt',
			'package <PACKAGE_NAME> \n //<swrve_application_imports> \n //<swrve_application_content>\n',
			'utf-8'
		);
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('modifyApplicationFile.txt');
	});

	test('exists', () => {
		expect(modifyApplicationFile).toBeDefined();
	});

	test('completely modifies Application with push disabled', () => {
		const expectedModifications = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/ApplicationWithoutPush.txt'
		);

		//targetApplicationPath, packageName, appName, pushEnabled
		modifyApplicationFile('modifyApplicationFile.txt', 'com.swrve.test.modapp', undefined, false);
		const filecontents = fs.readFileSync('modifyApplicationFile.txt', 'utf-8');

		expect(filecontents).toContain('package com.swrve.test.modapp;');
		expect(filecontents).toContain(expectedModifications);
	});

	test('completely modifies Application With push enabled and app name', () => {
		// check if the right init code was added
		const expectedImports = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/ApplicationPushImports.txt'
		);

		//targetApplicationPath, packageName, appName, pushEnabled
		modifyApplicationFile('modifyApplicationFile.txt', 'com.swrve.test.modapp', 'testName', true);
		const filecontents = fs.readFileSync('modifyApplicationFile.txt', 'utf-8');

		expect(filecontents).toContain('package com.swrve.test.modapp;');
		expect(filecontents).toContain(expectedImports);
		expect(filecontents).toContain(
			'new NotificationChannel("123", "testName default channel", NotificationManager.IMPORTANCE_DEFAULT);'
		);
	});

	test('completely modifies Application with push enabled and no app name', () => {
		// check if the right init code was added
		const expectedImports = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/ApplicationPushImports.txt'
		);

		const expectedModifications = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/ApplicationWithPush.txt'
		);

		//targetApplicationPath, packageName, appName, pushEnabled
		modifyApplicationFile('modifyApplicationFile.txt', 'com.swrve.test.modapp', undefined, true);
		const filecontents = fs.readFileSync('modifyApplicationFile.txt', 'utf-8');

		expect(filecontents).toContain('package com.swrve.test.modapp;');
		expect(filecontents).toContain(expectedImports);
		expect(filecontents).toContain(expectedModifications);
	});
});

// ---------- setStackPreferences -------------
describe('setStackPreferences', () => {
	beforeEach(() => {
		fs.appendFileSync('setStackPreferences_android.txt', '// config.setSelectedStack(SwrveStack.EU);', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('setStackPreferences_android.txt');
	});

	test('exists', () => {
		expect(setStackPreferences).toBeDefined();
	});

	test('sets EU if stack is EU', () => {
		setStackPreferences('setStackPreferences_android.txt', 'EU');

		const filecontents = fs.readFileSync('setStackPreferences_android.txt', 'utf-8');
		expect(filecontents).toBe('config.setSelectedStack(SwrveStack.EU);');
	});

	test('leaves EU commented out if stack is anything else', () => {
		setStackPreferences('setStackPreferences_android.txt', 'ELSE');

		const filecontents = fs.readFileSync('setStackPreferences_android.txt', 'utf-8');
		expect(filecontents).toBe('// config.setSelectedStack(SwrveStack.EU);');
	});

	test('leaves EU commented out if stack is empty', () => {
		setStackPreferences('setStackPreferences_android.txt', undefined);

		const filecontents = fs.readFileSync('setStackPreferences_android.txt', 'utf-8');
		expect(filecontents).toBe('// config.setSelectedStack(SwrveStack.EU);');
	});
});

// ---------- produceTargetPathFromPackage -------------
describe('produceTargetPathFromPackage', () => {
	test('exists', () => {
		expect(produceTargetPathFromPackage).toBeDefined();
	});

	test('can break down a package name to a path', () => {
		var resultPath = produceTargetPathFromPackage('test/path/', 'com.package.swrve.testproject');
		expect(resultPath).toBe('test/path/java/com/package/swrve/testproject/');
	});

	test('will only parse . delimited packages', () => {
		var resultPath = produceTargetPathFromPackage('test/path/', 'com.package.swrve?testproject');
		expect(resultPath).toBe('test/path/java/com/package/swrve?testproject/');
	});
});

// ---------- modifyManifestXML -------------
describe('modifyManifestXML', () => {
	beforeEach(() => {
		fs.appendFileSync('modifyManifestXML.txt', 'android:supportsRtl="true" \n </activity>', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('modifyManifestXML.txt');
	});

	test('exists', () => {
		expect(modifyManifestXML).toBeDefined();
	});

	test('completely modifies Manifest.xml with push enabled', () => {
		const expectedModifications = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/FirebasePushManifest.txt'
		);

		modifyManifestXML('modifyManifestXML.txt', true);
		const filecontents = fs.readFileSync('modifyManifestXML.txt', 'utf-8');
		expect(filecontents).toContain('android:name=".Application" android:supportsRtl="true"');
		expect(filecontents).toContain(expectedModifications);
	});

	test('completely modifies Manifest.xml with push disabled', () => {
		const expectedModifications = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/FirebasePushManifest.txt'
		);

		modifyManifestXML('modifyManifestXML.txt', false);
		const filecontents = fs.readFileSync('modifyManifestXML.txt', 'utf-8');
		expect(filecontents).toContain('android:name=".Application" android:supportsRtl="true"');
		expect(filecontents).not.toContain(expectedModifications);
	});

	test('does nothing if Manifest.xml is already edited (push enabled)', () => {
		// change contents of modifyManifestXML.txt
		fs.writeFileSync('modifyManifestXML.txt', 'com.swrve.sdk.SwrveFirebaseMessagingService', 'utf-8');
		modifyManifestXML('modifyManifestXML.txt', true);

		const filecontents = fs.readFileSync('modifyManifestXML.txt', 'utf-8');
		// no changes should have occured
		expect(filecontents).toBe('com.swrve.sdk.SwrveFirebaseMessagingService');
	});

	test('does nothing if Manifest.xml is already edited (push disabled)', () => {
		// change contents of modifyManifestXML.txt
		fs.writeFileSync('modifyManifestXML.txt', 'android:name=".Application"', 'utf-8');
		modifyManifestXML('modifyManifestXML.txt', false);

		const filecontents = fs.readFileSync('modifyManifestXML.txt', 'utf-8');
		// no changes should have occured
		expect(filecontents).toBe('android:name=".Application"');
	});
});

// ---------- modifyGradleFile -------------
describe('modifyGradleFile', () => {
	beforeEach(() => {
		fs.appendFileSync('modifyGradleFile.txt', '    dependencies {', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('modifyGradleFile.txt');
	});

	test('exists', () => {
		expect(modifyGradleFile).toBeDefined();
	});

	test('completely modifies gradle file with version set', () => {
		modifyGradleFile('modifyGradleFile.txt', '3.2.0');
		const filecontents = fs.readFileSync('modifyGradleFile.txt', 'utf-8');
		expect(filecontents).toContain(`    dependencies { \n     classpath 'com.google.gms:google-services:3.2.0'`);
	});

	test('does nothing if google services is already set', () => {
		// write the change into the file already
		fs.writeFileSync('modifyGradleFile.txt', 'com.google.gms.google-services', 'utf-8');

		modifyGradleFile('modifyGradleFile.txt', '4.2.0');
		const filecontents = fs.readFileSync('modifyGradleFile.txt', 'utf-8');
		// no changes should have occured
		expect(filecontents).toBe('com.google.gms.google-services');
	});

	test('does nothing if version is not passed', () => {
		// write the change into the file already
		fs.writeFileSync('modifyGradleFile.txt', 'com.google.gms.google-services', 'utf-8');

		modifyGradleFile('modifyGradleFile.txt', undefined);
		const filecontents = fs.readFileSync('modifyGradleFile.txt', 'utf-8');
		// no changes should have occured
		expect(filecontents).toBe('com.google.gms.google-services');
	});
});

// ---------- setAdJourney -------------
describe('setAdJourney', () => {
	beforeEach(() => {
		// create a file with all entry points necessary to test SetAdJourney
		fs.appendFileSync(
			'setAdJourney_test.txt',
			'import android.os.Bundle; super.onCreate(savedInstanceState); public class MainActivity extends CordovaActivity\n{',
			'utf-8'
		);
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('setAdJourney_test.txt');
	});

	test('exists', () => {
		expect(setAdJourney).toBeDefined();
	});

	test('Check ad journey code injection for imports', () => {
		setAdJourney('setAdJourney_test.txt');
		const filecontents = fs.readFileSync('setAdJourney_test.txt', 'utf-8');

		expect(filecontents).toContain(
			'import android.os.Bundle;\nimport android.content.Intent;\nimport com.swrve.SwrvePlugin;\n'
		);
	});

	test('Check ad journey code injection for adJourneyHandlerOnNewIntentCreate file', () => {
		setAdJourney('setAdJourney_test.txt');
		const filecontents = fs.readFileSync('setAdJourney_test.txt', 'utf-8');

		// check if the adJourneyHandlerOnNewIntentCreate was injected.
		const expectedAdJourneyHandlerOnNewIntentCreateCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/adJourneyHandlerOnNewIntentCreate.txt'
		);

		expect(filecontents).toContain(expectedAdJourneyHandlerOnNewIntentCreateCode);
	});

	test('Check ad journey code injection for adJourneyHandlerOnNewIntentCreate file', () => {
		setAdJourney('setAdJourney_test.txt');
		const filecontents = fs.readFileSync('setAdJourney_test.txt', 'utf-8');

		// check if the adJourneyHandlerDeeplinks was injected.
		const expectedadJourneyHandlerDeeplinksCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/android/adJourneyHandlerDeeplinks.txt'
		);

		expect(filecontents).toContain(expectedadJourneyHandlerDeeplinksCode);
	});
});

// ---------- copyDrawableNotificationsImages -------------
describe('copyDrawableNotificationsImages', () => {
	var drawableFiles = [ 'icon.png', 'material_icon.png' ];

	beforeAll(() => {
		fs.mkdirSync('./res');
	});

	beforeEach(() => {});

	afterEach(() => {
		// remove items from this test
		fs.unlinkSync('./res/drawable/icon.png');
		fs.unlinkSync('./res/drawable/material_icon.png');
		fs.rmdirSync('./res/drawable');
	});

	afterAll(() => {
		fs.rmdirSync('./res');
	});

	test('check copy with path with "/" on the final of drawable path', () => {
		copyDrawableNotificationsImages('./platform_test_files/android/drawable/', '.', drawableFiles);
		const filecontentsIconOriginal = fs.readFileSync('./platform_test_files/android/drawable/icon.png', 'utf-8');
		const filecontentsIconCopied = fs.readFileSync('./res/drawable/icon.png', 'utf-8');

		// Check if the files get copied
		expect(filecontentsIconCopied).toBe(filecontentsIconOriginal);
	});

	test('check copy with path without "/" on the final of drawable path', () => {
		copyDrawableNotificationsImages('./platform_test_files/android/drawable', '.', drawableFiles);
		const filecontentsIconOriginal = fs.readFileSync('./platform_test_files/android/drawable/icon.png', 'utf-8');
		const filecontentsIconCopied = fs.readFileSync('./res/drawable/icon.png', 'utf-8');

		// Check if the files get copied
		expect(filecontentsIconCopied).toBe(filecontentsIconOriginal);
	});

	test('check copy with drawable folder already exist', () => {
		fs.mkdirSync('./res/drawable');
		copyDrawableNotificationsImages('./platform_test_files/android/drawable', '.', drawableFiles);
		const filecontentsIconOriginal = fs.readFileSync('./platform_test_files/android/drawable/icon.png', 'utf-8');
		const filecontentsIconCopied = fs.readFileSync('./res/drawable/icon.png', 'utf-8');

		// Check if the files get copied
		expect(filecontentsIconCopied).toBe(filecontentsIconOriginal);
	});
});
