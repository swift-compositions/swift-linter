public import File_System
public import Lint

extension Lint.Filter.Prefix {

    @inlinable
    public init(_ filePath: File.Path) {
        #if os(Windows)
            self = Self(filePath.description.replacing("\\", with: "/"))
        #else
            self = Self(filePath.description)
        #endif
    }
}
