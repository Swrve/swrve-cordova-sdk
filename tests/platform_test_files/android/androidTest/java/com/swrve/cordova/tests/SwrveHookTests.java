package com.swrve.cordova.tests;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import androidx.test.runner.AndroidJUnit4;

import com.swrve.sdk.SwrveNotificationConfig;
import com.swrve.sdk.SwrveSDK;

import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class SwrveHookTests {

    @Test
    public void testPushNotificationPermissionEvent() {
        SwrveNotificationConfig notificationConfig = SwrveSDK.getConfig().getNotificationConfig();
        assertNotNull(notificationConfig.getPushNotificationPermissionEvents());
        assertEquals(notificationConfig.getPushNotificationPermissionEvents().size(), 1);
        assertEquals(notificationConfig.getPushNotificationPermissionEvents().get(0), "request_notification_permission_event");
    }
}
