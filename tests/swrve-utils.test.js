const fs = require('fs');

const {
	isEmptyString,
	convertToBoolean,
	searchAndReplace,
	setAppIdAndApiKey,
	copyRecursiveSync
} = require('./plugins/cordova-plugin-swrve/swrve-utils/hooks/swrve-utils');

describe('isEmptyString', () => {
	test('Detects an empty string', () => {
		expect(isEmptyString('')).toBe(true);
	});

	test('Detects an undefined var', () => {
		expect(isEmptyString(undefined)).toBe(true);
	});

	test('Detects a populated string', () => {
		expect(isEmptyString('string')).toBe(false);
	});
});

describe('convertToBoolean', () => {
	test('is case insensitive', () => {
		expect(convertToBoolean('true')).toBe(true);
		expect(convertToBoolean('True')).toBe(true);
		expect(convertToBoolean('TRue')).toBe(true);
		expect(convertToBoolean('TRUe')).toBe(true);
		expect(convertToBoolean('TRUE')).toBe(true);
	});

	test('handles an empty string', () => {
		expect(convertToBoolean('')).toBe(false);
	});

	test('handles an undefined var', () => {
		expect(convertToBoolean(undefined)).toBe(false);
	});
});

describe('searchAndReplace', () => {
	beforeEach(() => {
		// create a basic file to edit
		fs.appendFileSync('test_file.txt', 'file wasnt edited', 'utf-8');
		fs.appendFileSync('empty_file.txt', '', 'utf-8');
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('test_file.txt');
		fs.unlinkSync('empty_file.txt');
	});

	test('replaces all items in a given file', () => {
		searchAndReplace('test_file.txt', [ 'file', 'wasnt', 'edited' ], [ 'files', 'were', 'changed' ]);
		const filecontents = fs.readFileSync('test_file.txt', 'utf-8');
		expect(filecontents).toBe('files were changed');
	});

	test('ensures that the search/replace is sync and thread safe', () => {
		searchAndReplace('test_file.txt', [ 'file', 'wasnt', 'edited' ], [ 'files', 'were', 'changed' ]);
		searchAndReplace('test_file.txt', [ 'changed' ], [ 'different' ]);

		const filecontents = fs.readFileSync('test_file.txt', 'utf-8');
		expect(filecontents).toBe('files were different');
	});

	test('throws an exception when the search and replace arrays arent the same length', () => {
		try {
			searchAndReplace(
				'test_file.txt',
				[ 'file', 'wasnt' /** set too short on purpose */ ],
				[ 'files', 'were', 'changed' ]
			);
		} catch (e) {
			expect(e.message).toBe('search/replace array lengths do not match');
		}
	});

	test('throws an exception when the file at filePath is empty', () => {
		try {
			searchAndReplace('empty_file.txt', [ 'hello' ], [ 'world' ]);
		} catch (e) {
			expect(e.message).toBe('file at empty_file.txt is empty');
		}
	});
});

