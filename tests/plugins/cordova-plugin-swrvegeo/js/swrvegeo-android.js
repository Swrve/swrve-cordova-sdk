function SwrveGeoPlugin() {}

SwrveGeoPlugin.prototype.android = true;
SwrveGeoPlugin.prototype.ios = false;

SwrveGeoPlugin.prototype.start = function(success, fail) {
	return cordova.exec(success, fail, 'SwrveGeoPlugin', 'start', []);
};

SwrveGeoPlugin.prototype.stop = function(success, fail) {
	return cordova.exec(success, fail, 'SwrveGeoPlugin', 'stop', []);
};

SwrveGeoPlugin.install = function() {
	if (!window.plugins) {
		window.plugins = {};
	}

	window.plugins.swrvegeo = new SwrveGeoPlugin();
	return window.plugins.swrvegeo;
};

cordova.addConstructor(SwrveGeoPlugin.install);
