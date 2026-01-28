// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KoardSDK",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KoardSDK",
            targets: ["KoardSDK"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "KoardSDK",
            path: "./KoardSDK.xcframework"
        )
    ]
)
