package com.swrve.cordova.tests;

import android.app.Instrumentation;
import android.content.Intent;
import android.view.View;
import android.view.ViewGroup;

import com.swrve.sdk.ISwrve;
import com.swrve.sdk.Swrve;
import com.swrve.sdk.SwrveNotificationEngageReceiver;
import com.swrve.sdk.SwrveSDK;

import com.swrve.sdk.messaging.SwrveBaseCampaign;
import com.swrve.sdk.messaging.ui.SwrveInAppMessageActivity;
import com.swrve.sdk.messaging.view.SwrveButtonView;
import com.swrve.sdk.messaging.view.SwrveMessageView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.Mockito;

import java.util.ArrayList;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import static android.support.test.InstrumentationRegistry.getInstrumentation;
import static org.awaitility.Awaitility.await;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

public class SwrvePluginTests extends SwrvePluginBaseTests {

    // NOTE: Any JS failure might affect the next run. If the UI does not appear
    // in the test run it is a sign that there was an error.

    @Test
    public void testEvents() {
        runJS("window.plugins.swrve.event(\"levelup\", undefined, undefined);");
        runJS("window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, undefined, undefined);");
        runJS("window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, undefined, undefined);");
        runJS("window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date(2016, 12, 2, 16, 20, 0, 0), undefined, undefined);");
        runJS("window.plugins.swrve.currencyGiven(\"Gold\", 20, undefined, undefined);");
        runJS("window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, undefined, undefined);");
        runJS("window.plugins.swrve.iap(2, \"sword\", 99.5, \"USD\", undefined, undefined);");
        runJS("window.plugins.swrve.iapPlay(\"iap_item\", 98.5, \"USD\", \"fake_purchase_data\", \"fake_purchase_signature\", undefined, undefined);");
        runJS("window.plugins.swrve.sendEvents(undefined, undefined);");

        // Define events that we should find
        ArrayList<EventChecker> eventChecks = new ArrayList<EventChecker>();
        eventChecks.add(new EventChecker("event") {
            @Override
            public boolean check(JSONObject event) {
                JSONObject payload = event.optJSONObject("payload");
                return event.optString("name", "").equals("levelup") && (payload == null || payload.length() == 0);
            }
        });
        eventChecks.add(new EventChecker("event with payload") {
            @Override
            public boolean check(JSONObject event) {
                JSONObject payload = event.optJSONObject("payload");
                return event.optString("name", "").equals("leveldown") && (payload != null && payload.optString("armor", "").equals("disabled"));
            }
        });
        eventChecks.add(new EventChecker("user update") {
            @Override
            public boolean check(JSONObject event) {
                JSONObject attributes = event.optJSONObject("attributes");
                return event.optString("type", "").equals("user") && (attributes != null && attributes.optString("cordova", "").equals("TRUE"));
            }
        });
        eventChecks.add(new EventChecker("currency given") {
            @Override
            public boolean check(JSONObject event) {
                return event.optString("type", "").equals("currency_given")
                        && event.optString("given_amount", "").equals("20.0")
                        && event.optString("given_currency", "").equals("Gold");
            }
        });
        eventChecks.add(new EventChecker("purchase") {
            @Override
            public boolean check(JSONObject event) {
                return event.optString("type", "").equals("purchase")
                        && event.optString("quantity", "").equals("2")
                        && event.optString("currency", "").equals("Gold")
                        && event.optString("cost", "").equals("15")
                        && event.optString("item", "").equals("sword");
            }
        });
        eventChecks.add(new EventChecker("iap") {
            @Override
            public boolean check(JSONObject event) {
                return event.optString("type", "").equals("iap")
                        && event.optString("quantity", "").equals("2")
                        && event.optString("local_currency", "").equals("USD")
                        && event.optString("cost", "").equals("99.5")
                        && event.optString("product_id", "").equals("sword")
                        && event.optString("rewards", "").equals("{}");
            }
        });
        eventChecks.add(new EventChecker("iapPlay") {
            @Override
            public boolean check(JSONObject event) {
                return event.optString("type", "").equals("iap")
                        && event.optString("quantity", "").equals("1")
                        && event.optString("local_currency", "").equals("USD")
                        && event.optString("cost", "").equals("98.5")
                        && event.optString("product_id", "").equals("iap_item")
                        && event.optString("receipt", "").equals("fake_purchase_data")
                        && event.optString("receipt_signature", "").equals("fake_purchase_signature")
                        && event.optString("rewards", "").equals("{}");
            }
        });
        eventChecks.add(new EventChecker("user update date") {
            @Override
            public boolean check(JSONObject event) {
                JSONObject attributes = event.optJSONObject("attributes");
                return event.optString("type", "").equals("user") && (attributes != null && attributes.optString("last_subscribed", "").equals("2017-01-02T16:20:00.000Z"));
            }
        });

        runJS("window.plugins.swrve.sendEvents(function(successCallback) { alert('swrve:190:' + successCallback);}, undefined);");
        final AtomicBoolean sendEventsCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(190, value -> {
            try {
                EventChecker failedChecker = returnFailedChecker(eventChecks);
                assertEquals("Success return should be OK", value, "OK");
                assertEquals("Number of events on queue should be 8.",8, eventChecks.size());
            } catch (JSONException e) {
                e.printStackTrace();
            }
            assertNotNull(value);
            sendEventsCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(sendEventsCompleted);
    }

    @Test
    public void testEvent() {
        runJS("window.plugins.swrve.event(\"SomeEvent\", undefined, function(forceCallback) { alert('swrve:11:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(11, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserWithPayload() {
        runJS("window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, function(forceCallback) { alert('swrve:12:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(12, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserUpdate() {
        runJS("window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, function(forceCallback) { alert('swrve:13:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(13, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserUpdateDate() {
        runJS("window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date(2016, 12, 2, 16, 20, 0, 0), function(forceCallback) { alert('swrve:14:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(14, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testCurrencyGiven() {
        runJS("window.plugins.swrve.currencyGiven(\"Gold\", 20, function(forceCallback) { alert('swrve:14:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(14, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testPurchase() {
        runJS("window.plugins.swrve.purchase(\"sword\", \"Gold\", 2, 15, function(forceCallback) { alert('swrve:14:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(14, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testIAP() {
        runJS("window.plugins.swrve.iap(2, \"sword\", 99.5, \"USD\", function(forceCallback) { alert('swrve:15:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(15, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testIapPlay() {
        runJS("window.plugins.swrve.iapPlay(\"iap_item\", 98.5, \"USD\", \"fake_purchase_data\", \"fake_purchase_signature\", function(forceCallback) { alert('swrve:16:' + forceCallback);}, undefined);");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(16, value -> {
            assertNotNull(value);
            assertEquals("OK", value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserResources() {
        runJS("window.plugins.swrve.getUserResources(function(resources) {alert('swrve:10:' + JSON.stringify(resources));}, function () {});");
        runJS("window.plugins.swrve.setResourcesListener(function(resources) { alert('swrve:40:' + JSON.stringify(resources)); });");

        final AtomicBoolean resourcesCompleted = new AtomicBoolean(false);
        final AtomicBoolean resourcesListenerCompleted = new AtomicBoolean(false);

        mActivity.getJSReturnValueAsync(10, value -> {
            assertNotNull(value);
            // Check user resources
            JSONObject userResourcesJSON = null;
            try {
                userResourcesJSON = new JSONObject(value);
                assertEquals("999", userResourcesJSON.getJSONObject("house").getString("cost"));
                resourcesCompleted.set(true);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        });

        mActivity.getJSReturnValueAsync(40, value -> {
            assertNotNull(value);

            JSONObject userResourcesListenerJSON = null;
            try {
                userResourcesListenerJSON = new JSONObject(value);
                assertEquals("999", userResourcesListenerJSON.getJSONObject("house").getString("cost"));
                resourcesListenerCompleted.set(true);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        });

        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(resourcesCompleted);
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(resourcesListenerCompleted);
    }

    @Test
    public void testUserResourcesDiff() {
        runJS("window.plugins.swrve.getUserResourcesDiff(function(resourcesDiff) {alert('swrve:20:' + JSON.stringify(resourcesDiff));}, function () {});");

        final AtomicBoolean resourcesCompleted = new AtomicBoolean(false);

        mActivity.getJSReturnValueAsync(20, value -> {
            assertNotNull(value);
            // Check user resources
            JSONObject userResourcesDiffJSON = null;
            try {
                userResourcesDiffJSON = new JSONObject(value);
                assertEquals("666", userResourcesDiffJSON.getJSONObject("new").getJSONObject("house").getString("cost"));
                assertEquals("550", userResourcesDiffJSON.getJSONObject("old").getJSONObject("house").getString("cost"));
                resourcesCompleted.set(true);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        });

        await().atMost( SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(resourcesCompleted);
    }

    @Test
    public void testCustomButtonListener() {

        runJS("window.plugins.swrve.setCustomButtonListener(function(action) { alert('swrve:22:' + action); });");
        runJS("window.plugins.swrve.event(\"campaign_trigger\", undefined, function(forceCallback) { alert('swrve:11:' + forceCallback);}, undefined);");
        Instrumentation.ActivityMonitor monitor = getInstrumentation().addMonitor(SwrveInAppMessageActivity.class.getName(), null, false);

        final AtomicBoolean eventTriggerCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(11, value -> {
            SwrveInAppMessageActivity iamActivity = null;
            SwrveMessageView innerMessage = null;
            ViewGroup parentView = null;
            
            while (iamActivity == null) {
                iamActivity = (SwrveInAppMessageActivity) monitor.getLastActivity();
            }
            while (innerMessage == null) {
                parentView = iamActivity.findViewById(android.R.id.content);
                innerMessage = (SwrveMessageView)parentView.getChildAt(0);
            }

            // Flow that will check for a SwrveButtonView on the screen and click on it and validate it.
            boolean clickedButton = false;
            int childrenViewsCount = innerMessage.getChildCount();
            for(int i = 0; i < childrenViewsCount; i++) {
                final View childView = innerMessage.getChildAt(i);
                if (childView instanceof SwrveButtonView) {
                    clickedButton = true;
                    mActivity.runOnUiThread(() -> childView.performClick());
                }
            }
            assertNotNull(iamActivity);
            assertNotNull(innerMessage);
            assertTrue(clickedButton);

            eventTriggerCompleted.set(true);
        });
        await().atMost( SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(eventTriggerCompleted);

        final AtomicBoolean receivedActionFromButton = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(22, value -> {
            assertEquals("custom_action_from_server", value);
            receivedActionFromButton .set(true);
        });
        await().atMost( SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(receivedActionFromButton);
    }

    @Test
    public void testGetUserId() {
        runJS("window.plugins.swrve.getUserId(function(userId) { alert('swrve:120:' + userId); });");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);

        mActivity.getJSReturnValueAsync(120, value -> {
            assertNotNull(value);
            hasCompleted.set(true);
        });

        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testGetMessageCenterResponse() {
        runJS("window.plugins.swrve.getMessageCenterCampaigns(function(campaigns) { alert('swrve:235:' + JSON.stringify(campaigns)); });");
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);

        mActivity.getJSReturnValueAsync(235, value -> {
            assertNotNull(value);

            JSONArray messageCentreJSON = null;
            JSONObject firstCampaign = null;

            try {
                messageCentreJSON = new JSONArray(value);
                firstCampaign = (JSONObject)messageCentreJSON.get(0);

                assertNotNull(firstCampaign);
                assertEquals(firstCampaign.getInt("ID"), 123);
                assertEquals(firstCampaign.getBoolean("messageCenter"), true);
                assertEquals(firstCampaign.getInt("maxImpressions"), 11111);
                assertEquals(firstCampaign.getInt("dateStart"), 1362671700);

                JSONObject firstCampaignState = firstCampaign.getJSONObject("state");

                assertNotNull(firstCampaignState);
                assertEquals(firstCampaign.getInt("next"), 0);
                assertEquals(firstCampaign.getInt("impressions"), 0);
                assertEquals(firstCampaign.getString("status"), "Unseen");


            } catch (Exception e) {
                e.printStackTrace();
            }

            hasCompleted.set(true);
        });

        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testShowGetMessageCenterCampaign() {
        runJS("window.plugins.swrve.showMessageCenterCampaign(123, function(forceCallback) { alert('swrve:75:' + forceCallback);}, undefined);");
        final AtomicBoolean eventTriggerCompleted = new AtomicBoolean(false);

        Instrumentation.ActivityMonitor monitor = getInstrumentation().addMonitor(SwrveInAppMessageActivity.class.getName(), null, false);

        mActivity.getJSReturnValueAsync(75, value -> {
            SwrveInAppMessageActivity iamActivity = null;
            SwrveMessageView innerMessage = null;
            ViewGroup parentView = null;
            
            while (iamActivity == null) {
                iamActivity = (SwrveInAppMessageActivity) monitor.getLastActivity();
            }
            while (innerMessage == null) {
                parentView = iamActivity.findViewById(android.R.id.content);
                innerMessage = (SwrveMessageView)parentView.getChildAt(0);
            }

            assertNotNull(iamActivity);
            assertNotNull(innerMessage);
            eventTriggerCompleted.set(true);
        });
        await().atMost( SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(eventTriggerCompleted);
    }

    @Test
    public void testRemoveMessageCenterCampaign() throws Exception {

        swrveMock = Mockito.mock(ISwrve.class);
        SwrveBaseCampaign mockCampaign = Mockito.mock(SwrveBaseCampaign.class);
        Mockito.doReturn(44).when(mockCampaign).getId();

        ArrayList<SwrveBaseCampaign> realList = new ArrayList<>();
        realList.add(mockCampaign);

        Mockito.doReturn(realList).when(swrveMock).getMessageCenterCampaigns();
        Mockito.doNothing().when(swrveMock).removeMessageCenterCampaign(Mockito.any());
        SwrveTestHelper.setSDKInstance(swrveMock);

        runJS("window.plugins.swrve.removeMessageCenterCampaign(44, function(forceCallback) { alert('swrve:85:' + forceCallback);}, undefined);");

        final AtomicBoolean hasCompleted = new AtomicBoolean(false);

        mActivity.getJSReturnValueAsync(85, value -> {
            Mockito.verify(swrveMock, Mockito.atLeast(1)).getMessageCenterCampaigns();
            Mockito.verify(swrveMock, Mockito.atLeast(1)).removeMessageCenterCampaign(mockCampaign);
            hasCompleted.set(true);
        });

        await().atMost( SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testCustomPushPayloadListener() throws Exception {
        runJS("window.plugins.swrve.setPushNotificationListener(function(payload) { alert('swrve:40:' + payload); });");

        Instrumentation.ActivityMonitor monitor = getInstrumentation().addMonitor(MainActivity.class.getName(), null, false);
        int retries = 20;
        String payloadJSON;
        SwrveNotificationEngageReceiver pushEngageReceiver = new SwrveNotificationEngageReceiver();
        do {
            Intent intent = getFirebaseIntent(retries, "custom", "custom_payload");
            pushEngageReceiver.onReceive(getInstrumentation().getTargetContext().getApplicationContext(), intent);

            payloadJSON = mActivity.getJSReturnValue(40);
            if (payloadJSON == null) {
                Thread.sleep(1000);
            }
        } while(retries-- > 0 && payloadJSON == null);
        assertNotNull(payloadJSON);

        MainActivity startedActivity = (MainActivity)getInstrumentation().waitForMonitor(monitor);
        startedActivity.finish();
    }

}
