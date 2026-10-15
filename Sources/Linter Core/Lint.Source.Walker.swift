public import File_System
public import Glob
import Glob
public import Lint
internal import SwiftParser
internal import SwiftSyntax

extension Lint.Source {

  public enum Walker {}
}

extension Lint.Source.Walker {

  public static let included: [Glob.Pattern] = ["**/*.swift"]

  public static let excluded: [Glob.Pattern] = [
    "**/.build/**",
    "**/.swiftpm/**",
    "**/.benchmarks/**",
    "**/DerivedData/**",
    "**/Carthage/**",
    "**/Pods/**",
    "**/*.docc/**",
  ]

  public static func paths(under root: File.Path) -> [Lint.Source.Path] {

    if root.components.last?.extension?.string == "swift" {
      return [Lint.Source.Path("")]
    }

    let directory = File.Directory(root)
    let files: [File]
    do throws(Glob.Error) {
      files = try directory.glob.files(
        include: included,
        excluding: excluded
      )
    } catch {
      return []
    }

    var nestedPackageRoots: [File.Path] = []
    for file in files {
      guard file.path.components.last?.string == "Package.swift",
        let parent = file.path.parent,
        parent != root,
        let source = try? Lint.File.Single.contents(of: file.path),
        Self.isPackageManifest(source)
      else { continue }
      nestedPackageRoots.append(parent)
    }

    var results: [Lint.Source.Path] = []
    results.reserveCapacity(files.count)
    for file in files {
      if nestedPackageRoots.contains(where: { file.path.hasPrefix($0) }) {
        continue
      }
      guard let relative = file.path.relative(to: root) else {
        continue
      }
      results.append(Lint.Source.Path(relative))
    }
    return results.sorted(by: { $0.underlying < $1.underlying })
  }

  internal static func isPackageManifest(_ source: Swift.String) -> Swift.Bool {
    Self.isPackageManifest(in: Parser.parse(source: source).statements)
  }

  fileprivate static func isPackageManifest(
    in statements: CodeBlockItemListSyntax
  ) -> Swift.Bool {
    statements.contains { statement in
      if let conditional = statement.item.as(IfConfigDeclSyntax.self) {
        return conditional.clauses.contains { clause in
          guard case .statements(let statements)? = clause.elements else { return false }
          return Self.isPackageManifest(in: statements)
        }
      }
      if let declaration = statement.item.as(ImportDeclSyntax.self) {
        return declaration.path.first?.name.text == "PackageDescription"
      }
      guard let declaration = statement.item.as(VariableDeclSyntax.self) else { return false }
      return declaration.bindings.contains { binding in
        guard binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "package",
          let call = binding.initializer?.value.as(FunctionCallExprSyntax.self)
        else { return false }
        return call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package"
      }
    }
  }
}
