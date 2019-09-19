package com.swrve;

import android.content.Context;
import android.content.pm.PackageManager;
import android.Manifest;

import com.swrve.sdk.geo.SwrveGeoSDK;
import com.swrve.sdk.geo.SwrveGeoConfig;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PermissionHelper;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;

public class SwrveGeoPlugin extends CordovaPlugin {

    private static SwrveGeoPlugin instance;
    private static Context applicationContext;

    CallbackContext cordovaCallbackContext;
    String[] permissions = { Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION };

    public static synchronized void createInstance(Context context, String geoApiKey) {
        createInstance(context, geoApiKey, null);
    }

    public static synchronized void createInstance(Context context, String geoApiKey, SwrveGeoConfig geoConfig) {

        if (geoConfig == null) {
            geoConfig = new SwrveGeoConfig();
        }
        applicationContext = context;
        SwrveGeoSDK.init(context, geoApiKey, geoConfig);

    }

    // Used when instantiated via reflection by PluginManager
    public SwrveGeoPlugin() {
        super();
        instance = this;
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
    }

    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        cordovaCallbackContext = callbackContext;
        if (action.equals("start")) {
            if (hasPermission()) {
                PluginResult r = new PluginResult(PluginResult.Status.OK);
                cordovaCallbackContext.sendPluginResult(r);
                SwrveGeoSDK.start(applicationContext);
                return true;
            } else {
                PermissionHelper.requestPermissions(this, 0, permissions);
            }
            return true;
        } else if (action.equals("stop")) {
            PluginResult r = new PluginResult(PluginResult.Status.OK);
            cordovaCallbackContext.sendPluginResult(r);
            SwrveGeoSDK.stop(applicationContext);
            return true;
        }
        return false;
    }

    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults)
            throws JSONException {
        PluginResult result;
        if (cordovaCallbackContext != null) {
            for (int r : grantResults) {
                if (r == PackageManager.PERMISSION_DENIED) {
                    result = new PluginResult(PluginResult.Status.ILLEGAL_ACCESS_EXCEPTION);
                    cordovaCallbackContext.sendPluginResult(result);
                    return;
                }

            }
            result = new PluginResult(PluginResult.Status.OK);
            cordovaCallbackContext.sendPluginResult(result);
            SwrveGeoSDK.start(applicationContext);
        }
    }

    public boolean hasPermission() {
        for (String p : permissions) {
            if (!PermissionHelper.hasPermission(this, p)) {
                return false;
            }
        }
        return true;
    }

    public void requestPermissions(int requestCode) {
        PermissionHelper.requestPermissions(this, requestCode, permissions);
    }
}