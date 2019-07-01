cordova.define('cordova/plugin_list', function(require, exports, module) {
  module.exports = [
    {
      "id": "cordova-plugin-swrve.SwrvePlugin",
      "file": "plugins/cordova-plugin-swrve/js/swrve-ios.js",
      "pluginId": "cordova-plugin-swrve",
      "clobbers": [
        "SwrvePlugin"
      ]
    }
  ];
  module.exports.metadata = {
    "cordova-plugin-swrve": "1.0"
  };
});