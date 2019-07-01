package com.swrve.cordova.tests;

import android.os.Build;
import android.webkit.JsResult;
import android.webkit.ValueCallback;
import android.webkit.WebView;

import com.swrve.cordova.tests.MainActivity;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaWebViewImpl;
import org.apache.cordova.engine.SystemWebChromeClient;
import org.apache.cordova.engine.SystemWebView;
import org.apache.cordova.engine.SystemWebViewClient;
import org.apache.cordova.engine.SystemWebViewEngine;

import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

public class MainTestActivity extends MainActivity {

    private SystemWebView testWebView;
    private Map<Integer, String> jsReturnValues;
    private boolean pageFinishedLoading;

    public interface JSCallback { void callback(String value); }

    @Override
    protected CordovaWebView makeWebView() {
        CordovaWebView cordovaWebView = super.makeWebView();
        testWebView = (SystemWebView)cordovaWebView.getView();
        jsReturnValues = new HashMap<Integer, String>();

        // Obtain a reference to the engine to create a custom web chrome client
        SystemWebViewEngine webEngine = null;
        try {
            Field engineField = CordovaWebViewImpl.class.getDeclaredField("engine");
            engineField.setAccessible(true);
            webEngine = (SystemWebViewEngine)engineField.get(cordovaWebView);
        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        }

        // Inject webchrome client and chrome client
        testWebView.getSettings().setJavaScriptEnabled(true);
        testWebView.getSettings().setJavaScriptCanOpenWindowsAutomatically(true);
        testWebView.setWebChromeClient(new SystemWebChromeClient(webEngine) {
            @Override
            public boolean onJsAlert(WebView view, String url, String message, JsResult result) {
                // Capture data through alert calls if they start with 'swrve:id:value'
                if (message.startsWith("swrve:")) {
                    String msg = message.substring(6);
                    int separator = msg.indexOf(':');
                    String idStr = msg.substring(0, separator);
                    String val = msg.substring(separator + 1);
                    synchronized (jsReturnValues) {
                        jsReturnValues.put(Integer.parseInt(idStr), val);
                    }
                    result.confirm();
                    return true;
                } else {
                    return super.onJsAlert(view, url, message, result);
                }
            }
        });
        testWebView.setWebViewClient(new SystemWebViewClient(webEngine) {
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                if (url.contains("index")) {
                    pageFinishedLoading = true;
                }
            }
        });
        return cordovaWebView;
    }

    public String getJSReturnValue(int id) {
        synchronized (jsReturnValues) {
            return jsReturnValues.get(id);
        }
    }

    protected void getJSReturnValueAsync(int id , JSCallback jsReturn) {
        new Thread(() -> {
            String value;
            do {
                value = getJSReturnValue(id);
                if (value != null) {
                    jsReturn.callback(value);
                    break;
                }
            } while(value == null);
        }).start();
    }

    public boolean isPageFinishedLoading() {
        return pageFinishedLoading;
    }

    public void clearJSReturnValues() {
        synchronized (jsReturnValues) {
            jsReturnValues.clear();
        }
    }

    public void runJS(String js) {
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            testWebView.evaluateJavascript(js, new ValueCallback<String>() {
                @Override
                public void onReceiveValue(String s) {
                }
            });
        } else {
            // Fallback method
            testWebView.loadUrl("javascript:" + js);
        }
    }
}
