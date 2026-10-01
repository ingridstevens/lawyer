// swift-tools-version: 6.2
import PackageDescription

// The macOS app. Built into a .app bundle by scripts/build-app.sh.
let package = Package(
    name: "NotALawyerApp",
    platforms: [.macOS(.v26)],
    dependencies: [.package(path: "../Packages/NotALawyerCore")],
    targets: [
        .executableTarget(
            name: "NotALawyer",
            dependencies: [
                .product(name: "NotALawyerCore", package: "NotALawyerCore"),
                .product(name: "NotALawyerApple", package: "NotALawyerCore"),
            ]
        ),
    ]
)
