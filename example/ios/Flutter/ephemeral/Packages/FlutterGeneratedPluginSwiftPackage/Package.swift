// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "integration_test", path: "../.packages/integration_test"),
        .package(name: "webview_flutter_wkwebview", path: "../.packages/webview_flutter_wkwebview-3.25.1"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.6"),
        .package(name: "audio_session", path: "../.packages/audio_session-0.2.3"),
        .package(name: "photo_manager", path: "../.packages/photo_manager-3.9.0"),
        .package(name: "video_player_avfoundation", path: "../.packages/video_player_avfoundation-2.9.7"),
        .package(name: "sensors_plus", path: "../.packages/sensors_plus-7.0.0"),
        .package(name: "camera_avfoundation", path: "../.packages/camera_avfoundation-0.10.1"),
        .package(name: "wakelock_plus", path: "../.packages/wakelock_plus-1.5.2"),
        .package(name: "package_info_plus", path: "../.packages/package_info_plus-9.0.1"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.4.1"),
        .package(name: "share_plus", path: "../.packages/share_plus-12.0.2"),
        .package(name: "record_ios", path: "../.packages/record_ios-1.2.1"),
        .package(name: "just_audio", path: "../.packages/just_audio-0.10.5"),
        .package(name: "flutter_local_notifications", path: "../.packages/flutter_local_notifications-19.5.0"),
        .package(name: "file_picker", path: "../.packages/file_picker-10.3.10"),
        .package(name: "device_info_plus", path: "../.packages/device_info_plus-12.3.0"),
        .package(name: "sqflite_darwin", path: "../.packages/sqflite_darwin-2.4.2"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "integration-test", package: "integration_test"),
                .product(name: "webview-flutter-wkwebview", package: "webview_flutter_wkwebview"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "audio-session", package: "audio_session"),
                .product(name: "photo-manager", package: "photo_manager"),
                .product(name: "video-player-avfoundation", package: "video_player_avfoundation"),
                .product(name: "sensors-plus", package: "sensors_plus"),
                .product(name: "camera-avfoundation", package: "camera_avfoundation"),
                .product(name: "wakelock-plus", package: "wakelock_plus"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "record-ios", package: "record_ios"),
                .product(name: "just-audio", package: "just_audio"),
                .product(name: "flutter-local-notifications", package: "flutter_local_notifications"),
                .product(name: "file-picker", package: "file_picker"),
                .product(name: "device-info-plus", package: "device_info_plus"),
                .product(name: "sqflite-darwin", package: "sqflite_darwin"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
