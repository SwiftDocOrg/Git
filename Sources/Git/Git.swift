import Clibgit2

let initializer: () = {
    git_libgit2_init()
}()


#if os(Windows)
let pathListSeparator = ";"
#else
let pathListSeparator = ":"
#endif
