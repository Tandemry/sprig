// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SprigNative",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "SprigCore", targets: ["SprigCore"]),
    .executable(name: "Sprig", targets: ["SprigApp"]),
  ],
  targets: [
    .target(name: "SprigCore", resources: [.process("Resources")]),
    .executableTarget(
      name: "SprigApp", dependencies: ["SprigCore"],
      resources: [
        .copy("Resources/Assets"), .copy("Resources/Fonts"), .copy("Resources/Markdown"),
        .copy("Resources/Assets.xcassets"),
      ]),
    .testTarget(name: "SprigCoreTests", dependencies: ["SprigCore"]),
    .testTarget(name: "SprigAppTests", dependencies: ["SprigApp"]),
  ]
)
