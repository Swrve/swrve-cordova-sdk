package com.swrve.cordova.tests;

import android.app.Application;
import android.content.Context;
import android.support.test.rule.ActivityTestRule;

import com.swrve.SwrvePlugin;
import com.swrve.sdk.ISwrve;
import com.swrve.sdk.SwrveSDKBase;
import com.swrve.sdk.config.SwrveConfig;

import org.junit.After;
import org.junit.Before;
import org.mockito.Mockito;

import java.lang.reflect.Field;
import java.net.URL;
import java.util.concurrent.Semaphore;

import static android.support.test.InstrumentationRegistry.getInstrumentation;
import static junit.framework.TestCase.assertTrue;
import static org.junit.Assert.assertNotNull;

public class SwrvePluginBaseTests extends ActivityTestRule<MainTestActivity> {

    protected MainTestActivity mActivity;

    // don't spy on Swrve since mockito will reflect NotificationChannel and fail for Android < 25
    protected ISwrve swrveMock;
    protected SwrveConfig configMock;

    public SwrvePluginBaseTests() {
        super(MainTestActivity.class);
    }

    @Before
    public void setUp() throws Exception {

        final Context context = getInstrumentation().getTargetContext().getApplicationContext();
        applicationOnCreate((Application) context);

        // Start activity and SDK
        mActivity = launchActivity(null);
        assertNotNull(mActivity);

        // Wait for page to load...
        for (int i = 0; i < 60 && !mActivity.isPageFinishedLoading(); i++) {
            Thread.sleep(1000);
        }

        assertTrue(mActivity.isPageFinishedLoading());

        // Wait for plugin to be loaded
        String pluginLoaded = null;
        for (int i = 0; i < 10 && pluginLoaded == null; i++) {
            runJS("if (window !== undefined && 'plugins' in window && 'swrve' in window.plugins) { alert('swrve:99:yes'); }");
            pluginLoaded = mActivity.getJSReturnValue(99);
            if (pluginLoaded == null) {
                Thread.sleep(1000);
            }
        }

        mActivity.clearJSReturnValues();
        assertNotNull(pluginLoaded);

        swrveMock = Mockito.spy(ISwrve.class);
        SwrveTestHelper.setSDKInstance(swrveMock);
    }


    @After
    public void tearDown() {
        mActivity = null;
        if (swrveMock != null) {
            Mockito.reset(swrveMock);
        }
        if (configMock != null) {
            Mockito.reset(configMock);
        }
    }


    protected void runJS(final String js) {
        final Semaphore mutex = new Semaphore(0);
        mActivity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mActivity.runJS(js);
                mutex.release();
            }
        });
        try {
            mutex.acquire();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    private void applicationOnCreate(final Application application) throws Exception {
        // Clean any previous instance of the SDK
        Field instanceField = SwrveSDKBase.class.getDeclaredField("instance");
        instanceField.setAccessible(true);
        instanceField.set(null, null);

        // Init SDK
        configMock = Mockito.spy(new SwrveConfig());
        configMock.setContentUrl(new URL("http://localhost:8083"));
        configMock.setEventsUrl(new URL("http://localhost:8085"));
        configMock.setIdentityUrl(new URL("http://localhost:8086"));
        SwrvePlugin.createInstance(application, 1111, "fake_api_key", configMock);
    }

}
