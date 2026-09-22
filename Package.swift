// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Shade", platforms: [.macOS(.v13)], products: [.executable(name: "Shade", targets: ["Shade"])], targets: [.executableTarget(name: "Shade")])
