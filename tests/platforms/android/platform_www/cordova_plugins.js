cordova.define('cordova/plugin_list', function(require, exports, module) {
  module.exports = [
    {
      "id": "cordova-plugin-swrve.SwrvePlugin",
      "file": "plugins/cordova-plugin-swrve/js/swrve-android.js",
      "pluginId": "cordova-plugin-swrve",
      "clobbers": [
        "SwrvePlugin"
      ]
    },
    {
      "id": "cordova-plugin-swrvegeo.SwrveGeoPlugin",
      "file": "plugins/cordova-plugin-swrvegeo/js/swrvegeo-android.js",
      "pluginId": "cordova-plugin-swrvegeo",
      "clobbers": [
        "SwrveGeoPlugin"
      ]
    }
  ];
  module.exports.metadata = {
    "cordova-plugin-swrve": "1.0",
    "cordova-plugin-swrvegeo": "1.0"
  };
});