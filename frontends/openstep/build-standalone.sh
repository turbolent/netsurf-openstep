#!/bin/sh

set -e

die()
{
	echo "error: $*" >&2
	exit 1
}

ensure_dir()
{
	dir=$1
	test -d "$dir" && return 0

	case $dir in
		/*) current=/ ;;
		*) current=. ;;
	esac

	old_ifs=$IFS
	IFS=/
	set -- $dir
	IFS=$old_ifs
	for part
	do
		test -n "$part" || continue
		if test "$current" = /; then
			current=/$part
		else
			current=$current/$part
		fi
		test -d "$current" || mkdir "$current"
	done
}

SOURCE_ROOT=`pwd`
WORK_ROOT=$SOURCE_ROOT/build/openstep-standalone
STATIC_LIB_DIR=$WORK_ROOT/StaticLibraries
APP_DIR=$SOURCE_ROOT/NetSurf.app
DIST_DIR=$SOURCE_ROOT/dist
ARCHIVE_NAME=NetSurf-3.12-dev-openstep-i386.tar.gz

case $WORK_ROOT in
	"$SOURCE_ROOT"/build/openstep-standalone) ;;
	*) die "refusing unsafe standalone work path: $WORK_ROOT" ;;
esac

if test "x$1" = x--clean; then
	/bin/rm -rf "$WORK_ROOT"
	/bin/rm -rf "$SOURCE_ROOT/build/NeXT-openstep"
	/bin/rm -rf "$APP_DIR"
	/bin/rm -f "$DIST_DIR/$ARCHIVE_NAME"
	exit 0
fi

test -f "$SOURCE_ROOT/Makefile" || die "run this script from the NetSurf source root"
test -n "$1" || die "missing openstep-pkg checkout path"
test -f "$SOURCE_ROOT/frontends/openstep/res/fonts/LICENSE-DejaVu" || \
	die "missing bundled DejaVu license"

OPENSTEP_PKG_DIR=$1
case $OPENSTEP_PKG_DIR in
	/*) ;;
	*) die "OPENSTEP_PKG_DIR must be an absolute path" ;;
esac

test -f "$OPENSTEP_PKG_DIR/pkg" || die "missing $OPENSTEP_PKG_DIR/pkg"

PACKAGES="gcc42 make pkg-config netsurf-buildsystem nsgenbind ca-certificates zlib libpng jpeg openssl curl expat freetype utf8proc libiconv libnsutils libparserutils libwapcaplet libhubbub libcss libdom libnsbmp libnsgif libsvgtiny libnslog libnsfb"

echo "==> Installing standalone build dependencies"
(
	cd "$OPENSTEP_PKG_DIR"
	/bin/sh ./pkg install $PACKAGES
)

for tool in /bin/otool /usr/local/bin/gcc-4.2 /usr/local/bin/gnumake /usr/local/bin/pkg-config
do
	test -x "$tool" || die "missing required tool: $tool"
done

for package in $PACKAGES
do
	test -f "$OPENSTEP_PKG_DIR/$package/version" || \
		die "missing package metadata: $package/version"
done

/bin/rm -rf "$WORK_ROOT"
ensure_dir "$STATIC_LIB_DIR"

# OPENSTEP ld has no @executable_path/rpath equivalent, and repeated
# libtool -dynamic -all_load conversions can wedge this host.  Put links to
# the package archives in a directory searched before /usr/local/lib instead;
# every third-party -l option is consequently resolved into NetSurf itself.
ARCHIVES="libz.a libpng16.a libjpeg.a libssl.a libcrypto.a libcurl.a \
libexpat.a libfreetype.a libutf8proc.a libiconv.a libcharset.a libnsutils.a libparserutils.a \
libwapcaplet.a libhubbub.a libcss.a libdom.a libnsbmp.a libnsgif.a \
libsvgtiny.a libnslog.a libnsfb.a"
for archive in $ARCHIVES
do
	test -f "/usr/local/lib/$archive" || \
		die "missing archive: /usr/local/lib/$archive"
	/bin/ln -s "/usr/local/lib/$archive" "$STATIC_LIB_DIR/$archive"
done

echo "==> Building NetSurf payload"
/bin/rm -f "$SOURCE_ROOT/NetSurf"
PATH=/usr/local/bin:/usr/ucb:/bin:/usr/bin:$PATH
export PATH
NETSURF_OPENSTEP_STANDALONE_STATIC_LIBDIR=$STATIC_LIB_DIR
export NETSURF_OPENSTEP_STANDALONE_STATIC_LIBDIR
build_succeeded=no
for attempt in 1 2 3 4 5
do
	if /usr/local/bin/gnumake HOST=NeXT TARGET=openstep \
		CC_CAN_BUILD_AND_DEP=no \
		CC_CANNOT_DEP=yes \
		CCACHE= \
		OPTCFLAGS="-DNDEBUG -O0" \
		OPTCXXFLAGS="-DNDEBUG -O0" \
		NetSurf; then
		build_succeeded=yes
		break
	fi
	echo "==> NetSurf build attempt $attempt failed; retrying incomplete targets"
done
test "$build_succeeded" = yes || die "NetSurf build failed after five attempts"

echo "==> Assembling NetSurf.app"
/bin/rm -rf "$APP_DIR"
ensure_dir "$APP_DIR/Resources/Fonts"
ensure_dir "$APP_DIR/Resources/Licenses"

/bin/cp "$SOURCE_ROOT/NetSurf" "$APP_DIR/NetSurf"

/bin/cp "$SOURCE_ROOT/frontends/openstep/res/NetSurf.icns" "$APP_DIR"
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/NetSurf.tiff" "$APP_DIR"
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/NetSurf.iconheader" "$APP_DIR/Resources"
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/NetSurf.tiff" "$APP_DIR/Resources"
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/Left.tiff" "$APP_DIR/Resources"
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/Reload.tiff" "$APP_DIR/Resources"
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/Right.tiff" "$APP_DIR/Resources"
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/Stop.tiff" "$APP_DIR/Resources"

for resource in adblock.css default.css internal.css quirks.css forward.png back.png refresh.png search.png
do
	/bin/cp "$SOURCE_ROOT/resources/$resource" "$APP_DIR"
done

/bin/cp "$SOURCE_ROOT/frontends/openstep/res/ca-bundle" "$APP_DIR/ca-bundle"
for font in $SOURCE_ROOT/frontends/openstep/res/fonts/*.ttf
do
	test -f "$font" || die "missing bundled font: $font"
	/bin/cp "$font" "$APP_DIR/Resources/Fonts"
done
/bin/cp "$SOURCE_ROOT/frontends/openstep/res/fonts/LICENSE-DejaVu" "$APP_DIR/Resources/Licenses/LICENSE-DejaVu"
/bin/cp "$SOURCE_ROOT/COPYING" "$APP_DIR/Resources/Licenses/NetSurf-COPYING"
/bin/cp "$SOURCE_ROOT/frontends/openstep/THIRD_PARTY_NOTICES" "$APP_DIR/Resources/Licenses"
/bin/cp -R "$SOURCE_ROOT/frontends/openstep/res/licenses/." "$APP_DIR/Resources/Licenses/"
/bin/cp "$SOURCE_ROOT/frontends/openstep/RELEASE-README.txt" "$APP_DIR/Resources/README.txt"

MANIFEST=$APP_DIR/Resources/BuildManifest.txt
echo "NetSurf 3.12-dev for OPENSTEP i386" > "$MANIFEST"
echo "" >> "$MANIFEST"
echo "openstep-pkg inputs:" >> "$MANIFEST"
for package in $PACKAGES
do
	version=`sed -n '1p' "$OPENSTEP_PKG_DIR/$package/version"`
	echo "$package $version" >> "$MANIFEST"
done

echo "==> Auditing load commands"
binary="$APP_DIR/NetSurf"
/bin/otool -L "$binary" > "$WORK_ROOT/otool.out"
/bin/sed -n '2,$s/^[ 	]*\([^ 	]*\).*/\1/p' \
	"$WORK_ROOT/otool.out" > "$WORK_ROOT/dependencies.out"
while read dependency
do
	case $dependency in
		/usr/lib/*|/System/*|/NextLibrary/*)
			;;
		*)
			/bin/cat "$WORK_ROOT/otool.out" >&2
			die "third-party load command remains in $binary: $dependency"
			;;
	esac
done < "$WORK_ROOT/dependencies.out"

ensure_dir "$DIST_DIR"
/bin/rm -f "$DIST_DIR/$ARCHIVE_NAME"
(
	cd "$SOURCE_ROOT"
	/usr/bin/gnutar czf "$DIST_DIR/$ARCHIVE_NAME" NetSurf.app
)

echo "==> Standalone application: $APP_DIR"
echo "==> Release archive: $DIST_DIR/$ARCHIVE_NAME"
