public import File_System

extension Lint.Driver {

  public enum Manifest {}
}

extension Lint.Driver.Manifest {

  public static func path(at consumerPackageRoot: File.Path) -> File.Path? {
    let candidate: File.Path = consumerPackageRoot / "Lint.swift"

    return File.System.Stat.isFile(at: candidate) ? candidate : nil
  }

  internal static func checkout(_ name: File.Path.Component, beside linter: File.Path) -> File.Path {
    let sibling: File.Path = (linter.parent ?? linter) / name
    let built: File.Path = linter / ".build" / "checkouts" / name
    return !File.System.Stat.isDirectory(at: sibling) && File.System.Stat.isDirectory(at: built)
      ? built
      : sibling
  }
}
