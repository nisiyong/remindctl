// swift-tools-version: 6.0
import PackageDescription

let commandLineToolsFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

let package = Package(
  name: "remindctl",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "RemindCore", targets: ["RemindCore"]),
    .executable(name: "remindctl", targets: ["remindctl"]),
  ],
  dependencies: [
    .package(url: "https://github.com/steipete/Commander.git", from: "0.2.0"),
  ],
  targets: [
    .target(
      name: "RemindCore",
      dependencies: [],
      linkerSettings: [
        .linkedFramework("EventKit"),
      ]
    ),
    .executableTarget(
      name: "remindctl",
      dependencies: [
        "RemindCore",
        .product(name: "Commander", package: "Commander"),
      ],
      exclude: [
        "Resources/Info.plist",
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate",
          "-Xlinker", "__TEXT",
          "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/remindctl/Resources/Info.plist",
        ]),
      ]
    ),
    .testTarget(
      name: "RemindCoreTests",
      dependencies: [
        "RemindCore",
      ],
      swiftSettings: [
        .unsafeFlags([
          "-F", commandLineToolsFrameworks,
          "-Xfrontend", "-disable-cross-import-overlay-search",
        ]),
      ],
      linkerSettings: [
        .unsafeFlags([
          "-F", commandLineToolsFrameworks,
          "-Xlinker", "-rpath",
          "-Xlinker", commandLineToolsFrameworks,
        ]),
      ]
    ),
    .testTarget(
      name: "remindctlTests",
      dependencies: [
        "remindctl",
        "RemindCore",
      ],
      swiftSettings: [
        .unsafeFlags([
          "-F", commandLineToolsFrameworks,
          "-Xfrontend", "-disable-cross-import-overlay-search",
        ]),
      ],
      linkerSettings: [
        .unsafeFlags([
          "-F", commandLineToolsFrameworks,
          "-Xlinker", "-rpath",
          "-Xlinker", commandLineToolsFrameworks,
        ]),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
