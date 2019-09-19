function SwrveGeoPlugin() {}

SwrveGeoPlugin.prototype.android = false;
SwrveGeoPlugin.prototype.ios = true;

cordova.addConstructor(SwrveGeoPlugin.install);
