# Swrve SDK Cordova Plugin

## What is Swrve

Swrve is a single integrated platform delivering everything you need to drive mobile engagement and create valuable consumer relationships on mobile.  This Cordova plugin will enable your app to use all of these features on Android and iOS.

## Getting started

We recommend you read our [integration guide](http://docs.swrve.com/developer-documentation/integration/cordova/) before attempting to download and add to the sourcecode yourself.

The SDK uses [Cordova hooks](https://cordova.apache.org/docs/en/latest/guide/appdev/hooks/) which allow us to modify the generated code as part of the plugin installation to the platform.
We currently use the `after_plugin_install` and `after_prepare` hook to include the native changes needed to kick off the Swrve Native SDK side of the Plugin.

## Sample Template

If you are starting with a fresh application, there is a [template available](https://github.com/Swrve/swrve-cordova-minimal-integration.git) which we recommend using.
This can be added with the following command replacing `hello`, `com.example.hello` and `HelloWorld` with your own desired attributes:

```bash
cordova create hello com.example.hello HelloWorld --template https://github.com/Swrve/swrve-cordova-minimal-integration.git
```

## Preferences that are available on Swrve Cordova SDK

Our SDK uses a series of hooks to inject code to the final iOS/Android project. Below, we provide a table with all available preferences the SwrveSDK can interpret.

### Preferences availables for iOS/Android

 Preference | Description | type |
| --- | --- | --- |
| `swrve.appId` | Swrve **App Id** |  string |
| `swrve.apiKey` | Swrve **API Key** | string |  
| `swrve.pushEnabled` | Include and enable push notifications. | boolean|
| `swrve.adJourneyEnabled` | Include and enable ad journey support. | boolean|

### Preferences only available on Android

 Preference | Description | type |
| --- | --- | --- |
| `swrve.handlingGoogleServices` | Set true if you are handling your own Google Services setup and don't want Swrve to alter anything associated with it. This will also make sure that the SwrveFirebaseMessagingService is not added. | boolean |
| `swrve.drawablePath` | Local path that points to your icon files that are used for Android push notifications. | string |
| `swrve.googleServicesPath` | Path for your local google-services.json file that is **required** to use Android push notifications.  | string |

### Preferences only available on iOS

 Preference | Description | type |
| --- | --- | --- |
| `swrve.appGroupIdentifier` | This is an application group identifier that is used for push notification influence tracking. |  string |
| `swrve.clearPushBadgeOnStartup` | When enabled, the application clears any notification badges from the app icon when the app starts. | boolean |  
| `swrve.pushNotificationEvent` | Event that triggers the push notification permission request. Include if you do not want to ask for push permissions on startup. | string |
| `swrve.provisionalPushNotificationEvent` | Event that triggers token retrieval for provisional push notifications. | string |

## Testing

We have provided tests inside the `/tests` directory contains cordova project which verifies the connection between Swrve Native SDKs for iOS and Android and our Cordova Plugin along with tests for our hook system.
These have complete projects included so you can simply open them and run them without using any cordova commands.

## Contributing

We would love to see your contributions! Follow these steps:

1. Fork this repository.
2. Create a branch (`git checkout -b my_awesome_cordova_feature`)
3. Commit your changes (`git commit -m "Awesome Cordova feature"`)
4. Push to the branch (`git push origin my_awesome_cordova_feature`)
5. Open a Pull Request.

## License

© Copyright Swrve Mobile Inc or its licensors. Distributed under the [Apache 2.0 License](LICENSE).
