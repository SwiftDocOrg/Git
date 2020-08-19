import Clibgit2

public enum Credentials {
    case `default`
    case plaintext(username: String, password: String)
    case sshAgent(username: String)
    case sshMemory(username: String, publicKey: String, privateKey: String, passphrase: String)
}
