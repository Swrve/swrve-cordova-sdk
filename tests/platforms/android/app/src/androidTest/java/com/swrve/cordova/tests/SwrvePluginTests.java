package com.swrve.cordova.tests;

import android.app.Instrumentation;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.swrve.sdk.SwrveIdentityResponse;
import com.swrve.sdk.SwrvePushNotificationListener;
import com.swrve.sdk.SwrveSilentPushListener;
import com.swrve.sdk.SwrveUserResourcesDiffListener;
import com.swrve.sdk.SwrveUserResourcesListener;
import com.swrve.sdk.messaging.SwrveBaseCampaign;
import com.swrve.sdk.messaging.SwrveCampaignState;
import com.swrve.sdk.messaging.SwrveCustomButtonListener;
import com.swrve.sdk.messaging.ui.SwrveInAppMessageActivity;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.junit.Assert;
import org.junit.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;
import org.mockito.stubbing.Answer;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import static android.support.test.InstrumentationRegistry.getInstrumentation;
import static org.awaitility.Awaitility.await;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.mockito.Mockito.doAnswer;

public class SwrvePluginTests extends SwrvePluginBaseTests {

    // NOTE: Any JS failure might affect the next run. If the UI does not appear
    // in the test run it is a sign that there was an error.

    @Test
    public void testEvents() throws  Exception {

        runJS("window.plugins.swrve.event(\"levelup\", undefined, undefined);");
        runJS("window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, undefined, undefined);");
        runJS("window.plugins.swrve.currencyGiven(\"Gold\", 20, undefined, undefined);");
        runJS("window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, undefined, undefined);");
        runJS("window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date('2019-01-02T10:00'), function(forceCallback) { alert('swrve:5:' + forceCallback);}, undefined);");
        runJS("window.plugins.swrve.sendEvents(function(successCallback) { alert('swrve:1:' + successCallback);}, undefined);");

        // Create some expectation for our tests, so we are sure that we reach our SDK and we do have the expected parameters as well.
        Map<String, String> expectedMapLevelEvent = new HashMap<String, String>();
        expectedMapLevelEvent.put("armor", "disabled");

        Map<String, String> expectedMapUpdate1 = new HashMap<String, String>();
        expectedMapUpdate1.put("cordova", "TRUE");

        String dtStart = "2019-01-02T10:00";
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm");
        Date expectedDate = format.parse(dtStart);

        // Verify if each call rly get called.
        Mockito.verify(swrveMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).event("levelup");
        Mockito.verify(swrveMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).event("leveldown", expectedMapLevelEvent);
        Mockito.verify(swrveMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).currencyGiven("Gold", 20);
        Mockito.verify(swrveMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).userUpdate(expectedMapUpdate1);
        Mockito.verify(swrveMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).userUpdate("last_subscribed", expectedDate);

        // Check the JS Callback
        final AtomicBoolean sendEventsCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(1, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).sendQueuedEvents();
            sendEventsCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_LONG, TimeUnit.SECONDS).untilTrue(sendEventsCompleted);
    }

    @Test
    public void testEvent() {
        runJS("window.plugins.swrve.event(\"SomeEvent\", undefined, function(forceCallback) { alert('swrve:2:' + forceCallback);}, undefined);");

        // Test JS Callback
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(2, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).event("SomeEvent");
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserWithPayload() {

        // Mock and expectations for the test
        Mockito.doNothing().when(swrveMock).event(Mockito.anyString(), Mockito.anyMap());
        Map<String, String> expectedMap = new HashMap<String, String>();
        expectedMap.put("armor", "disabled");

        runJS("window.plugins.swrve.event(\"leveldown\", {\"armor\":\"disabled\"}, function(forceCallback) { alert('swrve:3:' + forceCallback);}, undefined);");

        // Test JS Callback
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(3, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).event("leveldown", expectedMap);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserUpdate() {

        // Mock and expectations for the test
        Map<String, String> expectedMap = new HashMap<String, String>();
        expectedMap.put("cordova", "TRUE");

        runJS("window.plugins.swrve.userUpdate({\"cordova\":\"TRUE\"}, function(forceCallback) { alert('swrve:4:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(4, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).userUpdate(expectedMap);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserUpdateDate() throws Exception {

        // Mock and expectations for the test
        String dtStart = "2019-01-02T10:00";
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm");
        Date expectedDate = format.parse(dtStart);

        runJS("window.plugins.swrve.userUpdateDate(\"last_subscribed\", new Date('2019-01-02T10:00'), function(forceCallback) { alert('swrve:5:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(5, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).userUpdate("last_subscribed", expectedDate);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testCurrencyGiven() {

        runJS("window.plugins.swrve.currencyGiven(\"Gold\", 20, function(forceCallback) { alert('swrve:6:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(6, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).currencyGiven("Gold", 20);
            hasCompleted.set(true);
        });

        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testPurchase() {

        runJS("window.plugins.swrve.purchase(\"sword\", \"Gold\", 1, 99, function(forceCallback) { alert('swrve:7:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(7, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).purchase("sword", "Gold", 99, 1);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testIAP() {

        runJS("window.plugins.swrve.iap(2, \"sword\", 99.5, \"USD\", function(forceCallback) { alert('swrve:8:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(8, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).iap(2, "sword", 99.5, "USD");
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testIapPlay() {

        runJS("window.plugins.swrve.iapPlay(\"iap_item\", 98.5, \"USD\", \"fake_purchase_data\", \"fake_purchase_signature\", function(forceCallback) { alert('swrve:9:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(9, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).iapPlay("iap_item",98.5,"USD","fake_purchase_data","fake_purchase_signature");
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testUserResources() {

        Map<String, String> resources = new HashMap<>();
        resources.put("uid", "MySweetUUID");
        resources.put("name", "house");
        resources.put("cost", "999");
        Map<String, Map<String, String>> expectedResources = new HashMap<>();
        expectedResources .put("MySweetUUID", resources);

        // Mocked resources callback
        doAnswer((Answer<Void>) invocation -> {
            SwrveUserResourcesListener listener = (SwrveUserResourcesListener) invocation.getArguments()[0];
            listener.onUserResourcesSuccess(expectedResources , "some json");
            return null;
        }).when(swrveMock).getUserResources(Mockito.any(SwrveUserResourcesListener.class));

        runJS("window.plugins.swrve.getUserResources(function(resources) {alert('swrve:10:' + JSON.stringify(resources));}, function () {});");

        // Test JS Callback
        final AtomicBoolean resourcesCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(10, value -> {
            Map<String, Object> returnedResources = new Gson().fromJson(
                    value , new TypeToken<HashMap<String, Object>>() {}.getType()
            );
            assertEquals(returnedResources, expectedResources);
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).getUserResources(Mockito.any());
            resourcesCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(resourcesCompleted);
    }


    @Test
    public void testUserResourcesDiff() {
        Map<String, String> oldResources = new HashMap<>();
        oldResources.put("uid", "old_uid");
        oldResources.put("name", "houseOld");
        oldResources.put("cost", "999");

        Map<String, String> newExpectedResources= new HashMap<>();
        newExpectedResources.put("uid", "new_uid");
        newExpectedResources.put("name", "houseNew");
        newExpectedResources.put("cost", "999");

        Map<String, Map<String, String>> expectedOldResources = new HashMap<>();
        expectedOldResources .put("old", oldResources);
        Map<String, Map<String, String>> expectedNewResources = new HashMap<>();
        expectedNewResources.put("new", newExpectedResources);

        // Mocked getUserResourcesDiff callback
        doAnswer((Answer<Void>) invocation -> {
            SwrveUserResourcesDiffListener listener = (SwrveUserResourcesDiffListener) invocation.getArguments()[0];
            listener.onUserResourcesDiffSuccess(expectedOldResources, expectedNewResources, "some json");
            return null;
        }).when(swrveMock).getUserResourcesDiff(Mockito.any(SwrveUserResourcesDiffListener.class));

        runJS("window.plugins.swrve.getUserResourcesDiff(function(resourcesDiff) {alert('swrve:12:' + JSON.stringify(resourcesDiff));}, function () {});");

        // Test JS Callback
        final AtomicBoolean resourcesDiffCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(12, value -> {
            Map<String, Object> map = new Gson().fromJson(
                    value , new TypeToken<HashMap<String, Object>>() {}.getType()
            );
            assertEquals(map.get("old"), expectedOldResources);
            assertEquals(map.get("new"), expectedNewResources);

            Mockito.verify(swrveMock, Mockito.atLeastOnce()).getUserResourcesDiff(Mockito.any());
            resourcesDiffCompleted .set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(resourcesDiffCompleted );
    }

    @Test
    public void testCustomButtonListener() {

        final String expectedAction = "custom_action_from_server";
        runJS("window.plugins.swrve.setCustomButtonListener(function(action) { alert('swrve:13:' + action); });");

        ArgumentCaptor<SwrveCustomButtonListener> customButtonListenerCaptor = ArgumentCaptor.forClass(SwrveCustomButtonListener.class);
        Mockito.verify(swrveMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).setCustomButtonListener(customButtonListenerCaptor.capture());
        customButtonListenerCaptor.getValue().onAction(expectedAction);

        final AtomicBoolean receivedActionFromButton = new AtomicBoolean(false);

        mActivity.getJSReturnValueAsync(13, value -> {
            assertEquals(expectedAction, value);
            receivedActionFromButton.set(true);
        });

        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(receivedActionFromButton);
    }

    @Test
    public void testGetExternalUserId() {

        // Mock and expectations for the test
        final String mockedExternalUserId = "mockedExternalUserId";
        Mockito.doReturn(mockedExternalUserId).when(swrveMock).getExternalUserId();

        runJS("window.plugins.swrve.getExternalUserId(function(forceCallback) { alert('swrve:14:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(14, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).getExternalUserId();
            assertEquals(mockedExternalUserId, value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testGetUserId() {

        // Mock and expectations for the test
        final String mockedUserId = "mockedUserId";
        Mockito.doReturn(mockedUserId).when(swrveMock).getUserId();

        runJS("window.plugins.swrve.getUserId(function(forceCallback) { alert('swrve:15:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(15, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).getUserId();
            assertEquals(mockedUserId, value);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testGetMessageCenterResponse() throws Exception{

        // Mock an all the campaign that we use in our Plugin layer.
        SwrveBaseCampaign mockCampaign = Mockito.mock(SwrveBaseCampaign.class);
        final int expectedId = 123;
        final int expectedMaxImpressions = 10;
        final String expectedSubject = "MySweetSubject";
        final int expectedImpressions = 1;
        final boolean expectedMessageCenter = true;

        Mockito.doReturn(expectedId).when(mockCampaign).getId();
        Mockito.doReturn(expectedMaxImpressions).when(mockCampaign).getMaxImpressions();
        Mockito.doReturn(expectedSubject).when(mockCampaign).getSubject();
        Mockito.doReturn(expectedMessageCenter).when(mockCampaign).isMessageCenter();
        Mockito.doReturn(expectedImpressions).when(mockCampaign).getImpressions();
        Mockito.doReturn(new SwrveCampaignState()).when(mockCampaign).getSaveableState();

        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm");
        String dtStart = "2019-01-02T10:00";
        final Date expectedStartDate = format.parse(dtStart);

        Mockito.doReturn(expectedId).when(mockCampaign).getId();
        Mockito.doReturn(expectedStartDate).when(mockCampaign).getStartDate();
        final String expectedStartDateAsTimeStamp = ""+mockCampaign.getStartDate().getTime() / 1000;

        ArrayList<SwrveBaseCampaign> realList = new ArrayList<>();
        realList.add(mockCampaign);

        Mockito.doReturn(realList).when(swrveMock).getMessageCenterCampaigns();


        runJS("window.plugins.swrve.getMessageCenterCampaigns(function(campaigns) { alert('swrve:16:' + JSON.stringify(campaigns)); });");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(16, value -> {

            JSONArray messageCentreJSON = null;
            JSONObject firstCampaign = null;

            try {
                messageCentreJSON = new JSONArray(value);
                firstCampaign = (JSONObject) messageCentreJSON.get(0);

                assertNotNull(firstCampaign);
                assertEquals(firstCampaign.getInt("ID"), expectedId);
                assertEquals(firstCampaign.getInt("maxImpressions"), expectedMaxImpressions);
                assertEquals(firstCampaign.getInt("subject"), expectedSubject);
                assertEquals(firstCampaign.getBoolean("messageCenter"), expectedMessageCenter);
                assertEquals(firstCampaign.getInt("dateStart"), expectedStartDateAsTimeStamp);

                JSONObject campaignState = firstCampaign.getJSONObject("state");
                assertNotNull(campaignState);
                assertEquals(campaignState.getInt("next"), 0);
                assertEquals(campaignState.getInt("impressions"), 0);
                assertEquals(campaignState.getInt("impressions"), 0);
                assertEquals(campaignState.getString("status"), "Unseen");
            } catch (Exception e) {
                e.printStackTrace();
            }
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testShowGetMessageCenterCampaign() {

        // Mock an all the campaign that we use in our Plugin layer.
        SwrveBaseCampaign expectedCampain = Mockito.mock(SwrveBaseCampaign.class);
        Mockito.doReturn(123).when(expectedCampain).getId();
        ArrayList<SwrveBaseCampaign> realList = new ArrayList<>();
        realList.add(expectedCampain);
        Mockito.doReturn(realList).when(swrveMock).getMessageCenterCampaigns();

        runJS("window.plugins.swrve.showMessageCenterCampaign(123, function(forceCallback) { alert('swrve:17:' + forceCallback);}, undefined);");
        final AtomicBoolean eventTriggerCompleted = new AtomicBoolean(false);

        Instrumentation.ActivityMonitor monitor = getInstrumentation().addMonitor(SwrveInAppMessageActivity.class.getName(), null, false);

        mActivity.getJSReturnValueAsync(17, value -> {

            Mockito.verify(swrveMock, Mockito.atLeastOnce()).showMessageCenterCampaign(expectedCampain);
            eventTriggerCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(eventTriggerCompleted);
    }

    @Test
    public void testRemoveMessageCenterCampaign() {

        // Mock and expectations for the test
        SwrveBaseCampaign mockCampaign = Mockito.mock(SwrveBaseCampaign.class);
        Mockito.doReturn(44).when(mockCampaign).getId();

        ArrayList<SwrveBaseCampaign> realList = new ArrayList<>();
        realList.add(mockCampaign);

        Mockito.doReturn(realList).when(swrveMock).getMessageCenterCampaigns();
        Mockito.doNothing().when(swrveMock).removeMessageCenterCampaign(Mockito.any());

        runJS("window.plugins.swrve.removeMessageCenterCampaign(44, function(forceCallback) { alert('swrve:18:' + forceCallback);}, undefined);");

        // Test the JS Callback.
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(18, value -> {
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).getMessageCenterCampaigns();
            Mockito.verify(swrveMock, Mockito.atLeastOnce()).removeMessageCenterCampaign(mockCampaign);
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testCustomPushPayloadListener() throws Exception {

        final String expectedArmor = "disabled";
        runJS("window.plugins.swrve.setPushNotificationListener(function(payload) { alert('swrve:19:' + JSON.stringify(payload)); });");
        Thread.sleep(1000);

        ArgumentCaptor<SwrvePushNotificationListener> customPushNotificationListenerCaptor = ArgumentCaptor.forClass(SwrvePushNotificationListener.class);
        Mockito.verify(configMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).setNotificationListener(customPushNotificationListenerCaptor.capture());
        customPushNotificationListenerCaptor.getValue().onPushNotification(new JSONObject("{\"armor\":"+expectedArmor+"}"));

        final AtomicBoolean receivedPushNotification = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(19, value -> {
            try {
                JSONObject payloadAsJson = new JSONObject(value);
                assertNotNull(value);
                Assert.assertEquals(expectedArmor, payloadAsJson.getString("armor"));
                receivedPushNotification.set(true);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(receivedPushNotification);
    }

    @Test
    public void testSilentPushPayloadListener() throws Exception {

        final String expectedArmor = "disabled";
        runJS("window.plugins.swrve.setSilentPushNotificationListener(function(payload) { alert('swrve:20:' + JSON.stringify(payload)); });");
        Thread.sleep(1000);

        ArgumentCaptor<SwrveSilentPushListener> customSilentPushNotificationListenerCaptor = ArgumentCaptor.forClass(SwrveSilentPushListener.class);
        Mockito.verify(configMock, Mockito.timeout(SwrveTestHelper.WAITING_SHORT_MILLISEC).atLeastOnce()).setSilentPushListener(customSilentPushNotificationListenerCaptor.capture());
        customSilentPushNotificationListenerCaptor.getValue().onSilentPush(null, new JSONObject("{\"armor\":"+expectedArmor+"}"));

        final AtomicBoolean receivedSilentPushNotification = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(20, value -> {
            try {
                JSONObject payloadAsJson = new JSONObject(value);
                assertNotNull(value);
                Assert.assertEquals(expectedArmor, payloadAsJson.getString("armor"));
                receivedSilentPushNotification.set(true);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(receivedSilentPushNotification);
    }

    @Test
    public void testIdentifySuccess() {

        String expectedStatus = "loaded From cache";
        String expectedSwrveID = "UUID_FOR_TESTING";

        // Mocked identify callback
        doAnswer((Answer<Void>) invocation -> {
            SwrveIdentityResponse listener = (SwrveIdentityResponse) invocation.getArguments()[1];
            listener.onSuccess(expectedStatus , expectedSwrveID);
            return null;
        }).when(swrveMock).identify(Mockito.eq("testUserId"), Mockito.any(SwrveIdentityResponse.class));

        runJS("window.plugins.swrve.identify(\"testUserId\", function(response) { alert('swrve:21:' + JSON.stringify(response));}, undefined);");

        // Test JS Callback
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(21, value -> {
            try {
                JSONObject jsonObject = new JSONObject(value);
                Assert.assertEquals(expectedStatus, jsonObject.getString("status"));
                Assert.assertEquals(expectedSwrveID, jsonObject.getString("swrveId"));

            } catch (JSONException e) {
                e.printStackTrace();
            }

            Mockito.verify(swrveMock, Mockito.atLeastOnce()).identify(Mockito.eq("testUserId"), Mockito.any(SwrveIdentityResponse.class));
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

    @Test
    public void testIdentifyError() {
        int expectedResponse = 500;
        String expectedErrorMessage = "TEST ERROR MESSAGE";

        // Mocked identify callback
        doAnswer((Answer<Void>) invocation -> {
            SwrveIdentityResponse listener = (SwrveIdentityResponse) invocation.getArguments()[1];
            listener.onError(expectedResponse , expectedErrorMessage);
            return null;
        }).when(swrveMock).identify(Mockito.eq("testUserId"), Mockito.any(SwrveIdentityResponse.class));

        runJS("window.plugins.swrve.identify(\"testUserId\", undefined,  function(response) { alert('swrve:22:' + JSON.stringify(response));});");

        // Test JS Callback
        final AtomicBoolean hasCompleted = new AtomicBoolean(false);
        mActivity.getJSReturnValueAsync(22, value -> {
            try {
                JSONObject jsonObject = new JSONObject(value);
                Assert.assertEquals(expectedResponse, jsonObject.getInt("reseponseCode"));
                Assert.assertEquals(expectedErrorMessage, jsonObject.getString("errorMessage"));

            } catch (JSONException e) {
                e.printStackTrace();
            }

            Mockito.verify(swrveMock, Mockito.atLeastOnce()).identify(Mockito.eq("testUserId"), Mockito.any(SwrveIdentityResponse.class));
            hasCompleted.set(true);
        });
        await().atMost(SwrveTestHelper.WAITING_SHORT, TimeUnit.SECONDS).untilTrue(hasCompleted);
    }

}
