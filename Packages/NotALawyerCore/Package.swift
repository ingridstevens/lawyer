// swift-tools-version: 6.2
import PackageDescription

// NotALawyerCore stays free of Apple-only frameworks so it can later back a
// local web app on Linux and Windows (spec §12). Anything that needs
// FoundationModels lives in NotALawyerApple.
let package = Package(
    name: "NotALawyerCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "NotALawyerCore", targets: ["NotALawyerCore"]),
        .library(name: "NotALawyerApple", targets: ["NotALawyerApple"]),
        .executable(name: "nal-eval", targets: ["nal-eval"]),
    ],
    targets: [
        .systemLibrary(name: "CSQLite", providers: [.apt(["libsqlite3-dev"])]),
        .target(name: "NotALawyerCore", dependencies: ["CSQLite"]),
        .target(name: "NotALawyerApple", dependencies: ["NotALawyerCore"]),
        .executableTarget(name: "nal-eval", dependencies: ["NotALawyerCore", "NotALawyerApple"]),
        .testTarget(name: "NotALawyerCoreTests", dependencies: ["NotALawyerCore"]),
    ]
)
