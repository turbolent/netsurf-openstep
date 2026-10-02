
THIS FORK
=======

This fork aims at getting a usable version of NetSurf running under OPENSTEP.

To build, run `gnumake HOST=NeXT TARGET=openstep`.

Standalone OPENSTEP release
---------------------------

The standalone release target uses an existing `openstep-pkg` checkout to
install the build toolchain and build the dependency archives.  The checkout
path is deliberately explicit:

```
/bin/gnumake -f frontends/openstep/Makefile.standalone \
    standalone \
    OPENSTEP_PKG_DIR=/absolute/path/to/openstep-pkg
```

The target produces `NetSurf.app` and
`dist/NetSurf-3.12-dev-openstep-i386.tar.gz`.  Third-party libraries are
linked into the application executable, and the DejaVu fonts are stored in
the bundle.  The packages installed under `/usr/local` are build inputs only
and are not needed by users of the finished application.

Use the corresponding cleanup target to remove standalone build products:

```
/bin/gnumake -f frontends/openstep/Makefile.standalone clean-standalone
```

For release installation and source rebuild instructions, see
`frontends/openstep/RELEASE-README.txt` and
`frontends/openstep/RELEASE-BUILDING.txt`. The regular app-bundle target also
includes fonts, third-party license texts, and the pinned CA bundle.
`tools/package-openstep-release.py` assembles matching binary/source archives
and checksums from an audited native build and verified dependency inputs.

ORIGINAL NETSURF README
----------------

NetSurf
=======

This document should help point you at various useful bits of information.


Building NetSurf
----------------

Read the [Quick Start](docs/quick-start.md) document for instructions.


Creating a new port
-------------------

Look at the existing front ends for example implementations.
The framebuffer front end is simplest and most self-contained.
Also, you can [contact the developers](https://www.netsurf-browser.org/contact/)
for help.


Further documentation
---------------------

* [Developer documentation](https://www.netsurf-browser.org/developers/)
* [Developer wiki](https://wiki.netsurf-browser.org/Documentation/)
* [Code style guide](https://www.netsurf-browser.org/developers/StyleGuide.pdf)
