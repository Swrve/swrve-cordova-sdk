package com.swrve;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.os.Build;
import android.util.Base64;
import android.webkit.ValueCallback;

import org.apache.cordova.engine.SystemWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Iterator;
import java.util.TimeZone;

import com.swrve.sdk.ISwrveBase;
import com.swrve.sdk.SwrveIdentityResponse;
import com.swrve.sdk.SwrveResourcesListener;
import com.swrve.sdk.SwrveSilentPushListener;
import com.swrve.sdk.SwrveUserResourcesListener;
import com.swrve.sdk.SwrveSDK;
import com.swrve.sdk.config.SwrveConfig;
import com.swrve.sdk.messaging.SwrveBaseCampaign;
import com.swrve.sdk.SwrvePushNotificationListener;
import com.swrve.sdk.messaging.SwrveCustomButtonListener;
import com.swrve.sdk.runnable.UIThreadSwrveResourcesRunnable;
import com.swrve.sdk.UIThreadSwrveUserResourcesListener;
import com.swrve.sdk.runnable.UIThreadSwrveResourcesDiffRunnable;
import com.swrve.sdk.UIThreadSwrveUserResourcesDiffListener;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;

public class SwrvePlugin extends CordovaPlugin {

    public String VERSION = "1.1.1";
    private static SwrvePlugin instance;

    private boolean resourcesListenerReady;
    private boolean mustCallResourcesListener;

    // Push notification SwrvePlugin variables.
    private boolean pushNotificationListenerReady;
    private boolean silentPushNotificationListenerReady;
    private static List<String> pushNotificationsQueued = new ArrayList<>();
    private static List<String> silentPushNotificationsQueued = new ArrayList<>();

    public static synchronized void createInstance(Application application, int appId, String apiKey) {
        createInstance(application, appId, apiKey, null);
    }

    public static synchronized void createInstance(Application application, int appId, String apiKey,
            SwrveConfig config) {
        if (config == null) {
            config = new SwrveConfig();
        }
        config.setNotificationListener(pushNotificationListener);
        config.setSilentPushListener(silentPushNotificationListener);

        SwrveSDK.createInstance(application, appId, apiKey, config);
        SwrveSDK.setResourcesListener(resourcesListener);
    }

    // Used when instantiated via reflection by PluginManager
    public SwrvePlugin() {
        super();
        instance = this;
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        // Sent the wrapper
        Map<String, String> userUpdateWrapperVersion = new HashMap<String, String>();
        userUpdateWrapperVersion.put("swrve.cordova_plugin_version", VERSION);
        SwrveSDK.userUpdate(userUpdateWrapperVersion);
    }

    private HashMap<String, String> getMapFromJSON(JSONObject json) throws JSONException {
        HashMap<String, String> map = new HashMap<String, String>();

        for (Iterator<String> iterator = json.keys(); iterator.hasNext();) {
            String key = iterator.next();
            String value = json.getString(key);
            map.put(key, value);
        }
        return map;
    }

    private boolean isBadArgument(JSONArray arguments, CallbackContext callbackContext, int requiredSize, String msg) {
        if (arguments.length() < requiredSize) {
            System.err.println(msg);
            callbackContext.error(msg);
            return true;
        }
        return false;
    }

