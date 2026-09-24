---
title: Installing Swift and alula-cli
description: Get a Swift toolchain and the alula command on your machine.
order: 1
---

You need two things before you write a line of Alula: a Swift toolchain,
and the `alula` command itself.

## Swift

Alula targets Swift 6.3 or later, on Linux or macOS 15+. If you already
have `swift --version` printing 6.3 or newer, skip ahead.

**On a Mac, you also need the macOS 26 SDK — Xcode 26.** That is a requirement
to *build*, not to run: what you build still runs on macOS 15. Alula's
configuration layer reaches for FoundationEssentials, which older Darwin SDKs
do not offer, and the failure looks unrelated to the SDK when you hit it — an
error about `Data` having no member `bytes`, inside a package you did not
write. On Linux there is nothing extra to install.

If not, [Swiftly](https://www.swift.org/install/) is the fastest path on
either platform:

```bash
curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
tar zxf swiftly-$(uname -m).tar.gz
./swiftly init
swiftly install latest
```

Confirm it:

```bash
swift --version
# Swift version 6.3.x
```

## alula-cli

`alula` is not published as a binary yet, so you build it from source —
which, on a Swift project, is one command:

```bash
git clone https://github.com/Alula-Framework/alula-cli.git
cd alula-cli
swift build -c release
cp .build/release/alula ~/.local/bin/
```

Make sure `~/.local/bin` is on your `PATH`, then:

```bash
alula --help
```

If that prints a usage summary, you're set. Everything from here on is one
command away.

## Why build it yourself, for now

The templates `alula new` emits are embedded directly in the binary —
copied in at build time from the exact `templates/` directory this
tutorial's exercises are generated from. Building from source means the
`alula` on your machine and the `alula` this tutorial was written against
are, by construction, the same one. A packaged binary release is coming;
until it does, `swift build -c release` *is* the install step, not a
workaround for one.
