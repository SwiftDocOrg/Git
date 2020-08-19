import Clibgit2

public enum Message {
    public func prettify(_ message: String, stripComments: Bool = false, commentDelimiter: Character = "#") throws -> String {
        var buffer = git_buf()
        defer { git_buf_free(&buffer) }

        try wrap { git_message_prettify(&buffer, message, stripComments ? 1 : 0, numericCast(commentDelimiter.asciiValue ?? 35)) }

        return String(cString: buffer.ptr)
    }
}
