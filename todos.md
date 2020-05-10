# Todos

TODO: Single dotmodule file for dependencies / clashes / etc, ini or toml

TODO: Multirequirements using `:` 0.root.pacman:cargo.sh

TODO: use make on update and remove too use Make targets, check if exits

TODO: deprecation alternatives prompt, check nvm and fnm

TODO: Experiment with `sudo -l` to find out you have sudo access or not
TODO: If not, automatically turn on `skip-root` and print some message

TODO: Clash support. Use .clash file, if two modules clash, ask which to use
TODO: If a clashing module is already installed, abort, ask if interactive,
TODO: remove other if forced. Ignore deprecated modules

TODO: clash feature support tags, see if something from that tag is installed

TODO: track dangling dependencies. When installing leave a file in the module
TODO: that will store a snapshot of the dependencies. During uninstall check
TODO: If there is a dependency somewhere that is not directly installed.
TODO: (Or maybe dont and leave this to dot2)

TODO: If the module contains a git submodule. Check it out / update it

TODO: Experiment with paralell execution (sort dependencies into a tree)
TODO: Right now every dependency is sorted into a column and executed
TODO: sequentially. The new executor would treat everything in one column
TODO: and one indentation as modules that can be executed paralelly
TODO: then pass everything below as a dependency list to it with one level
TODO: of indentation removed
TODO: make a test modules directory with modules with logs and sleeps
TODO: Also a buffer output is needed to display this
TODO: It should keep a buffer as high as many modules are currently being
TODO: installed and then do the logging above it like normal
TODO: Or have an indented section below each entry with a preview log
TODO: or both
TODO: investigate if feasible
TODO: add flags to disable or enable paralell work
TODO: add a .lock file with PID into each module just in case and remove after

TODO: forced clash on every input module. This is useful when you want to
TODO: have a menu to install something in a category. combine with
TODO: no-uninstall flags
