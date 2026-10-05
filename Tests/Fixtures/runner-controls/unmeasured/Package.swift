let package = Package(
    name: "Fixture",
    targets: [.target(name: "Consumer", dependencies: dependencies())]
)
