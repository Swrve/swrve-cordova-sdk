const fs = require('fs');

const {
	modifyAppDelegate,
	setInitPreferences,
	setStackPreferences,
	setPushCapabilities,
	setPushNotificationEvents,
	setAdJourney
} = require('./plugins/cordova-plugin-swrve/swrve-utils/hooks/swrve-ios-integration');

// ---------- modifyAppDelegate -------------
describe('modifyAppDelegate', () => {
	beforeEach(() => {
		fs.appendFileSync(
			'delegate.txt',
			'#import "AppDelegate.h" \n self.viewController = [[MainViewController alloc] init];',
			'utf-8'
		);
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('delegate.txt');
	});

	test('exists', () => {
		expect(modifyAppDelegate).toBeDefined();
	});

	test('adds everything from the boilerplate file if there is no SwrvePlugin', () => {
		var hasModifed = modifyAppDelegate('delegate.txt');
		const filecontents = fs.readFileSync('delegate.txt', 'utf-8');

		// check if the right init code was added
		const expectedLaunchOptions = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/ios/didFinishLaunchingWithOptions.txt'
		);

		expect(hasModifed).toBe(true);
		expect(filecontents).toContain('#import "AppDelegate.h"\n#import "SwrvePlugin.h"');
		expect(filecontents).toContain(expectedLaunchOptions);
	});

	test('returns false and doesnt edit when its already modified', () => {
		// add the SwrvePlugin import which suggests it's already edited
		fs.writeFileSync('delegate.txt', `"SwrvePlugin.h"`, 'utf-8');

		var hasModifed = modifyAppDelegate('delegate.txt');
		const filecontents = fs.readFileSync('delegate.txt', 'utf-8');

		expect(hasModifed).toBe(false);
		// file should be unmodified
		expect(filecontents).toBe('"SwrvePlugin.h"');
	});
});