describe('setAppIdAndApiKey', () => {
	beforeEach(() => {
		fs.appendFileSync(
			'ios_example.txt',
			'[SwrvePlugin initWithAppID: <SwrveAppId> apiKey: @"<SwrveKey>" config:config viewController:self.viewController];',
			'utf-8'
		);
		fs.appendFileSync(
			'android_example.txt',
			'SwrvePlugin.createInstance(this, <SwrveAppId>, "<SwrveKey>", config);',
			'utf-8'
		);
	});

	afterEach(() => {
		// clean up the file after
		fs.unlinkSync('ios_example.txt');
		fs.unlinkSync('android_example.txt');
	});

	test('Check if is able to set AppId and APIKey', () => {
		setAppIdAndApiKey(`ios_example.txt`, 12345, `MyApiKey`);
		let iosExample = fs.readFileSync(`ios_example.txt`, 'utf-8');
		expect(iosExample).toContain(
			`[SwrvePlugin initWithAppID: 12345 apiKey: @"MyApiKey" config:config viewController:self.viewController];`
		);

		setAppIdAndApiKey(`android_example.txt`, 12345, `MyApiKey`);
		let androidExample = fs.readFileSync(`android_example.txt`, 'utf-8');
		expect(androidExample).toContain(`SwrvePlugin.createInstance(this, 12345, "MyApiKey", config);`);
	});

	test('Check if is able to set just AppId', () => {
		setAppIdAndApiKey(`ios_example.txt`, 12345, null);
		let iosExample = fs.readFileSync(`ios_example.txt`, 'utf-8');
		expect(iosExample).toContain(
			`[SwrvePlugin initWithAppID: 12345 apiKey: @"<SwrveKey>" config:config viewController:self.viewController];`
		);

		setAppIdAndApiKey(`android_example.txt`, 12345, null);
		let androidExample = fs.readFileSync(`android_example.txt`, 'utf-8');
		expect(androidExample).toContain(`SwrvePlugin.createInstance(this, 12345, "<SwrveKey>", config);`);
	});

	test('Check if is able to set just APIKey', () => {
		setAppIdAndApiKey(`ios_example.txt`, null, `MyApiKey`);
		let iosExample = fs.readFileSync(`ios_example.txt`, 'utf-8');
		expect(iosExample).toContain(
			`[SwrvePlugin initWithAppID: <SwrveAppId> apiKey: @"MyApiKey" config:config viewController:self.viewController];`
		);

		setAppIdAndApiKey(`android_example.txt`, null, `MyApiKey`);
		let androidExample = fs.readFileSync(`android_example.txt`, 'utf-8');
		expect(androidExample).toContain(`SwrvePlugin.createInstance(this, <SwrveAppId>, "MyApiKey", config);`);
	});

	describe('copyRecursiveSync', () => {
		const file1URL = 'random_file1.txt';
		const file2URL = 'random_file2.txt';
		const file3URL = 'folder/random_file3';
		const file4URL = 'folder/folder_in_folder/random_file4.txt';

		beforeEach(() => {
			fs.mkdirSync('origin/');
			fs.mkdirSync('origin/folder/');
			fs.mkdirSync('origin/folder/folder_in_folder');
			// create some files in diferrent folder levels.
			fs.appendFileSync(`origin/${file1URL}`, 'random_file1', 'utf-8');
			fs.appendFileSync(`origin/${file2URL}`, 'random_file2', 'utf-8');
			fs.appendFileSync(`origin/${file3URL}`, 'random_file3', 'utf-8');
			fs.appendFileSync(`origin/${file4URL}`, 'random_file4', 'utf-8');
		});

		afterEach(() => {
			// clean up all the files to copy
			fs.unlinkSync(`origin/${file1URL}`);
			fs.unlinkSync(`origin/${file2URL}`);
			fs.unlinkSync(`origin/${file3URL}`);
			fs.unlinkSync(`origin/${file4URL}`);
			fs.rmdirSync('origin/folder/folder_in_folder');
			fs.rmdirSync('origin/folder/');
			fs.rmdirSync('origin/');
		});

		test('Check basic copy and past with some files and folders.', () => {
			// copy all the files from 'origin' folder to 'dest' folder. and check for content of each one of them
			copyRecursiveSync('origin/', `dest/`);

			const filecontents1 = fs.readFileSync(`dest/${file1URL}`, 'utf-8');
			expect(filecontents1).toBe('random_file1');

			const filecontents2 = fs.readFileSync(`dest/${file2URL}`, 'utf-8');
			expect(filecontents2).toBe('random_file2');

			const filecontents3 = fs.readFileSync(`dest/${file3URL}`, 'utf-8');
			expect(filecontents3).toBe('random_file3');

			const filecontents4 = fs.readFileSync(`dest/${file4URL}`, 'utf-8');
			expect(filecontents4).toBe('random_file4');

			// clean up all the files from desty folder and remove directories for the current test.
			fs.unlinkSync(`dest/${file1URL}`);
			fs.unlinkSync(`dest/${file2URL}`);
			fs.unlinkSync(`dest/${file3URL}`);
			fs.unlinkSync(`dest/${file4URL}`);
			fs.rmdirSync('dest/folder/folder_in_folder');
			fs.rmdirSync('dest/folder/');
			fs.rmdirSync('dest/');
		});

		test('throws an exception when file already exist, we do not replace file at destination!', () => {
			try {
				copyRecursiveSync(`origin/${file1URL}`, `origin/${file1URL}`);
			} catch (e) {
				expect(e.message).toBe(
					`EEXIST: file already exists, link 'origin/random_file1.txt' -> 'origin/random_file1.txt'`
				);
			}
		});

		test('throws an exception when cant find derectory', () => {
			try {
				copyRecursiveSync(`origin/${file1URL}`, `dest/${file1URL}`);
			} catch (e) {
				expect(e.message).toBe(
					`ENOENT: no such file or directory, link 'origin/random_file1.txt' -> 'dest/random_file1.txt'`
				);
			}
		});
	});
});
