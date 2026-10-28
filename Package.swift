// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SSOKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "SSOKit", targets: ["SSOKit"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc",
            from: "1.9.0"
        )
    ],
    targets: [
        .target(
            name: "SSOKit",
            dependencies: [
                .product(name: "MSAL", package: "microsoft-authentication-library-for-objc")
            ]
        ),
        .testTarget(
            name: "SSOKitTests",
            dependencies: ["SSOKit"]
        )
    ]
)