// ---------- setStackPreferences -------------
describe('setStackPreferences', () => {
	beforeEach(() => {
		fs.appendFileSync('stack.txt', '// config.stack = SWRVE_STACK_EU;', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('stack.txt');
	});

	test('exists', () => {
		expect(setStackPreferences).toBeDefined();
	});

	test('sets EU if stack is EU', () => {
		setStackPreferences('stack.txt', 'EU');

		const filecontents = fs.readFileSync('stack.txt', 'utf-8');
		expect(filecontents).toBe('config.stack = SWRVE_STACK_EU;');
	});

	test('leaves EU commented out if stack is anything else', () => {
		setStackPreferences('stack.txt', 'ELSE');

		const filecontents = fs.readFileSync('stack.txt', 'utf-8');
		expect(filecontents).toBe('// config.stack = SWRVE_STACK_EU;');
	});

	test('leaves EU commented out if stack is empty', () => {
		setStackPreferences('stack.txt', undefined);

		const filecontents = fs.readFileSync('stack.txt', 'utf-8');
		expect(filecontents).toBe('// config.stack = SWRVE_STACK_EU;');
	});
});

// ---------- setInitPreferences -------------
describe('setInitPreferences', () => {
	beforeEach(() => {
		fs.appendFileSync('initPreferences_iOS.txt', 'SwrveConfig *config = [[SwrveConfig alloc] init];', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('initPreferences_iOS.txt');
	});

	test('exists', () => {
		expect(setInitPreferences).toBeDefined();
	});

	test('sets MANAGED if MANAGED is passed in', () => {
		setInitPreferences('initPreferences_iOS.txt', 'MANAGED', '');

		const filecontents = fs.readFileSync('initPreferences_iOS.txt', 'utf-8');
		expect(filecontents).toContain('SwrveConfig *config = [[SwrveConfig alloc] init];');
		expect(filecontents).toContain('config.initMode = SWRVE_INIT_MODE_MANAGED;');
		expect(filecontents).not.toContain('config.autoStartLastUser = NO;');
	});

	test('sets MANAGED if MANAGED is passed in and not add the extra line if autoStart is true', () => {
		setInitPreferences('initPreferences_iOS.txt', 'MANAGED', 'true');

		const filecontents = fs.readFileSync('initPreferences_iOS.txt', 'utf-8');
		expect(filecontents).toContain('SwrveConfig *config = [[SwrveConfig alloc] init];');
		expect(filecontents).toContain('config.initMode = SWRVE_INIT_MODE_MANAGED;');
		expect(filecontents).not.toContain('config.autoStartLastUser = NO;');
	});

	test('sets MANAGED and AutoStart', () => {
		setInitPreferences('initPreferences_iOS.txt', 'MANAGED', 'false');
		const filecontents = fs.readFileSync('initPreferences_iOS.txt', 'utf-8');
		expect(filecontents).toContain('SwrveConfig *config = [[SwrveConfig alloc] init];');
		expect(filecontents).toContain('config.initMode = SWRVE_INIT_MODE_MANAGED;');
		expect(filecontents).toContain('config.autoStartLastUser = NO;');
	});

	test('sets nothing else if MANAGED isnt present', () => {
		setInitPreferences('initPreferences_iOS.txt', '', 'false');
		const filecontents = fs.readFileSync('initPreferences_iOS.txt', 'utf-8');
		expect(filecontents).toBe('SwrveConfig *config = [[SwrveConfig alloc] init];');
	});
});

// ---------- setPushCapabilities -------------
describe('setPushCapabilities', () => {
	beforeEach(() => {
		fs.appendFileSync('setPushCapabilities.txt', 'config.pushEnabled = false;\n @end', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('setPushCapabilities.txt');
	});

	test('exists', () => {
		expect(setPushCapabilities).toBeDefined();
	});

	test('sets everything with appGroup and badge removal', () => {
		setPushCapabilities('setPushCapabilities.txt', 'appGroupId', true);
		const filecontents = fs.readFileSync('setPushCapabilities.txt', 'utf-8');

		// check if didFinishLaunchingWithOptions would get the appropriate edit
		expect(filecontents).toContain('config.pushEnabled = true;');
		expect(filecontents).toContain('[UIApplication sharedApplication].applicationIconBadgeNumber = 0;');
		expect(filecontents).toContain('config.appGroupIdentifier = @"appGroupId";');

		// check if the remote function is added as well
		var expectedReceiveCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/ios/didReceiveRemoteNotification.txt'
		);

		expect(filecontents).toContain(expectedReceiveCode);
	});

	test('sets everything with appGroup and no badge removeal', () => {
		setPushCapabilities('setPushCapabilities.txt', 'appGroupId', false);
		const filecontents = fs.readFileSync('setPushCapabilities.txt', 'utf-8');

		// check if didFinishLaunchingWithOptions would get the appropriate edit
		expect(filecontents).toContain('config.pushEnabled = true;');
		expect(filecontents).not.toContain('[UIApplication sharedApplication].applicationIconBadgeNumber = 0;');
		expect(filecontents).toContain('config.appGroupIdentifier = @"appGroupId";');

		// check if the remote function is added as well
		var expectedReceiveCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/ios/didReceiveRemoteNotification.txt'
		);

		expect(filecontents).toContain(expectedReceiveCode);
	});

	test('ignores appGroup logic if it isnt set', () => {
		setPushCapabilities('setPushCapabilities.txt', undefined, false);
		const filecontents = fs.readFileSync('setPushCapabilities.txt', 'utf-8');
		expect(filecontents).toContain('config.pushEnabled = true;');
		expect(filecontents).not.toContain('config.appGroupIdentifier = @"appGroupId";');
	});

	test('ignores adding remoteNotificationFunction if its already there', () => {
		const didReceiveRemoteNotification = `- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {`;

		// add token which suggests that the RemoteNotification Function is already there
		fs.writeFileSync(
			'setPushCapabilities.txt',
			`config.pushEnabled = false; \n ${didReceiveRemoteNotification} @end`,
			'utf-8'
		);

		setPushCapabilities('setPushCapabilities.txt', 'appGroupId', true);
		const filecontents = fs.readFileSync('setPushCapabilities.txt', 'utf-8');

		// check if didFinishLaunchingWithOptions would still get the appropriate edit
		expect(filecontents).toContain('config.pushEnabled = true;');
		expect(filecontents).toContain('[UIApplication sharedApplication].applicationIconBadgeNumber = 0;');
		expect(filecontents).toContain('config.appGroupIdentifier = @"appGroupId";');

		// check if the remote function will always be injected
		var expectedReceiveCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/ios/didReceiveRemoteNotification.txt'
		);

		expect(filecontents).toContain(expectedReceiveCode);
	});
});

