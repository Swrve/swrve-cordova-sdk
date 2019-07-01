# Swrve SDK Cordova Plugin

## What is Swrve

Swrve is a single integrated platform delivering everything you need to drive mobile engagement and create valuable consumer relationships on mobile.  This Cordova plugin will enable your app to use all of these features on Android and iOS.

## Getting started

We recommend you read our [integration guide](http://docs.swrve.com/developer-documentation/integration/cordova/) before attempting to download and add the sourcecode yourself.

The SDK uses [Cordova hooks](https://cordova.apache.org/docs/en/latest/guide/appdev/hooks/) which allow us to modify the generated code as part of the plugin installation to the platform.
We currently use the `after_plugin_install` and `after_prepare` hook to include the native changes needed to kick off the Swrve Native SDK side of the Plugin.

## Sample Template

If you are starting with a fresh application, there is a [template available](https://github.com/Swrve/swrve-cordova-minimal-integration.git) which we recommend using.
This can be added with the following command replacing `hello`, `com.example.hello` and `HelloWorld` with your own desired attributes:

```bash
cordova create hello com.example.hello HelloWorld --template https://github.com/Swrve/swrve-cordova-minimal-integration.git
```

## Testing

We have provided tests inside the `/tests` directory which is a cordova app template which verifies the connection between Swrve Native SDKs for iOS and Android and our Cordova Plugin.
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
