import Clibgit2
import Foundation

extension Repository {
    /// The repository `HEAD` reference.
    public enum Head: Equatable {
        case attached(Branch)
        case detached(Commit)

        public var attached: Bool {
            switch self {
            case .attached:
                return true
            case .detached:
                return false
            }
        }

        public var detached: Bool {
            return !attached
        }

        public var branch: Branch? {
            switch self {
            case .attached(let branch):
                return branch
            case .detached:
                return nil
            }
        }

        public var commit: Commit? {
            switch self {
            case .attached(let branch):
                return branch.commit
            case .detached(let commit):
                return commit
            }
        }
    }
}
