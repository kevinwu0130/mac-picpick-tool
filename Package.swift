// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPicPickTool",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacPicPickTool",
            path: "Sources/MacPicPickTool",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)
