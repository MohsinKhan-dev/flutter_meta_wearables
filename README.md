# flutter_meta_wearables

A Flutter plugin for the **Meta Wearables Device Access Toolkit (DAT) SDK**. This plugin provides a cross-platform Dart API for connecting to Ray-Ban Meta smart glasses, streaming live video from the device camera, and capturing photos.

## Features

- **Device Registration** - OAuth-based registration flow via Meta AI app
- **BLE Device Discovery** - Real-time stream of connected wearable devices
- **Live Video Streaming** - Zero-copy video rendering using Flutter's Texture API at up to 24fps
- **Photo Capture** - Capture JPEG photos from the wearable camera during a stream session
- **Permission Management** - Check and request wearable camera permissions
- **MockDeviceKit** - Test your app without physical hardware using simulated devices
- **Deep Link Handling** - iOS OAuth callback URL handling built-in

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
  - [1. Add the Dependency](#1-add-the-dependency)
  - [2. SDK Access Setup](#2-sdk-access-setup)
  - [3. Android Configuration](#3-android-configuration)
  - [4. iOS Configuration](#4-ios-configuration)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [MetaWearables (Singleton)](#metawearables-singleton)
  - [MetaWearablesStreamSession](#metawearablesstreamession)
  - [WearableVideoView (Widget)](#wearablevideoview-widget)
  - [MockDeviceKit](#mockdevicekit)
  - [MockDevice](#mockdevice)
- [Data Models](#data-models)
  - [RegistrationState](#registrationstate)
  - [DeviceIdentifier](#deviceidentifier)
  - [WearablePermission](#wearablepermission)
  - [PermissionStatus](#permissionstatus)
  - [StreamConfiguration](#streamconfiguration)
  - [VideoQuality](#videoquality)
  - [StreamSessionState](#streamsessionstate)
  - [VideoFrameInfo](#videoframeinfo)
  - [PhotoData](#photodata)
  - [StreamError](#streamerror)
  - [DeviceCompatibility](#devicecompatibility)
  - [MetaWearablesException](#metawearablesexception)
- [Usage Guide](#usage-guide)
  - [Initialization](#initialization)
  - [Device Registration](#device-registration)
  - [Listening for Devices](#listening-for-devices)
  - [Permissions](#permissions)
  - [Video Streaming](#video-streaming)
  - [Photo Capture](#photo-capture)
  - [Using the Video Widget](#using-the-video-widget)
  - [Deep Link Handling (iOS)](#deep-link-handling-ios)
  - [Testing with MockDeviceKit](#testing-with-mockdevicekit)
  - [Cleanup](#cleanup)
- [Architecture](#architecture)
  - [Plugin Structure](#plugin-structure)
  - [Video Streaming Strategy](#video-streaming-strategy)
  - [Platform Channel Definitions](#platform-channel-definitions)
- [Example App](#example-app)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| Flutter  | 3.3.0+         |
| Dart     | 3.11.0+        |
| Android  | API 31 (Android 12) |
| iOS      | 17.0+          |

You also need access to the Meta Wearables DAT SDK:
- **Android**: Access to the Maven repository at `maven.pkg.github.com/facebook/meta-wearables-dat-android`
- **iOS**: Access to the Swift Package at `github.com/facebook/meta-wearables-dat-ios`

## Installation

### 1. Add the Dependency

Add this plugin to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_meta_wearables:
    path: ../flutter_meta_wearables  # Adjust path as needed
```

### 2. SDK Access Setup

The Meta Wearables DAT SDK is distributed via GitHub Packages and requires a GitHub personal access token with `read:packages` scope.

**Generate a token:**
1. Go to [GitHub Settings > Personal Access Tokens](https://github.com/settings/tokens)
2. Create a token with `read:packages` scope
3. Set the token as an environment variable or in `local.properties`

**Option A - Environment variable:**
```bash
export GITHUB_TOKEN=ghp_your_token_here
```

**Option B - local.properties (Android):**
```properties
# android/local.properties
github_token=ghp_your_token_here
```

### 3. Android Configuration

**a) Set minSdk to 31** in your app's `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 31
    }
}
```

**b) Add the MWDAT Maven repository** to your `android/settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/facebook/meta-wearables-dat-android")
            credentials {
                username = ""
                password = System.getenv("GITHUB_TOKEN")
                    ?: run {
                        val properties = java.util.Properties()
                        val localPropertiesFile = file("local.properties")
                        if (localPropertiesFile.exists()) {
                            localPropertiesFile.inputStream().use { properties.load(it) }
                        }
                        properties.getProperty("github_token", "")
                    }
            }
        }
    }
}
```

**c) Add permissions and MWDAT meta-data** to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application ...>
        <!-- Set with your ID from Wearables Developer Center -->
        <meta-data
            android:name="com.meta.wearable.mwdat.APPLICATION_ID"
            android:value="YOUR_META_APP_ID" />

        <activity ...>
            <!-- Deep link for MWDAT OAuth callback -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.BROWSABLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:scheme="your-app-scheme" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 4. iOS Configuration

**a) Set iOS deployment target to 17.0** in your `ios/Podfile`:

```ruby
platform :ios, '17.0'
```

**b) Add MWDAT SDK via Swift Package Manager.** In Xcode, go to File > Add Package Dependencies and add:
```
https://github.com/facebook/meta-wearables-dat-ios
```
Add the products: `MWDATCore`, `MWDATCamera`, and `MWDATMockDevice`.

**c) Configure `ios/Runner/Info.plist`:**

```xml
<!-- MWDAT SDK Configuration -->
<key>MWDAT</key>
<dict>
    <key>AppLinkURLScheme</key>
    <string>your-app-scheme://</string>
    <key>MetaAppID</key>
    <string>YOUR_META_APP_ID</string>
    <key>ClientToken</key>
    <string>YOUR_CLIENT_TOKEN</string>
    <key>TeamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>

<!-- URL Scheme for OAuth callback -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>your-app-scheme</string>
        </array>
    </dict>
</array>

<!-- Bluetooth & External Accessory -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to Ray-Ban Meta smart glasses.</string>
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>com.meta.ar.wearable</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-peripheral</string>
    <string>external-accessory</string>
</array>
```

---

## Quick Start

```dart
import 'package:flutter_meta_wearables/flutter_meta_wearables.dart';

// 1. Initialize
final wearables = MetaWearables.instance;
await wearables.initialize();

// 2. Listen for registration state
wearables.registrationState.listen((state) {
  print('Registration: ${state.name}');
});

// 3. Register (opens Meta AI app)
await wearables.startRegistration();

// 4. Listen for devices
wearables.devices.listen((devices) {
  print('Found ${devices.length} devices');
});

// 5. Check permissions & start streaming
final status = await wearables.checkPermissionStatus(WearablePermission.camera);
if (status == PermissionStatus.granted) {
  final session = await wearables.startStreamSession();

  // 6. Display video
  // Use Texture(textureId: session.textureId) or WearableVideoView widget

  // 7. Capture a photo
  final photo = await session.capturePhoto();
  print('Photo: ${photo.width}x${photo.height}, ${photo.bytes.length} bytes');

  // 8. Stop
  await session.stop();
}

// 9. Cleanup
await wearables.dispose();
```

---

## API Reference

### MetaWearables (Singleton)

The primary entry point for all plugin operations. Access via `MetaWearables.instance`.

| Method / Property | Return Type | Description |
|---|---|---|
| `initialize()` | `Future<void>` | Initialize the MWDAT SDK. Must be called before any other method. |
| `startRegistration()` | `Future<void>` | Launch the Meta AI OAuth registration flow. On Android, opens the Meta AI app Activity. On iOS, triggers the async registration. |
| `startUnregistration()` | `Future<void>` | Unregister / disconnect the current device. |
| `registrationState` | `Stream<RegistrationState>` | Stream of registration state changes. Emits whenever the state transitions (e.g., `registering` -> `registered`). |
| `devices` | `Stream<List<DeviceIdentifier>>` | Stream of discovered wearable devices. Updates whenever devices connect or disconnect. |
| `checkPermissionStatus(permission)` | `Future<PermissionStatus>` | Check the current status of a wearable permission without prompting the user. |
| `requestPermission(permission)` | `Future<PermissionStatus>` | Request a wearable permission. May show a system prompt to the user. |
| `handleUrl(url)` | `Future<bool>` | Handle a deep link URL (used for iOS OAuth callback). Returns `true` if the URL was handled. |
| `startStreamSession({configuration})` | `Future<MetaWearablesStreamSession>` | Start a video streaming session. Returns a session object with a `textureId` for rendering. |
| `mockDeviceKit` | `MockDeviceKit?` | Access to the MockDeviceKit for testing. Available after `initialize()`. |
| `dispose()` | `Future<void>` | Release all resources held by the SDK. |

### MetaWearablesStreamSession

Represents an active video streaming session from a wearable device camera.

| Property / Method | Type | Description |
|---|---|---|
| `textureId` | `int` | The Flutter texture ID for rendering. Use with `Texture(textureId: session.textureId)` or `WearableVideoView`. |
| `state` | `Stream<StreamSessionState>` | Stream of session state changes (stopped, starting, streaming, etc.). |
| `videoFrameInfo` | `Stream<VideoFrameInfo>` | Stream of video frame metadata. Emits on every frame with width, height, and timestamp. |
| `errors` | `Stream<StreamError>` | Stream of streaming errors (device disconnection, timeout, permission denied, etc.). |
| `capturePhoto()` | `Future<PhotoData>` | Capture a JPEG photo from the current video stream. Returns the photo bytes, width, and height. |
| `stop()` | `Future<void>` | Stop the streaming session and release resources. |

### WearableVideoView (Widget)

A convenience widget that wraps Flutter's `Texture` widget with automatic aspect ratio handling and placeholder support.

```dart
WearableVideoView(
  session: session,               // Required: the active stream session
  fit: BoxFit.contain,            // Optional: how to fit the video (default: BoxFit.contain)
  placeholder: CircularProgressIndicator(), // Optional: shown while not streaming
)
```

**Behavior:**
- Automatically adjusts aspect ratio based on incoming `VideoFrameInfo`
- Shows the `placeholder` widget when the session is not in the `streaming` state
- Uses `FittedBox` with the specified `BoxFit` to scale the video texture

### MockDeviceKit

Provides access to simulated Ray-Ban Meta devices for testing without physical hardware. Available via `MetaWearables.instance.mockDeviceKit` after initialization.

| Method | Return Type | Description |
|---|---|---|
| `pairRaybanMeta()` | `Future<MockDevice>` | Create and pair a simulated Ray-Ban Meta glasses device. |
| `unpairDevice(device)` | `Future<void>` | Unpair and remove a mock device. |

### MockDevice

Represents a simulated wearable device for testing.

| Property / Method | Type | Description |
|---|---|---|
| `deviceId` | `String` | The unique identifier for this mock device. |
| `powerOn()` | `Future<void>` | Simulate powering on the device. |
| `powerOff()` | `Future<void>` | Simulate powering off the device. |
| `don()` | `Future<void>` | Simulate putting on the glasses (donning). |
| `doff()` | `Future<void>` | Simulate taking off the glasses (doffing). |
| `fold()` | `Future<void>` | Simulate folding the glasses hinges. |
| `unfold()` | `Future<void>` | Simulate unfolding the glasses hinges. |
| `setCameraFeed(filePath)` | `Future<void>` | Set a video file as the mock camera feed. This video will be streamed when a `StreamSession` is active. |
| `setCapturedImage(filePath)` | `Future<void>` | Set an image file as the mock captured photo. This image is returned when `capturePhoto()` is called. |

---

## Data Models

### RegistrationState

The registration state of the device with the Meta AI service.

```dart
enum RegistrationState {
  unavailable,    // SDK not configured or registration not available
  registering,    // Registration in progress (Meta AI app flow active)
  registered,     // Successfully registered and connected
  unregistering,  // Unregistration in progress
}
```

### DeviceIdentifier

Identifies a discovered wearable device.

```dart
class DeviceIdentifier {
  final String id;       // Unique device identifier
  final String? name;    // Human-readable device name (may be null)
}
```

Equality is based on `id` only, so two `DeviceIdentifier` objects with the same `id` are considered equal regardless of `name`.

### WearablePermission

Permissions that can be requested for wearable devices.

```dart
enum WearablePermission {
  camera,  // Permission to access the wearable device camera
}
```

### PermissionStatus

The result of a permission check or request.

```dart
enum PermissionStatus {
  granted,  // Permission has been granted
  denied,   // Permission has been denied
}
```

### StreamConfiguration

Configuration for starting a video stream session.

```dart
class StreamConfiguration {
  final VideoQuality videoQuality;  // Default: VideoQuality.medium
  final int frameRate;              // Default: 24 fps

  const StreamConfiguration({
    this.videoQuality = VideoQuality.medium,
    this.frameRate = 24,
  });
}
```

### VideoQuality

Video quality level for streaming.

```dart
enum VideoQuality {
  low,     // Lower resolution, less bandwidth
  medium,  // Balanced quality (default)
  high,    // Highest quality, more bandwidth
}
```

### StreamSessionState

The lifecycle state of a streaming session.

```dart
enum StreamSessionState {
  stopped,           // Session is not active
  starting,          // Session is initializing
  waitingForDevice,  // Waiting for a device to become available
  streaming,         // Actively streaming video frames
  paused,            // Stream is temporarily paused
  stopping,          // Session is shutting down
}
```

### VideoFrameInfo

Metadata about a received video frame. Emitted on the `videoFrameInfo` stream for each frame.

```dart
class VideoFrameInfo {
  final int width;         // Frame width in pixels
  final int height;        // Frame height in pixels
  final int timestampMs;   // Timestamp in milliseconds

  double get aspectRatio;  // Computed: width / height
}
```

### PhotoData

The result of a photo capture operation.

```dart
class PhotoData {
  final Uint8List bytes;   // JPEG image data
  final int width;         // Photo width in pixels
  final int height;        // Photo height in pixels
}
```

### StreamError

Errors that can occur during a streaming session.

```dart
enum StreamError {
  internalError,        // An internal SDK error occurred
  deviceNotFound,       // The target device was not found
  deviceNotConnected,   // The device is not connected
  timeout,              // The operation timed out
  videoStreamingError,  // Video streaming failed
  audioStreamingError,  // Audio streaming failed
  permissionDenied,     // Camera permission was denied
  hingesClosed,         // The glasses hinges were closed during streaming
  unknown,              // An unrecognized error occurred
}
```

### DeviceCompatibility

Compatibility status of a connected device.

```dart
enum DeviceCompatibility {
  compatible,            // Device is fully compatible
  deviceUpdateRequired,  // Device firmware needs updating
  appUpdateRequired,     // App needs updating for this device
  unknown,               // Compatibility could not be determined
}
```

### MetaWearablesException

Exception thrown by the plugin for error conditions.

```dart
class MetaWearablesException implements Exception {
  final String code;       // Error code (e.g., 'not_initialized', 'INIT_ERROR')
  final String message;    // Human-readable error message
  final dynamic details;   // Optional additional details
}
```

---

## Usage Guide

### Initialization

Always call `initialize()` before using any other API. This configures the native MWDAT SDK.

```dart
final wearables = MetaWearables.instance;

try {
  await wearables.initialize();
  print('SDK initialized successfully');
} catch (e) {
  print('Failed to initialize: $e');
}
```

Calling any method before `initialize()` will throw a `MetaWearablesException` with code `not_initialized`.

### Device Registration

Registration connects your app to the user's Ray-Ban Meta glasses via the Meta AI app.

```dart
// Listen for state changes
final subscription = wearables.registrationState.listen((state) {
  switch (state) {
    case RegistrationState.registering:
      print('Opening Meta AI app...');
    case RegistrationState.registered:
      print('Successfully connected!');
    case RegistrationState.unregistering:
      print('Disconnecting...');
    case RegistrationState.unavailable:
      print('Not registered');
  }
});

// Start registration (opens Meta AI app)
await wearables.startRegistration();

// Later: unregister
await wearables.startUnregistration();

// Don't forget to cancel the subscription
subscription.cancel();
```

**How it works:**
- **Android**: `Wearables.startRegistration(activity)` opens the Meta AI app. The user completes OAuth, and the Meta AI app redirects back via the deep link intent-filter.
- **iOS**: `Wearables.shared.startRegistration()` opens the Meta AI app. The OAuth callback returns via the URL scheme, and the plugin handles it via `handleUrl()`.

### Listening for Devices

Once registered, discover connected wearable devices:

```dart
wearables.devices.listen((devices) {
  for (final device in devices) {
    print('Device: ${device.name ?? device.id}');
  }
});
```

### Permissions

Before streaming, you need camera permission from the wearable device (this is separate from iOS/Android camera permissions):

```dart
// Check current status
final status = await wearables.checkPermissionStatus(WearablePermission.camera);

if (status != PermissionStatus.granted) {
  // Request permission (may show system UI)
  final result = await wearables.requestPermission(WearablePermission.camera);
  if (result == PermissionStatus.denied) {
    print('Camera permission denied');
    return;
  }
}

// Permission granted - proceed with streaming
```

### Video Streaming

Start a live video stream from the wearable camera:

```dart
// Start with default configuration (medium quality, 24fps)
final session = await wearables.startStreamSession();

// Or customize the configuration
final session = await wearables.startStreamSession(
  configuration: const StreamConfiguration(
    videoQuality: VideoQuality.high,
    frameRate: 30,
  ),
);

// Monitor session state
session.state.listen((state) {
  print('Stream state: ${state.name}');
});

// Monitor frame metadata
session.videoFrameInfo.listen((frame) {
  print('Frame: ${frame.width}x${frame.height}');
});

// Monitor errors
session.errors.listen((error) {
  print('Stream error: ${error.name}');
});

// Display the video using the texture ID
// In your widget tree:
Texture(textureId: session.textureId)

// Stop when done
await session.stop();
```

### Photo Capture

Capture a still photo during an active streaming session:

```dart
try {
  final photo = await session.capturePhoto();
  print('Captured ${photo.width}x${photo.height} photo (${photo.bytes.length} bytes)');

  // Display the photo
  Image.memory(photo.bytes);

  // Or save to file
  final file = File('photo.jpg');
  await file.writeAsBytes(photo.bytes);
} catch (e) {
  print('Capture failed: $e');
}
```

Photo capture only works when the session state is `StreamSessionState.streaming`.

### Using the Video Widget

The `WearableVideoView` widget provides a ready-to-use video display with automatic aspect ratio handling:

```dart
@override
Widget build(BuildContext context) {
  return WearableVideoView(
    session: session,
    fit: BoxFit.cover,
    placeholder: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Waiting for stream...'),
      ],
    ),
  );
}
```

Alternatively, use the raw `Texture` widget for full control:

```dart
StreamBuilder<VideoFrameInfo>(
  stream: session.videoFrameInfo,
  builder: (context, snapshot) {
    final info = snapshot.data;
    return AspectRatio(
      aspectRatio: info?.aspectRatio ?? 16 / 9,
      child: Texture(textureId: session.textureId),
    );
  },
)
```

### Deep Link Handling (iOS)

On iOS, the OAuth callback from the Meta AI app returns via a URL scheme. The plugin handles this automatically through the `FlutterApplicationLifeCycleDelegate`. If you need to handle it manually:

```dart
// In response to a deep link
final handled = await wearables.handleUrl('your-app-scheme://callback?token=...');
if (handled) {
  print('OAuth callback processed');
}
```

### Testing with MockDeviceKit

MockDeviceKit lets you develop and test without physical Ray-Ban Meta glasses:

```dart
final mockKit = wearables.mockDeviceKit;
if (mockKit == null) return; // Not available in release builds (iOS)

// 1. Create a mock device
final device = await mockKit.pairRaybanMeta();

// 2. Simulate device states
await device.powerOn();
await device.don();       // Put on the glasses
await device.unfold();    // Open the hinges

// 3. Set mock camera content
await device.setCameraFeed('/path/to/video.mp4');
await device.setCapturedImage('/path/to/photo.jpg');

// 4. Now start a stream session - it will use the mock camera feed
final session = await wearables.startStreamSession();

// 5. Capture a photo - returns the mock captured image
final photo = await session.capturePhoto();

// 6. Clean up
await session.stop();
await device.powerOff();
await mockKit.unpairDevice(device);
```

**MockDevice state methods:**

| Method | Effect |
|--------|--------|
| `powerOn()` | Device becomes discoverable |
| `powerOff()` | Device goes offline |
| `don()` | Simulates wearing the glasses |
| `doff()` | Simulates removing the glasses |
| `unfold()` | Simulates opening the hinges |
| `fold()` | Simulates closing the hinges (triggers `hingesClosed` error during stream) |

### Cleanup

Always dispose of the plugin when you're done to release native resources:

```dart
@override
void dispose() {
  registrationSubscription?.cancel();
  devicesSubscription?.cancel();
  wearables.dispose();
  super.dispose();
}
```

---

## Architecture

### Plugin Structure

```
flutter_meta_wearables/
  lib/
    flutter_meta_wearables.dart              # Barrel export
    src/
      meta_wearables.dart                    # MetaWearables singleton API
      meta_wearables_platform.dart           # Abstract platform interface
      meta_wearables_method_channel.dart     # MethodChannel/EventChannel impl
      stream_session.dart                    # MetaWearablesStreamSession
      mock_device_kit.dart                   # MockDeviceKit wrapper
      mock_device.dart                       # MockDevice wrapper
      models/
        models.dart                          # Barrel export
        device_identifier.dart               # DeviceIdentifier
        registration_state.dart              # RegistrationState enum
        permission.dart                      # WearablePermission + PermissionStatus
        stream_configuration.dart            # StreamConfiguration + VideoQuality
        stream_session_state.dart            # StreamSessionState enum
        video_frame.dart                     # VideoFrameInfo
        photo_data.dart                      # PhotoData
        device_compatibility.dart            # DeviceCompatibility enum
        stream_error.dart                    # StreamError + MetaWearablesException
      widgets/
        wearable_video_view.dart             # Texture-based video widget

  android/src/main/kotlin/com/meta/wearable/flutter/
    FlutterMetaWearablesPlugin.kt            # FlutterPlugin + ActivityAware
    WearablesMethodCallHandler.kt            # MethodCall dispatch
    WearablesStreamHandlers.kt               # EventChannel handlers
    StreamSessionManager.kt                  # Stream lifecycle + frame collection
    VideoFrameRenderer.kt                    # TextureRegistry surface rendering
    MockDeviceKitHandler.kt                  # Mock device methods
    Converters.kt                            # Enum/data conversions

  ios/Classes/
    FlutterMetaWearablesPlugin.swift         # Plugin registration + deep link delegate
    WearablesMethodCallHandler.swift         # Method dispatch
    WearablesStreamHandlers.swift            # EventChannel handlers
    StreamSessionManager.swift               # Stream lifecycle + publisher listeners
    VideoFrameRenderer.swift                 # FlutterTexture + CVPixelBuffer
    MockDeviceKitHandler.swift               # Mock device methods
    Converters.swift                         # Enum/data conversions
```

This uses the **simple plugin pattern** (not federated). This is appropriate for a single-team SDK wrapper. Migration to federated is straightforward later if needed.

### Video Streaming Strategy

The plugin uses Flutter's **Texture API** for zero-copy video rendering. This avoids serializing raw frame data (~33 MB/s at 24fps 720p) across the platform channel.

**How it works:**

1. The native side registers a texture with Flutter's texture registry
2. Each video frame is rendered directly to the native surface/texture (zero-copy)
3. Only lightweight metadata (width, height, timestamp) crosses the platform channel via EventChannel
4. The Dart side uses `Texture(textureId: id)` to display the native texture

**Android pipeline:**
```
VideoFrame (I420 ByteBuffer)
  -> convertI420toNV21()
  -> YuvImage -> compressToJpeg()
  -> BitmapFactory.decodeByteArray()
  -> Canvas.drawBitmap() on TextureRegistry Surface
```

**iOS pipeline:**
```
VideoFrame
  -> makeUIImage() -> CGImage
  -> CVPixelBufferCreate (BGRA)
  -> CGContext.draw()
  -> FlutterTexture.copyPixelBuffer()
  -> registry.textureFrameAvailable()
```

### Platform Channel Definitions

**Method Channel:** `com.meta.wearable.flutter/methods`

| Method | Arguments | Returns |
|--------|-----------|---------|
| `initialize` | - | `void` |
| `startRegistration` | - | `void` |
| `startUnregistration` | - | `void` |
| `checkPermissionStatus` | `{permission: String}` | `String` (enum name) |
| `requestPermission` | `{permission: String}` | `String` (enum name) |
| `handleUrl` | `{url: String}` | `bool` |
| `startStreamSession` | `{videoQuality: String, frameRate: int}` | `{sessionId: String, textureId: int}` |
| `stopStreamSession` | `{sessionId: String}` | `void` |
| `capturePhoto` | `{sessionId: String}` | `{bytes: Uint8List, width: int, height: int}` |
| `dispose` | - | `void` |
| `mock_pairRaybanMeta` | - | `{deviceId: String}` |
| `mock_unpairDevice` | `{deviceId: String}` | `void` |
| `mock_deviceAction` | `{deviceId: String, action: String}` | `void` |
| `mock_setCameraFeed` | `{deviceId: String, filePath: String}` | `void` |
| `mock_setCapturedImage` | `{deviceId: String, filePath: String}` | `void` |

**Event Channels:**

| Channel | Data Format |
|---------|-------------|
| `com.meta.wearable.flutter/registrationState` | `String` (enum name) |
| `com.meta.wearable.flutter/devices` | `List<Map<String, String?>>` |
| `com.meta.wearable.flutter/streamState` | `String` (enum name) |
| `com.meta.wearable.flutter/videoFrameInfo` | `Map {width: int, height: int, timestampMs: int}` |
| `com.meta.wearable.flutter/streamErrors` | `Map {code: String, message: String}` |

---

## Example App

The plugin includes a complete example app in the `example/` directory demonstrating:

- SDK initialization
- Mock device pairing (for development)
- Device registration via Meta AI
- Live video streaming with `WearableVideoView`
- Photo capture and display

Run the example:

```bash
cd flutter_meta_wearables/example
flutter run
```

The example app has two screens:

1. **Home** - Initialize SDK, connect/disconnect glasses, pair mock devices, navigate to streaming
2. **Streaming** - Live video display with capture button, error display, and stop controls

---

## Testing

### Dart Unit Tests

The plugin includes 25 unit tests covering the Dart API, model serialization, and platform interface:

```bash
cd flutter_meta_wearables
flutter test
```

Tests use a `MockMetaWearablesPlatform` that implements the platform interface with in-memory behavior, allowing full API testing without native code.

**Test coverage includes:**
- Platform interface default instance verification
- `initialize()`, `startRegistration()`, `startUnregistration()` delegation
- `registrationState` and `devices` stream emission
- Permission check and request
- URL handling
- Stream session creation with texture ID
- Photo capture response
- MockDeviceKit pairing
- `dispose()` cleanup
- All model `fromString()` / `fromMap()` / `toMap()` methods
- `DeviceIdentifier` equality semantics
- `VideoFrameInfo` aspect ratio calculation
- `StreamConfiguration` default values
- `MetaWearablesException` formatting

### Static Analysis

```bash
flutter analyze
```

The plugin passes with zero issues.

### Integration Testing

Integration tests are in `example/integration_test/`. They test SDK initialization on a real device or simulator:

```bash
cd flutter_meta_wearables/example
flutter test integration_test/
```

### Device Testing

For testing with physical Ray-Ban Meta glasses:

1. Register at the [Meta Wearables Developer Center](https://developers.facebook.com/)
2. Configure your `META_APP_ID` and `CLIENT_TOKEN` in the platform configs
3. Run the example app on a physical device
4. Tap "Connect Glasses" to initiate the Meta AI OAuth flow
5. Complete pairing in the Meta AI app
6. Return to the example app and tap "Start Streaming"

---

## Troubleshooting

### `MetaWearablesException: not_initialized`
Call `MetaWearables.instance.initialize()` before using any other API.

### Android build fails with "Could not resolve com.meta.wearable:mwdat-core"
Ensure your `GITHUB_TOKEN` is set and has `read:packages` scope. Verify the Maven repository is configured in `settings.gradle.kts`.

### iOS build fails with missing MWDATCore module
Add the MWDAT SDK via Swift Package Manager in Xcode. The plugin's podspec does not bundle the SDK - it must be added to the host app's Xcode project.

### Stream shows black frames
Ensure the device has camera permission (`checkPermissionStatus` / `requestPermission`). When using MockDeviceKit, call `setCameraFeed()` with a valid video file path before starting a stream.

### Registration flow doesn't return to the app
Verify your deep link URL scheme is correctly configured in both `AndroidManifest.xml` (intent-filter) and `Info.plist` (CFBundleURLSchemes / MWDAT AppLinkURLScheme).

### Photo capture returns error
Photo capture only works when the session state is `streaming`. Listen to `session.state` and only call `capturePhoto()` when the state is `StreamSessionState.streaming`.

### `hingesClosed` error during streaming
The user has folded the glasses hinges. The stream session will emit this error and may transition to `stopped`. Prompt the user to open the hinges and restart the stream.

### Plugin not found on Android after changing package name
If you changed the Android package in `pubspec.yaml`, ensure the Kotlin source files are in the matching directory path (`android/src/main/kotlin/com/meta/wearable/flutter/`).

---

## License

This plugin is provided under the terms of the license in the LICENSE file. The Meta Wearables DAT SDK has its own license terms - see the [Meta Wearables Developer Center](https://developers.facebook.com/) for details.
