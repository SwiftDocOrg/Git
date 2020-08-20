import Clibgit2

/// A libgit error.
public struct Error: Swift.Error {

    /**
     The error code.

     Error codes correspond to `git_error_code` constants, like `GIT_ENOTFOUND`.
     */
    public let code: Int // TODO: import raw values declared by libgit2


    /// The error message, if any.
    public let message: String?

    private static var lastErrorMessage: String? {
        guard let error = giterr_last() else { return nil }
        return String(cString: error.pointee.message)
    }

    init<Code: FixedWidthInteger>(code: Code, message: String? = Error.lastErrorMessage) {
        self.code = Int(code)
        self.message = message
    }
}

// MARK: -

func attempt(throwing function: () -> Int32) throws {
    _ = initializer // FIXME
    let result = function()
    guard result == 0 else {
        throw Error(code: result)
    }
}

func result(of function: () -> Int32) -> Result<Void, Swift.Error> {
    do {
        try attempt(throwing: function)
        return .success(())
    } catch {
        return .failure(error)
    }
}