// ---------- setPushNotficationEvents -------------
describe('setPushNotificationEvents', () => {
	beforeEach(() => {
		fs.appendFileSync('notfication_events_test.txt', 'config.pushEnabled = true;', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('notfication_events_test.txt');
	});

	test('exists', () => {
		expect(setPushNotificationEvents).toBeDefined();
	});

	test('updates push notification event without provisional', () => {
		setPushNotificationEvents('notfication_events_test.txt', 'test_event', null);

		const filecontents = fs.readFileSync('notfication_events_test.txt', 'utf-8');
		expect(filecontents).toBe(
			'config.pushEnabled = true; \n    config.pushNotificationEvents = [NSSet setWithObject:@"test_event"];'
		);
	});

	test('updates push notification event with provisional', () => {
		setPushNotificationEvents('notfication_events_test.txt', 'test_event', 'test_provisional');

		const filecontents = fs.readFileSync('notfication_events_test.txt', 'utf-8');
		expect(filecontents).toBe(
			'config.pushEnabled = true; \n    config.pushNotificationEvents = [NSSet setWithObject:@"test_event"]; \n    config.provisionalPushNotificationEvents = [NSSet setWithObject:@"test_provisional"];'
		);
	});

	test('doesnt update when there is no event', () => {
		setPushNotificationEvents('notfication_events_test.txt', null, 'test_provisional');

		const filecontents = fs.readFileSync('notfication_events_test.txt', 'utf-8');
		expect(filecontents).toBe('config.pushEnabled = true;'); // there should be no change
	});
});

// ---------- setAdJourney -------------
describe('setAdJourney', () => {
	beforeEach(() => {
		fs.appendFileSync('setAdJourney_test.txt', '// <Swrve_adJourney> @end', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('setAdJourney_test.txt');
	});

	test('exists', () => {
		expect(setAdJourney).toBeDefined();
	});

	test('Check Ad Journey integration option 1', () => {
		setAdJourney('setAdJourney_test.txt', false);

		const filecontents = fs.readFileSync('setAdJourney_test.txt', 'utf-8');

		// check if the adJourneyHandlerSwrveDeeplinks was injected.
		const expectedAdJourneyCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/ios/adJourneyHandlerSwrveDeeplinks.txt'
		);

		expect(filecontents).toContain('Option 1: Process Swrve deeplinks only');
		expect(filecontents).toContain(expectedAdJourneyCode);
	});

	test('Check Ad Journey integration option 2', () => {
		setAdJourney('setAdJourney_test.txt', true);

		const filecontents = fs.readFileSync('setAdJourney_test.txt', 'utf-8');

		// check if the adJourneyHandlerSwrveAndOthersDeeplinks was injected.
		const expectedAdJourneyCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/ios/adJourneyHandlerSwrveAndOthersDeeplinks.txt'
		);

		expect(filecontents).toContain('Option 2: Process other deeplinks in addition to Swrve');
		expect(filecontents).toContain(expectedAdJourneyCode);
	});

	test('Check ad journey deeplink handler injection', () => {
		setAdJourney('setAdJourney_test.txt', false);

		const filecontents = fs.readFileSync('setAdJourney_test.txt', 'utf-8');

		// check if the adJourneyDeeplinkHandler was injected.
		const expectedAdJourneyCode = fs.readFileSync(
			'./plugins/cordova-plugin-swrve/swrve-utils/ios/adJourneyDeeplinkHandler.txt'
		);

		expect(filecontents).toContain(
			'- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options'
		);
		expect(filecontents).toContain(expectedAdJourneyCode);
	});
});
