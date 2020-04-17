# Template

This folder contains a module template which can be used by `cpt` to
quickly scaffold you a module with your commonly used files

## Requirements

Rust and cargo installed

If cargo is available and cpt is not, dot will attempt to install it
on scaffolding

## Usage

```sh
dot --scaffold <modules...>
```

This will copy this folder as many times as many arguments you gave to it
overwriting every intance of `{{name}}` with the modules name.

If a module already exists, it will be ignored.

Only files with a `.tpl` extension will be affected, the rest is just copied
the `.tpl` extension will be ommitted. (`a.sh.tpl` will become `a.sh`)
