package com.swrve.cordova.tests;
import com.swrve.sdk.ISwrveBase;
import com.swrve.sdk.SwrveSDKBase;

import java.lang.reflect.Field;

public class SwrveTestHelper {

    static final int WAITING_SHORT = 10;
    static final int WAITING_LONG = 20;

    static final int WAITING_SHORT_MILLISEC = 3000;

    public static void setSDKInstance(ISwrveBase instance) throws Exception {
        Field hack = SwrveSDKBase.class.getDeclaredField("instance");
        hack.setAccessible(true);
        hack.set(null, instance);
    }
}