    private void identify(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            String userId = arguments.getString(0);
            SwrveSDK.identify(userId, new SwrveIdentityResponse() {
                @Override
                public void onSuccess(String status, String swrveId) {
                    try {
                        JSONObject callback = new JSONObject();
                        callback.put("status", status);
                        callback.put("swrveId", swrveId);
                        callbackContext.success(callback);

                    } catch (JSONException exception) {
                        callbackContext.success();
                    }
                }

                @Override
                public void onError(int responseCode, String errorMessage) {
                    System.err.println(errorMessage);
                    try {
                        JSONObject callback = new JSONObject();
                        callback.put("responseCode", responseCode);
                        callback.put("errorMessage", errorMessage);
                        callbackContext.error(callback);

                    } catch (JSONException exception) {
                        callbackContext.error(errorMessage);
                    }
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void sendEvent(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final String name = arguments.getString(0);
            // payload is optional
            if (arguments.length() > 1) {
                JSONObject payloads = arguments.getJSONObject(1);
                final HashMap<String, String> map = getMapFromJSON(payloads);
                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                        SwrveSDK.event(name, map);
                        callbackContext.success();
                    }
                });
            } else {
                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                        SwrveSDK.event(name);
                        callbackContext.success();
                    }
                });
            }
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void sendUserUpdate(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            JSONObject updates = arguments.getJSONObject(0);
            final HashMap<String, String> map = getMapFromJSON(updates);

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.userUpdate(map);
                    callbackContext.success();
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void sendUserUpdateDate(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final String propertyName = arguments.getString(0);
            final String propertyValueRaw = arguments.getString(1);

            // We assume it is a variation of the ISO 8601 date format
            TimeZone tz = TimeZone.getTimeZone("UTC");
            DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
            df.setTimeZone(tz);
            final Date propertyValue = df.parse(propertyValueRaw);

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.userUpdate(propertyName, propertyValue);
                    callbackContext.success();
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        } catch (ParseException e) {
            callbackContext.error("PARSE_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void sendCurrencyGiven(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final String currency = arguments.getString(0);
            final int quantity = arguments.getInt(1);

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.currencyGiven(currency, quantity);
                    callbackContext.success();
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void sendPurchase(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final String name = arguments.getString(0);
            final String currency = arguments.getString(1);
            final int quantity = arguments.getInt(2);
            final int cost = arguments.getInt(3);

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.purchase(name, currency, cost, quantity);
                    callbackContext.success();
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void sendIap(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final int quantity = arguments.getInt(0);
            final String productId = arguments.getString(1);
            final double price = arguments.getDouble(2);
            final String currency = arguments.getString(3);

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.iap(quantity, productId, price, currency);
                    callbackContext.success();
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void sendIapPlay(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final String productId = arguments.getString(0);
            final double productPrice = arguments.getDouble(1);
            final String currency = arguments.getString(2);
            final String purchaseData = arguments.getString(3);
            final String dataSignature = arguments.getString(4);

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.iapPlay(productId, productPrice, currency, purchaseData, dataSignature);
                    callbackContext.success();
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    @Override
    public boolean execute(final String action, final JSONArray arguments, final CallbackContext callbackContext) {
        if ("identify".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 1, "user id argument needs to be supplied")) {
                identify(arguments, callbackContext);
            }
            return true;

        } else if ("event".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 1, "event arguments need to be supplied.")) {
                sendEvent(arguments, callbackContext);
            }
            return true;

        } else if ("userUpdate".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 1, "user update arguments need to be supplied.")) {
                sendUserUpdate(arguments, callbackContext);
            }
            return true;

        } else if ("userUpdateDate".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 2, "user update date arguments need to be supplied.")) {
                sendUserUpdateDate(arguments, callbackContext);
            }
            return true;

        } else if ("currencyGiven".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 2, "currency given arguments need to be supplied.")) {
                sendCurrencyGiven(arguments, callbackContext);
            }
            return true;

        } else if ("purchase".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 4, "purchase arguments need to be supplied.")) {
                sendPurchase(arguments, callbackContext);
            }
            return true;

        } else if ("iap".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 4, "iap arguments need to be supplied.")) {
                sendIap(arguments, callbackContext);
            }
            return true;

        } else if ("iapPlay".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 5, "iap arguments need to be supplied.")) {
                sendIapPlay(arguments, callbackContext);
            }
            return true;

        } else if ("sendEvents".equals(action)) {
            cordova.getThreadPool().execute(() -> {
                SwrveSDK.sendQueuedEvents();
                callbackContext.success();
            });
            return true;

        } else if ("getUserResources".equals(action)) {
            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.getUserResources(new UIThreadSwrveUserResourcesListener(cordova.getActivity(),
                            new UIThreadSwrveResourcesRunnable() {
                                @Override
                                public void onUserResourcesSuccess(Map<String, Map<String, String>> resources,
                                        String resourcesAsJSON) {
                                    callbackContext.success(new JSONObject(resources));
                                }

                                @Override
                                public void onUserResourcesError(Exception exception) {
                                    exception.printStackTrace();
                                    callbackContext.error(exception.getMessage());
                                }
                            }));
                }
            });
            return true;

        } else if ("getUserResourcesDiff".equals(action)) {
            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    SwrveSDK.getUserResourcesDiff(new UIThreadSwrveUserResourcesDiffListener(cordova.getActivity(),
                            new UIThreadSwrveResourcesDiffRunnable() {
                                @Override
                                public void onUserResourcesDiffSuccess(Map<String, Map<String, String>> oldResources,
                                        Map<String, Map<String, String>> newResources, String resourcesAsJSON) {
                                    try {
                                        JSONObject result = new JSONObject();
                                        result.put("old", new JSONObject(oldResources));
                                        result.put("new", new JSONObject(newResources));
                                        callbackContext.success(result);
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                }

                                @Override
                                public void onUserResourcesDiffError(Exception exception) {
                                    exception.printStackTrace();
                                    callbackContext.error(exception.getMessage());
                                }
                            }));
                }
            });
            return true;
        } else if ("getMessageCenterCampaigns".equals((action))) {
            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    try {
                        List<SwrveBaseCampaign> campaigns = SwrveSDK.getMessageCenterCampaigns();
                        JSONArray result = new JSONArray();

                        for (SwrveBaseCampaign campaign : campaigns) {
                            JSONObject campaignJSON = new JSONObject();
                            campaignJSON.put("ID", campaign.getId());
                            campaignJSON.put("maxImpressions", campaign.getMaxImpressions());
                            campaignJSON.put("subject", campaign.getSubject());
                            campaignJSON.put("dateStart", (campaign.getStartDate().getTime() / 1000));
                            campaignJSON.put("messageCenter", campaign.isMessageCenter());
                            campaignJSON.put("state", campaign.getSaveableState().toJSON());
                            result.put(campaignJSON);
                        }

                        callbackContext.success(result);

                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }
            });
            return true;
        } else if ("showMessageCenterCampaign".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 1, "Invalid Arguments")) {
                showMessageCenterCampaign(arguments, callbackContext);
            }
            return true;
        } else if ("removeMessageCenterCampaign".equals(action)) {
            if (!isBadArgument(arguments, callbackContext, 1, "Invalid Arguments")) {
                removeMessageCenterCampaign(arguments, callbackContext);
            }
            return true;
        } else if ("refreshCampaignsAndResources".equals(action)) {
            SwrveSDK.refreshCampaignsAndResources();
            return true;
        } else if ("resourcesListenerReady".equals(action)) {
            setResourcesListenerReady();
            return true;
        } else if ("pushNotificationListenerReady".equals(action)) {
            setPushNotificationListenerReady();
            return true;
        } else if ("silentPushNotificationListenerReady".equals(action)) {
            setSilentPushNotificationListenerReady();
            return true;
        } else if ("customButtonListenerReady".equals(action)) {
            SwrveSDK.setCustomButtonListener(customButtonListener);
            return true;
        } else if ("getUserId".equals(action)) {
            callbackContext.success(SwrveSDK.getUserId());
            return true;
        } else if ("getExternalUserId".equals(action)) {
            callbackContext.success(SwrveSDK.getExternalUserId());
            return true;
        }

        return false;
    }

    private void runJS(String js) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            SystemWebView systemWebView = (SystemWebView) webView.getView();
            systemWebView.evaluateJavascript(js, new ValueCallback<String>() {
                @Override
                public void onReceiveValue(String s) {
                }
            });
        } else {
            // Fallback method
            webView.loadUrl("javascript:" + js);
        }
    }

    private void showMessageCenterCampaign(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final int identifier = arguments.getInt(0);

            cordova.getThreadPool().execute(() -> {

                SwrveBaseCampaign canditateCampaign = findMessageCenterCampaignbyID(identifier);

                if (canditateCampaign != null) {
                    SwrveSDK.showMessageCenterCampaign(canditateCampaign);
                    callbackContext.success();
                } else {
                    callbackContext.error("No campaign with ID: " + identifier + " found.");
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private void removeMessageCenterCampaign(JSONArray arguments, final CallbackContext callbackContext) {
        try {
            final int identifier = arguments.getInt(0);

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {

                    SwrveBaseCampaign canditateCampaign = findMessageCenterCampaignbyID(identifier);

                    if (canditateCampaign != null) {
                        SwrveSDK.removeMessageCenterCampaign(canditateCampaign);
                        callbackContext.success();
                    } else {
                        callbackContext.error("No campaign with ID: " + identifier + " found.");
                    }
                }
            });
        } catch (JSONException e) {
            callbackContext.error("JSON_EXCEPTION");
            e.printStackTrace();
        }
    }

    private SwrveBaseCampaign findMessageCenterCampaignbyID(int identifier) {

        List<SwrveBaseCampaign> campaigns = SwrveSDK.getMessageCenterCampaigns();
        SwrveBaseCampaign canditateCampaign = null;

        for (SwrveBaseCampaign campaign : campaigns) {
            if (campaign.getId() == identifier) {
                canditateCampaign = campaign;
            }
        }

        return canditateCampaign;
    }

    private void setResourcesListenerReady() {
        resourcesListenerReady = true;
        // Send any queued user resources listener calls
        if (mustCallResourcesListener) {
            resourcesListenerCall();
        }
    }

    private static void resourcesListenerCall() {
        Activity activity = instance.cordova.getActivity();
        if (!activity.isFinishing()) {
            activity.runOnUiThread(() -> {
                ISwrveBase sdk = SwrveSDK.getInstance();
                if (sdk != null) {
                    sdk.getUserResources(new SwrveUserResourcesListener() {
                        @Override
                        public void onUserResourcesSuccess(Map<String, Map<String, String>> resources,
                                String resourcesAsString) {
                            final String base64Encoded = encodeJsonToBase64(new JSONObject(resources));
                            instance.runJS(
                                    "if (window.swrveProcessResourcesUpdated !== undefined) { window.swrveProcessResourcesUpdated('"
                                            + base64Encoded + "'); }");
                        }

                        @Override
                        public void onUserResourcesError(Exception exception) {
                            exception.printStackTrace();
                        }
                    });
                }
            });
        }
    }

    private static SwrveResourcesListener resourcesListener = new SwrveResourcesListener() {
        @Override
        public void onResourcesUpdated() {
            if (instance.resourcesListenerReady) {
                resourcesListenerCall();
            } else {
                // Will call the listener later
                instance.mustCallResourcesListener = true;
            }
        }
    };

    private static SwrveCustomButtonListener customButtonListener = new SwrveCustomButtonListener() {
        @Override
        public void onAction(final String action) {
            instance.cordova.getActivity()
                    .runOnUiThread(() -> instance.runJS(
                            "if (window.swrveCustomButtonListener !== undefined) { window.swrveCustomButtonListener('"
                                    + action + "'); }"));
        }
    };

    // region Method for CustomPush and SilentPush handlers.

    private void setPushNotificationListenerReady() {
        pushNotificationListenerReady = true;
        sendQueuedPushNotifications(pushNotificationsQueued);
        pushNotificationsQueued.clear();
    }

    private void setSilentPushNotificationListenerReady() {
        silentPushNotificationListenerReady = true;
        sendQueuedPushNotifications(silentPushNotificationsQueued);
        silentPushNotificationsQueued.clear();
    }

    private synchronized void sendQueuedPushNotifications(List<String> queue) {
        if (queue.size() > 0) {
            if (queue == silentPushNotificationsQueued) {
                for (int i = 0; i < queue.size(); i++) {
                    String payload = queue.get(i);
                    instance.cordova.getActivity().runOnUiThread(() -> instance.notifyOfSilentPushPayload(payload));
                }
            } else {
                for (int i = 0; i < queue.size(); i++) {
                    String payload = queue.get(i);
                    instance.cordova.getActivity().runOnUiThread(() -> instance.notifyOfPushPayload(payload));
                }
            }
        }
    }

    private void notifyOfPushPayload(String base64Payload) {
        runJS("if (window.swrveProcessPushNotification !== undefined) { window.swrveProcessPushNotification('"
                + base64Payload + "'); }");
    }

    private void notifyOfSilentPushPayload(String base64Payload) {
        runJS("if (window.swrveProcessSilentPushNotification !== undefined) { window.swrveProcessSilentPushNotification('"
                + base64Payload + "'); }");
    }

    private static SwrveSilentPushListener silentPushNotificationListener = new SwrveSilentPushListener() {
        @Override
        public void onSilentPush(Context context, JSONObject json) {
            final String base64Encoded = encodeJsonToBase64(json);
            if (instance != null && instance.silentPushNotificationListenerReady) {
                instance.cordova.getActivity().runOnUiThread(() -> instance.notifyOfSilentPushPayload(base64Encoded));
            } else {
                silentPushNotificationsQueued.add(base64Encoded);
            }
        }
    };

    private static SwrvePushNotificationListener pushNotificationListener = new SwrvePushNotificationListener() {
        @Override
        public void onPushNotification(JSONObject json) {
            final String base64Encoded = encodeJsonToBase64(json);
            if (instance != null && instance.pushNotificationListenerReady) {
                instance.cordova.getActivity().runOnUiThread(() -> instance.notifyOfPushPayload(base64Encoded));
            } else {
                pushNotificationsQueued.add(base64Encoded);
            }
        }
    };

    // endregion

    private static String encodeJsonToBase64(JSONObject json) {
        String jsonString = json.toString();
        byte[] jsonBytes = jsonString.getBytes();
        return Base64.encodeToString(jsonBytes, Base64.NO_WRAP);
    }
}