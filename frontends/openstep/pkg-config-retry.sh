#!/bin/sh

# The OPENSTEP pkg-config/glib port can occasionally terminate with SIGBUS.
# Feature probes are idempotent, so retry a crashed query before reporting it
# as a genuinely missing package.
for attempt in 1 2 3 4 5
do
	/usr/local/bin/pkg-config "$@" && exit 0
done

exit 1
