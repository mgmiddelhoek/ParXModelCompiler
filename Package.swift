// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParXModelCompiler",
    products: [
        .library(
            name: "ParXModelCompiler",
            targets: ["ParXModelCompiler"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ParXModelCompiler",
            dependencies: []),
    ]
)
