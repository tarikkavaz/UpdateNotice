// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UpdateNotice",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UpdateNotice", targets: ["UpdateNotice"]),
        .library(name: "UpdateNoticeUI", targets: ["UpdateNoticeUI"]),
    ],
    targets: [
        .target(name: "UpdateNotice"),
        .target(name: "UpdateNoticeUI", dependencies: ["UpdateNotice"]),
        .testTarget(name: "UpdateNoticeTests", dependencies: ["UpdateNotice"]),
        .testTarget(name: "UpdateNoticeUITests", dependencies: ["UpdateNoticeUI", "UpdateNotice"]),
    ]
)
