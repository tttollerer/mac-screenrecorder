// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacScreenRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacScreenRecorder", targets: ["MacScreenRecorder"])
    ],
    targets: [
        .executableTarget(
            name: "MacScreenRecorder",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
