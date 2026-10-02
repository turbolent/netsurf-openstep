NetSurf 3.12 development build for OPENSTEP Intel
================================================

Requires OPENSTEP 4.2 for Intel. Extract the binary tar.gz and copy NetSurf.app
to a directory of your choice, then launch it from Workspace Manager.
The app includes fonts, stylesheets, images, and CA certificates. It does not
require the compiler or /usr/local third-party libraries. This is a development
build, not a stable NetSurf release.

Networking uses system network and DNS settings. If every site reports
"could not resolve hostname", check system DNS first. On the test host,
creating /etc/resolv.conf with a reachable nameserver and sending SIGHUP to
the PID in /etc/lookupd.pid fixed resolution without a reboot. Make system
changes as administrator using a DNS server appropriate for your network.
The app does not change network configuration.

The CA snapshot is dated 2026-05-14. To refresh trust roots, replace
NetSurf.app/ca-bundle with an appropriate PEM CA bundle and preserve its
notices. TLS certificate checking is not disabled.

Preferences, if present, are read from ~/.config/NetSurf/prefs. A custom
ca_bundle preference can override the bundled certificate file.

See VALIDATION.txt for checks actually performed and their limitations.
Keep the matching -source.tar.gz alongside the binary archive when sharing.
It includes source, dependency patches, and build instructions. License
texts are in NetSurf.app/Resources/Licenses.
