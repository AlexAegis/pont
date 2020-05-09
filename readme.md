# [dot](./dot.sh)

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/637b2b8de50b4a9f8ed5ebd4b57a1dfc)](https://app.codacy.com/manual/AlexAegis/dot?utm_source=github.com&utm_medium=referral&utm_content=AlexAegis/dot&utm_campaign=Badge_Grade_Dashboard)
[![Test](https://github.com/AlexAegis/dot/workflows/Test/badge.svg)](https://github.com/AlexAegis/dot/actions?query=workflow%3ATest) [![Lint](https://github.com/AlexAegis/dot/workflows/Lint/badge.svg)](https://github.com/AlexAegis/dot/actions?query=workflow%3ALint)

> Check my [dotfiles](https://github.com/alexaegis/dotfiles) as a live example

## What is dot

It's a single shell script designed to install programs and personal configs
in bulk in a highly configurable and environmentally aware way using as simple
techniques as possible.

The programs and configurations are stored in `dotmodules` which is just a
directory with scripts and folders named in a conventional manner. The names
of these files are the configuration itself. If I'd use a configuration file
it would require mentioning the directories you want to interact with. I've
cut out the config and store every metadata in filenames. More on this in the
[dotmodules](#dotmodules) section.

For example, using this script and an extensive set of dotmodules, on a fresh
arch install after downloading my dotfiles repository I can just issue this
command:

```sh
dot +arch
```

And then it will install every single thing I specified there without
assistance. In order.

But that could be done by having a single set of applications in an install
script, and all my config in a repository, right?

Yes, but what if you use multiple setups at once? Or you'd like to configure
just only a few things on a remote server? Why would you add your X config to
WSL? What if you distro hop a lot because you're experimenting?

But even if you use it for a single system it does have it's advantages.
Separating everything into it's little bundle helps keeping track of things.
If you wan't to teak some configurations you only have to go to one place, and
you get all related files in one module. You can see what other modules you
made this one depend on.

Configuration is just one part. But oftentime things require a little setup.
Downloading a repository, making it, installing it. Installing and enabling
services. These things can also be in an install script. You don't have to
remember things. And when you don't have to remember things, you can start
focusing on creating things.

A modular design allows this.

> It's my first shell script project so please leave issues, if you have any

![xkcd - Automation](https://imgs.xkcd.com/comics/automation.png)

## Prerequisites

A mostly [POSIX](https://en.wikipedia.org/wiki/POSIX) shell on
`/bin/sh` to run `dot` itself. It was developed on `dash` and it does not
utilize local variables.

A key component of `dot` is `stow` which handles the symlinks between the
modules and the target, but it's not needed to run `dot` itself and execute
modules that do not require linking. Meaning on a fresh install `dot` can set
this dependency up for you if you have a module that deals with this and do
not utilize linking.

## Installation

This repository can be used to download and install dot. It can also act
as a dotmodule itself. You can inclide this repository as a submodule to your
dotfiles repo.

```sh
git clone --recurse-submodules -j8 \
  http://www.github.com/AlexAegis/dotfiles ~/.config/dotfiles
```

### Using dot itself

If you have this repository as a submodule among your modules, you can install
it with itself. The only script `dot` will detect is
[`0.sudo.sh`](./0.sudo.sh) which does the linking as mentioned.

```sh
~/.dotfiles/modules/dot/dot.sh dot
```

### As a zsh plugin

This repository also contains `zsh` autocompletions

If you're using [Antibody](https://github.com/getantibody/antibody) then add
this entry to your plugin file to get `dot` autocompletions:

```sh
alexaegis/dot
```

> The zsh plugin does not put `dot` to the path as using both solution would
> cause confusion

Autocompletions will list all presets, tags and modules when triggered. When
typing a `-`, triggering the autocompletion will list all flags.

## Usage

Whether you chose to put it on your path or not, using it is the same.

### Configuration

It does not require any configuration, but most things can be configured
through a `dotrc` file which is read from every common configuration directory
in this order:

```sh
${XDG_CONFIG_HOME:-"$HOME/.config"}/dot/dotrc
${XDG_CONFIG_HOME:-"$HOME/.config"}/dotrc
$HOME/.dotrc
./.dotrc
```

The configuration file is a standard shell script and will be simply sourced
in `dot` after the defaults have been set but before the flags have been set
from the command line. Meaning you can override the defaults.
To see what you can set, check the script, search for the sourcing of the
config file. Everything above that is overridable.

#### Examples

These ones can be only configured through the files, or by hand, when
executing dot like `DOT_TARGET="./target" dot <module1> <module2>...`

```sh
# The default target of module packages
DOT_TARGET=${DOT_TARGET:-"$HOME"}
# Your dotfiles location. Not directly utilized, only through the next two
DOTFILES_HOME=${DOTFILES_HOME:-"$HOME/.dotfiles"}
# I suggest keeping these relative to DOTFILES_HOME
# Dotmodules will be searched here. Only direct descendant folders.
DOT_MODULES_FOLDER=${DOT_MODULES_FOLDER:-"$DOTFILES_HOME/modules"}
# Presets will be searched from here, recursively
DOT_PRESETS_FOLDER=${DOT_PRESETS_FOLDER:-"$DOTFILES_HOME/presets"}
```

```sh
# Will always remove broken symlinks after execution in DOT_TARGET
DOT_CLEAN_SYMLINKS=1
# Makes it always execute `chmod u+x` on '.*.(sh|zsh|bash|fish|dash)' files in
# the modules. I use it so when making scripts I don't have to deal with it.
DOT_FIX_PERMISSIONS=1
```

### Installing dotmodules

You can optionally set flags, then as much modules/presets/tags as you want.

```sh
dot [-flags] modules...
```

## Dotmodules

> For reference you can also check the [template](./template) directory,
> which containes examples and short description on every available file
> or some of my modules.

When installing a dotmodule successfully, a `.tarhash` file will be created
in the modules directory. (Should be .gitignored). This containes a hash
calculated from the content of the module at the time of install. This enables
dot to skip any module that is **already install** and
**has not changed since**. This is especially important when installing
modules with large dependency trees.

> The `.tarhash` file also marks a module installed.

Modules that are already installed can be forced to be reinstalled using the
`-f` or `--force` flags. It just makes it ignore the hashfile.

### Listing installed modules

Installed modules can be listed and `sort`ed using the `-li` or
`--list-installed` flags. These flags makes `dot` immediately exit.

```sh
dot -li
```

### Listing available modules

Available modules can be listed and `sort`ed using the `-lm` or
`--list-modules` flags. These flags makes `dot` immediately exit.

```sh
dot -lm
```

## Content of a module

Every module can have 3 kinds of files inside, each of them being optional.
An empty module is a valid module too.

## Installation scripts

> Using [script selection flags](#Flagged-scripts), install scripts are
> getting automatically excluded from execution but re-adding the `-x` flag
> after these, these scripts can be re-enabled.

These scripts are what supposed to install packages for your module to work.
And they will run by default when installing a module.

> They are not the only way to describe the installation process of a module.
> You can use a `Makefile` with an `install` target. Both will execute, so
> either only create one type of installation or set a flag to disable one
> of them. See the [Makefiles](#Makefiles) section for more.

Since package management is unique to each system, and not just by having
different commands to install a package. Often their name is different. Or
on a particular distribution you need to install more, or different packages,
or having to add `PPA`s on debian systems etc etc.

So instead of making an overcomplicated solution I let the modules decide
how to install something. This gives great control since you're the one making
the script, `dot` just executes them.

> I may make an easy install for simple cases but this solution will stay
> as it can be used for anything, not just installation

These scripts can also be used to do some other things, like copying a
configuration file into `/etc`

### The scripts names decide how and when they will run

Their names can be separated into 3 segments, separated by 4 dots. Everything
after the 3rd dot is unused.

> \* If you skip the dependency segment then the extension will be read as
> the dependency, but since it's `sh` anyway it will always be true.

### First segment, order and grouping

> **1**.user.sh

The first segment is used for ordering. If multiple scripts are in one
order, they are considered a **script group**.

The only mechanic related to this are `fallback` scripts, more on that in the
[third segment](#Fallback)

### Second segment, privileges

> 0.**root**.sh

is the privilege and it can be two things:

- user
- root

No matter whether you run `dot` with sudo or not, if it has to run a `user`
script it will always `sudo` back to `$SUDO_USER` (If it has to) and it will
always `sudo` into `root` (While keeping your environment) if it's running
`root` scripts.

**This makes sure that your `HOME` folder will only contain items owned by you,
and not `root`.**

> `sudo` will be executed as many time it needs to as I described it above
> most distributions have a timeout enabled by default but if not, prepare
> to write your password in a few times.

In every script, you can also be sure that `.` means the root of that module
as `dot` will `cd` into the module before executing anything.

Using the `-nr` or `--no-root` flags, scripts with `sudo` privileges can be
skipped.

> If you are on a system where you don't have `root` access, but the programs
> are installed and you only need your configurations, you can set this flag
> permamently in a `dotrc`, and only use the `stow`ing mechanism of `dot`.
> The variable controlling this is `root` and is `1` by default.

### Third segment, condition

> 0.root.**pacman**.sh

While modules can have module dependencies, scripts can also have conditions
which can be executable dependencies and variable dependencies, if prefixed
with `$`. If it is, and that variable is set and not empty, it will be
executed. If it's not prefixed with `$`, it will be checked that
`command -v` returns something for it or not. If yes, it will be executed.

> Currently you can only specify 1 dependency on 1 script.

My common usecase for this is checking package managers. So I can have
a separate install script for `pacman` systems, `apt` systems and `xbps`
systems. And each will only execute on their respective platforms.

For variables, it's for things that cant be checked by a simple presence of
an executable. Like if I want to run a script only on `wsl`, or `arch` I can
name my script like `1.user.$wsl.sh`.

#### Fallback

> 0.user.**fallback**.sh

There is an extra special dependency setting called `fallback`, and this is
where `script groups` come into play. If in a script group (Defined by a
common ordering segment) none got executed, `fallback` will. If `fallback` is
alone it will also be executed.

> A usecase for this is the AUR. A lot of packages are available there, so on
> `arch` systems you can probably install anyting using `pacman` or with an
> AUR helper. If that package is only available on AUR, and it can't be
> installed with any other package managers, you can try compile it from
> source or download it using a custom installer script that they provide. Or
> install it with a different program. (Like Rust programs can be installed
> using `cargo install`, or `node` programs with `npm -g`) But instead of
> having a separate script for each system, or a custom script that skips on
> `pacman` systems, just have a `fallback` script.

TODO: enable the use of variables here using the `$` prefix

TODO: Enable having multiple dependencies using `:`

### Init Scripts

> `init.user.sh`

Scripts starting with `init` instead of the ordering first segment are run
before any other script do. And if it's `user` privileged it will not just
run, but it will be sourced so everything that it defines will be available
later.

> Thorough every module after that

These scripts are run before [stowing the stow packages](#Stow-packages) so
they can manually create folders that you don't want stow to
[fold](https://www.gnu.org/software/stow/manual/stow.html#Tree-folding).
These are usually folders that you want to interact with from multiple
packages. Like `~/.config/`, `~/.local/bin` or `~/.config/systemd/user`.

> If you're installing two modules, both to stow to the same path, where
> there is no directory, `stow` for the first module would no create a
> directory, just a single, _folded_ symlink. The second module then would
> just not stow.
>
> There is, in theory a [tree unfolding][stow-un] mechanism in `stow`, but it
> didn't work for me. It's maybe just because I can't use it in these
> conditions because it does not know of the original package that put that
> folded symlink there in the first place.

### Flagged scripts

There can also be some special scripts that are not executed during
standard installation. They are identified by their special first segment and
they can be enabled using flags.

#### Remove

> `remove.sudo.sh`

Using the `-r` flag, scripts with `remove` as their first segment will be run.
This also causes `dot` to `unstow` every **stow package** from the module,
and also removes the `.tarhash` file, marking the module uninstalled.

#### Update

> `update.sudo.sh`

using the `-u` flag, scripts with `update` as their first segment will be run.
Non installed modules can't be updated. This won't expand the dependency graph
and only the mentioned modules will be updated. You can force expanding with
the `-e` flag after the `-u` though to update every dependency too.

> Alternatively create a `Makefile` with an `update` target.

## Config files

There are some files that are used for configuration but they are really
simple and do not follow a common format

### Makefiles

> This is meant for simpler modules where `root` is not needed and direct
> dependencies are not used. For more granular installation (while it can be
> implemented inside the `Makefile`) the regular
> [Installation scripts](#Installation-scripts) are much easier to use.

Makefiles provide an alternative or complementary mode of defining the
installation, update and remove procedures using make targets.
If there is a `Makefile` in the module, it will be executed if `make` is
available, and running makefiles are enabled. (It is by default)

They will always execute after the regular installation scripts and
are always executed using `user` privileges.

### Dependencies

> .dependencies

This file lists all the dependencies the module has. It supports comments,
lines starting with `#`.
Every other line is a dependency and the first word can be the name of a
[module](#Dotmodules) if its not prefixed with anything. It can also be a
[tag](#Tags) if prefixed with `:` or a [preset](#Presets)
if with `+`. More about those in their own sections.

> The same format is used in presets too

#### Dependency resolvment

> Simple [DFS](https://en.wikipedia.org/wiki/Depth-first_search)

When installing a module, first every single dependency it has will be
installed before. **It avoids circular dependencies** by simply stopping at
entries that are already executed and moves on.

> Using the `-sm` or `--show-modules` flag, instead of installing (can be
> turned back on) you only get the list of modules that are gonna be
> executed

#### Conditional dependencies

Dependencies can be conditional. After the dependency statement you can put
a `?`. Everything after that will be `eval`d and then `test`ed. If it's not
true, the dependency will be skipped.

An example usecase for this would be the counterpart of the
[fallback section](#Fallback). There I defined how that module should build
in case no other install scripts can install it. With conditional dependencies
I can also list those that are required only for the fallback, only when
the fallback will actually run. If a rust program can be installed with
`pacman` on arch based systems and on any other systems you want to use
`cargo` you'll end up with 2 install scripts like so:

```sh
0.root.pacman.sh
0.user.cargo.sh
```

and at least one dependency entry:

```sh
rust ? [ ! $pacman ]
```

This tells `dot` only install the `rust` module while installing this module
when there is no `pacman` available.

> There are some pre calculated variables for these use-cases but you can use
> anything, and you can expand it with your `dotrc` as it will be sourced from
> `dot`

Some of them:

```sh
# Package managers
pacman
apt
xbps
# Init systems
systemd
# Distributions
distribution # name in /etc/os-release
arch # if distribution = 'Arch Linux', and so on
void
debian
ubuntu
fedora
```

#### Conditional modules

Sometimes a module doesn't makes sense in an environment, but is used by
many others as a non-essential dependency. In a headless environment like
`wsl`, fonts are like this. It makes no sense to install fonts in `wsl`. But
some of your modules might end up depending on them for convinience.

Instead of marking each dependency with a condition, the module itself can be.
For this, create a file name `.condition` in the modules root. It's content
will simply be `eval`d before executing anything in the module. So not even
`init` will run if `.condition` is false.

### Tags

> .tags

This file also supports comments, and each line defines a tag.
This is used to define a module group on module level.

Tags can be installed using the `:` prefix like so:

```sh
dot :shell
```

This will install every module that has a `.tags` file with the line `shell`.

Tags can both appear in `.dependencies` files and in `*.preset` files.

### Listing available tags

Available tags can be listed and `sort`ed using the `-lt` or `--list-tags`
flags. These flag makes `dot` immediately exit.

```sh
dot -lt
```

## Stow packages

Every directory directly in a module that ends with `.<MODULE_NAME>` is
a stow package.

> So in a module named `zsh`, the `.zsh` directory is a stowable package.

Just like scripts, stow package names are too divided by dots into segments.
The last one as mentioned is for marking a directory as a stow package.

### First segment, target

By default, stow packages will be stowed to `DOT_TARGET` (can be overriden
in a `dotrc` file) which is just `HOME` by default.

To make stowing more dynamic, stow modules can have variables before the `.`
in their names. These variables will then be expanded. If it's an absolute
path it will be treated as such (Ignoring `DOT_TARGET`) but if its a relative
path (it doesn't start with `/`) it will be appended after `DOT_TARGET`.
This path then will be used as the final target to stow to.

> This variable can be set in the `init` script too if you wan't to be module
> specific. These scripts are run before stowing and everything they define
> is available during the installation of the module.

### Second segment, condition

Just like packages, the second segment can be prefixed with `$`. In this case
dot checks if that variable is set or not. If it's not prefixed, it will
check with `command -v` if that it's a valid executable.

## Presets

Presets basically standalone dependency files without anything to install.
They have to have a `.preset` extension and they are searched under
`$DOT_PRESETS_FOLDER` which by default the `presets` directory in your
dotfiles directory.

They can handle everything a normal dependency file can.

You can reference a preset with the `+` prefix. If you have a preset called
`shells.preset`, you can install it like so:

```sh
dot +shells
```

Presets can be included in other presets and dependency files the same way

`.dependencies`

```sh
# this modules dependencies are all the shells I'm using
+shells
# and my vim setup
vim
```

### Listing available presets

Available presets can be listed and `sort`ed using the `-lp` or
`--list-presets` flags. These flags makes `dot` immediately exit.

```sh
dot -lp
```

## Far plans

Once it's done, I might do a Rust rewrite for easier implementation of
paralell execution while respecting the dependency tree.
Which could be done in a script too but having all of the outputs and logs
managed would be hard. The dotmodule "specification" won't really change,
but it can expand.

[stow-un]: https://www.gnu.org/software/stow/manual/stow.html#Tree-unfolding
