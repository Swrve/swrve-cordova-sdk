cordova.define("cordova-plugin-swrvegeo.SwrveGeoPlugin", function(require, exports, module) {
function SwrveGeoPlugin() {}

SwrveGeoPlugin.prototype.android = false;
SwrveGeoPlugin.prototype.ios = true;

cordova.addConstructor(SwrveGeoPlugin.install);

});
