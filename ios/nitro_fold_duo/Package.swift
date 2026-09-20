// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "nitro_fold_duo",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "nitro-fold-duo", targets: ["nitro_fold_duo"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        // C/C++ bridge — SPM requires Swift and C++ in separate targets.
        // nitro headers (nitro.h, dart_api_dl.h …) are copied into include/
        // by `nitrogen link`, so no extra header search path is needed.
        .target(
            name: "NitroFoldDuoCpp",
            path: "Sources/NitroFoldDuoCpp",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-std=c++17"])
            ]
        ),
        // Swift implementation + generated bridge.
        .target(
            name: "nitro_fold_duo",
            dependencies: [
                "NitroFoldDuoCpp",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/NitroFoldDuo"
        ),
    ]
)
