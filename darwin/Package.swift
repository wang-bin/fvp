// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "fvp",
    platforms: [
        .iOS("12.0"),
        .macOS("10.13"),
    ],
    products: [
        .library(name: "fvp", targets: ["fvp"]),
    ],
    targets: [
        .target(
            name: "fvp",
            dependencies: [.target(name: "mdk")],
            path: ".",
            sources: [
                "Classes/FvpPlugin.mm",
                "Classes/callbacks.cpp",
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "Classes",
            cSettings: [
                .headerSearchPath("Classes"),
            ],
            cxxSettings: [
                .unsafeFlags(["-Wno-documentation"]),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
            ]
        ),
        .binaryTarget(
            name: "mdk",
            url: "https://github.com/wang-bin/mdk-sdk/releases/download/v0.35.1/mdk-sdk-apple.zip",
            checksum: "eb1fc21c5f71ab1510eebf6ff027cbab2d50ae5833e17236056614b23d8f2f44"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
