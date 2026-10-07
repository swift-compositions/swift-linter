import Testing

@testable import Linter

extension Lint.Run.Command {
  @Suite
  struct Test {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Run.Command.Test.Unit {
  @Test
  func `inventory alone is the inventory command`() throws {
    #expect(try Lint.Run.Command.parse(["--inventory"]) == .inventory)
  }

  @Test
  func `profile with a profile and a path is the profile command`() throws {
    #expect(
      try Lint.Run.Command.parse(["--profile", "institute.json", "/tmp/empty"])
        == .profile(path: "institute.json", paths: ["/tmp/empty"])
    )
  }

  @Test
  func `plain paths are linted`() throws {
    #expect(
      try Lint.Run.Command.parse(["Sources", "Tests/Fixtures"])
        == .lint(paths: ["Sources", "Tests/Fixtures"])
    )
  }

  @Test
  func `profile-check is rejected as an unknown option before any linting`() {
    #expect(throws: Lint.Run.Command.Error.unknownOption("--profile-check")) {
      try Lint.Run.Command.parse(["--profile-check", "institute.json"])
    }
  }

  @Test
  func `an unknown option is rejected`() {
    #expect(throws: Lint.Run.Command.Error.unknownOption("--bogus")) {
      try Lint.Run.Command.parse(["--bogus"])
    }
  }
}

extension Lint.Run.Command.Test.`Edge Case` {
  @Test
  func `no arguments lint the current directory`() throws {
    #expect(try Lint.Run.Command.parse([]) == .lint(paths: []))
  }

  @Test
  func `profile without a path is a usage error`() {
    #expect(
      throws: Lint.Run.Command.Error.usage(
        "profile invocation requires --profile <profile.json> <path> ..."
      )
    ) {
      try Lint.Run.Command.parse(["--profile", "institute.json"])
    }
  }

  @Test
  func `inventory with further arguments is a usage error`() {
    #expect(throws: Lint.Run.Command.Error.usage("--inventory takes no further arguments")) {
      try Lint.Run.Command.parse(["--inventory", "Sources"])
    }
  }

  @Test
  func `a path after a leading path is never read as an option`() throws {
    #expect(
      try Lint.Run.Command.parse(["Sources", "--bogus"]) == .lint(paths: ["Sources", "--bogus"])
    )
  }
}
