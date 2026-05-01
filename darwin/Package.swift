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
            checksum: "510698c65c0851940e1b8872e7b713a0fb0f258b6266b0c4aa057e0d0523d937"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
