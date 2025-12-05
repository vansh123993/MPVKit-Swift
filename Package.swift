// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MPVKit",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MPVKit",
            targets: ["MPVKit"]),
    ],
    targets: [
        .binaryTarget(
            name: "MPV",
            path: "MPV.xcframework"
        ),
        .binaryTarget(
            name: "MoltenVK",
            path: "MoltenVK.xcframework"
        ),
        .target(
            name: "MPVKit",
            dependencies: ["MPV", "MoltenVK"],
            linkerSettings: [
                .linkedLibrary("iconv"),
                .linkedLibrary("z"),
                .linkedLibrary("xml2"),
                .linkedLibrary("resolv"),
                .linkedLibrary("c++"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("AppKit"),
                .linkedFramework("OpenGL"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)
