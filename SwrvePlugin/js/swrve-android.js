function SwrvePlugin() {}

SwrvePlugin.prototype.android = true;
SwrvePlugin.prototype.ios = false;

// name is a string
// payload is a JSON object
SwrvePlugin.prototype.event = function(name, payload, success, fail) {
	if (payload == undefined || !payload || payload.length < 1) {
		return cordova.exec(success, fail, 'SwrvePlugin', 'event', [ name ]);
	} else {
		return cordova.exec(success, fail, 'SwrvePlugin', 'event', [ name, payload ]);
	}
};

// attributes is a JSON object
SwrvePlugin.prototype.userUpdate = function(attributes, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'userUpdate', [ attributes ]);
};

// name is a string
// date is a date
SwrvePlugin.prototype.userUpdateDate = function(name, date, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'userUpdateDate', [ name, date ]);
};

// currency is a string
// quantity is an int
SwrvePlugin.prototype.currencyGiven = function(currency, quantity, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'currencyGiven', [ currency, quantity ]);
};

// itemName is a string
// currency is a string
// quantity is an int
// cost is a double
SwrvePlugin.prototype.purchase = function(itemName, currency, quantity, cost, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'purchase', [ itemName, currency, quantity, cost ]);
};

// localCost is a double
// localCurrency is a string
// productId is a string
// quantity is an int
SwrvePlugin.prototype.unvalidatedIap = function(localCost, localCurrency, productId, quantity, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'unvalidatedIap', [
		localCost,
		localCurrency,
		productId,
		quantity
	]);
};

// localCost is a double
// localCurrency is a string
// productId is a string
// quantity is an int
// reward is a JSONString
SwrvePlugin.prototype.unvalidatedIapWithReward = function(
	localCost,
	localCurrency,
	productId,
	quantity,
	reward,
	success,
	fail
) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'unvalidatedIapWithReward', [
		localCost,
		localCurrency,
		productId,
		quantity,
		reward
	]);
};

SwrvePlugin.prototype.sendEvents = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'sendEvents', []);
};

SwrvePlugin.prototype.getUserResources = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'getUserResources', []);
};

SwrvePlugin.prototype.getUserResourcesDiff = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'getUserResourcesDiff', []);
};

SwrvePlugin.prototype.refreshCampaignsAndResources = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'refreshCampaignsAndResources', []);
};

SwrvePlugin.prototype.getMessageCenterCampaigns = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'getMessageCenterCampaigns', []);
};

// identifier is an int
SwrvePlugin.prototype.showMessageCenterCampaign = function(identifier, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'showMessageCenterCampaign', [ identifier ]);
};

// identifier is an int
SwrvePlugin.prototype.removeMessageCenterCampaign = function(identifier, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'removeMessageCenterCampaign', [ identifier ]);
};

SwrvePlugin.prototype.resourcesListenerReady = function() {
	return cordova.exec(undefined, undefined, 'SwrvePlugin', 'resourcesListenerReady', []);
};

SwrvePlugin.prototype.setResourcesListener = function(listener) {
	window.swrveResourcesUpdatedListener = listener;
	window.plugins.swrve.resourcesListenerReady();
};

// customPayload is a JSON object
SwrvePlugin.prototype.setCustomPayloadForConversationInput = function(customPayload, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'setCustomPayloadForConversationInput', [ customPayload ]);
};

SwrvePlugin.prototype.setCustomButtonListener = function(listener) {
	window.swrveCustomButtonListener = listener;
	window.plugins.swrve.customButtonListenerReady();
};

SwrvePlugin.prototype.setDismissButtonListener = function(listener) {
	window.swrveDismissButtonListener = listener;
	window.plugins.swrve.dismissButtonListenerReady();
};

SwrvePlugin.prototype.dismissButtonListenerReady = function() {
	return cordova.exec(undefined, undefined, 'SwrvePlugin', 'dismissButtonListenerReady', []);
};

SwrvePlugin.prototype.customButtonListenerReady = function() {
	return cordova.exec(undefined, undefined, 'SwrvePlugin', 'customButtonListenerReady', []);
};

SwrvePlugin.prototype.pushNotificationListenerReady = function() {
	return cordova.exec(undefined, undefined, 'SwrvePlugin', 'pushNotificationListenerReady', []);
};

SwrvePlugin.prototype.silentPushNotificationListenerReady = function() {
	return cordova.exec(undefined, undefined, 'SwrvePlugin', 'silentPushNotificationListenerReady', []);
};

SwrvePlugin.prototype.setPushNotificationListener = function(listener) {
	window.swrvePushNotificationListener = listener;
	window.plugins.swrve.pushNotificationListenerReady();
};

SwrvePlugin.prototype.setSilentPushNotificationListener = function(listener) {
	window.swrveSilentPushNotificationListener = listener;
	window.plugins.swrve.silentPushNotificationListenerReady();
};

SwrvePlugin.prototype.getUserId = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'getUserId', []);
};

SwrvePlugin.prototype.getApiKey = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'getApiKey', []);
};

SwrvePlugin.prototype.getExternalUserId = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'getExternalUserId', []);
};

// userId is a string
SwrvePlugin.prototype.start = function(userId, success, fail) {
	if (!userId || userId.length < 1) {
		return cordova.exec(success, fail, 'SwrvePlugin', 'start', []);
	} else {
		return cordova.exec(success, fail, 'SwrvePlugin', 'start', [ userId ]);
	}
};

// userId is a string
SwrvePlugin.prototype.identify = function(userId, success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'identify', [ userId ]);
};

SwrvePlugin.prototype.isStarted = function(success, fail) {
	return cordova.exec(success, fail, 'SwrvePlugin', 'isStarted', []);
};

SwrvePlugin.install = function() {
	if (!window.plugins) {
		window.plugins = {};
	}

	window.plugins.swrve = new SwrvePlugin();
	// Empty callback for new user resources
	window.swrveResourcesUpdatedListener = function(resources) {};
	window.swrveProcessResourcesUpdated = function(resourcesJson) {
		// Decode the base64 encoded string sent by the plugin
		window.swrveResourcesUpdatedListener(JSON.parse(window.atob(resourcesJson)));
	};

	// Empty callback, override this to listen to custom IAM buttons
	window.swrveCustomButtonListener = function(action) {};

	// Empty callback, override this to listen to custom dismiss action
	window.swrveDismissButtonListener = function(action) {};

	// Empty callback, override this to listen to silent push notifications
	window.swrveSilentPushNotificationListener = function(payload) {};

	// Empty callback, override this to listen to push notifications
	window.swrvePushNotificationListener = function(payload) {};

	window.swrveProcessPushNotification = function(base64Payload) {
		// Decode the base64 encoded string sent by the plugin
		window.swrvePushNotificationListener(JSON.parse(window.atob(base64Payload)));
	};

	window.swrveProcessSilentPushNotification = function(base64Payload) {
		// Decode the base64 encoded string sent by the plugin
		window.swrveSilentPushNotificationListener(JSON.parse(window.atob(base64Payload)));
	};

	return window.plugins.swrve;
};

cordova.addConstructor(SwrvePlugin.install);
