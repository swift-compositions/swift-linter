public import SPM_Standard
public import URI_Standard
@_exported public import URI_Standard_Library_Integration
@_exported public import Version

extension Package.Dependency {

    @inlinable
    public static func package(
        // swift-linter:disable:next raw concept
        // REASON: a Lint manifest's .package(path:) text, written as a literal, usually relative, and stored as Package.Dependency.Source.path, whose payload SPM_Standard holds as text; Path::Path has no literal without ISO_9945_Kernel_File in every Lint.swift.
        path: Swift.String,
        products: [Product.Name]
    ) -> Package.Dependency {
        let basename: Swift.String = path.split(separator: "/").last.map(Swift.String.init) ?? path
        return Package.Dependency(
            source: .path(path),
            name: Package.Name(_unchecked: basename),
            products: products
        )
    }

    @inlinable
    public static func package(
        url: URI,
        _ range: Swift.Range<Version.Semantic>,
        products: [Product.Name]
    ) -> Package.Dependency {
        var name: Swift.String = url.value.split(separator: "/").last.map(Swift.String.init) ?? url.value
        if name.hasSuffix(".git") {
            name.removeLast(4)
        }
        let requirement: Package.Requirement = .range(Version.Range(range))
        return Package.Dependency(
            source: .url(url, requirement),
            name: Package.Name(_unchecked: name),
            products: products
        )
    }

    @inlinable
    public static func package(
        url: URI,
        from version: Version.Semantic,
        products: [Product.Name]
    ) -> Package.Dependency {
        var name: Swift.String = url.value.split(separator: "/").last.map(Swift.String.init) ?? url.value
        if name.hasSuffix(".git") {
            name.removeLast(4)
        }
        return Package.Dependency(
            source: .url(url, .from(version)),
            name: Package.Name(_unchecked: name),
            products: products
        )
    }

    @inlinable
    public static func package(
        url: URI,
        branch: Swift.String,
        products: [Product.Name]
    ) -> Package.Dependency {
        var name: Swift.String = url.value.split(separator: "/").last.map(Swift.String.init) ?? url.value
        if name.hasSuffix(".git") {
            name.removeLast(4)
        }
        return Package.Dependency(
            source: .url(url, .branch(branch)),
            name: Package.Name(_unchecked: name),
            products: products
        )
    }
}
