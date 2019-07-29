const fs = require('fs');

const {
	isEmptyString,
	convertToBoolean,
	searchAndReplace
} = require('../plugins/cordova-plugin-swrve/swrve-utils/hooks/swrve-utils');

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
