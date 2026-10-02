# ----------------------------------------------------------------------------
# OPENSTEP target setup
# ----------------------------------------------------------------------------

POSTEXES += NetSurf.app

SDK_CFLAGS := -F/NextLibrary/Frameworks
SDK_LDFLAGS := -F/NextLibrary/Frameworks -framework Foundation -framework AppKit
OBJC_CC := /usr/local/bin/gcc-4.2
LINK_CC := /usr/local/bin/gcc-4.2

CFLAGS :=  $(SDK_CFLAGS) $(CFLAGS)
CFLAGS += -I/NextDeveloper/Headers/bsd -I/usr/include/bsd
CFLAGS += -Ifrontends/openstep
CFLAGS += '-DNETSURF_OPENSTEP_RES_PATH="$(NETSURF_OPENSTEP_RES_PATH)"'
LDFLAGS :=  $(SDK_LDFLAGS) $(LDFLAGS)
CXXFLAGS :=  $(SDK_CFLAGS) $(CXXFLAGS)

LDFLAGS += -L/usr/lib
LDFLAGS += -L/usr/X11/lib
LDFLAGS += -lm -lcurl
LDFLAGS += -lssl -lcrypto

LDFLAGS += -sectcreate __ICON __header $(FRONTEND_RESOURCES_DIR)/NetSurf.iconheader
LDFLAGS += -segprot __ICON r r
LDFLAGS += -sectcreate __ICON app $(FRONTEND_RESOURCES_DIR)/NetSurf.tiff

CFLAGS += -D_BSD_SOURCE -D_POSIX_C_SOURCE -std=c99 -g
ifneq ($(NETSURF_OPENSTEP_STANDALONE_STATIC_LIBDIR),)
CFLAGS += -O0
else
CFLAGS += -Os
endif
CFLAGS += -I/usr/X11/include

CFLAGS += -Ifrontends/framebuffer
CFLAGS += -DNETSURF_OPENSTEP_USE_FRAMEBUFFER -Dnsframebuffer
CFLAGS += '-DNETSURF_FB_RESPATH="$(NETSURF_OPENSTEP_RES_PATH)"'
CFLAGS += '-DNETSURF_FB_FONTPATH="$(NETSURF_FB_FONTPATH)"'
CFLAGS += '-DNETSURF_FB_FONT_SANS_SERIF="$(NETSURF_FB_FONT_SANS_SERIF)"'
CFLAGS += '-DNETSURF_FB_FONT_SANS_SERIF_BOLD="$(NETSURF_FB_FONT_SANS_SERIF_BOLD)"'
CFLAGS += '-DNETSURF_FB_FONT_SANS_SERIF_ITALIC="$(NETSURF_FB_FONT_SANS_SERIF_ITALIC)"'
CFLAGS += '-DNETSURF_FB_FONT_SANS_SERIF_ITALIC_BOLD="$(NETSURF_FB_FONT_SANS_SERIF_ITALIC_BOLD)"'
CFLAGS += '-DNETSURF_FB_FONT_SERIF="$(NETSURF_FB_FONT_SERIF)"'
CFLAGS += '-DNETSURF_FB_FONT_SERIF_BOLD="$(NETSURF_FB_FONT_SERIF_BOLD)"'
CFLAGS += '-DNETSURF_FB_FONT_SERIF_ITALIC="$(NETSURF_FB_FONT_SERIF_ITALIC)"'
CFLAGS += '-DNETSURF_FB_FONT_SERIF_ITALIC_BOLD="$(NETSURF_FB_FONT_SERIF_ITALIC_BOLD)"'
CFLAGS += '-DNETSURF_FB_FONT_MONOSPACE="$(NETSURF_FB_FONT_MONOSPACE)"'
CFLAGS += '-DNETSURF_FB_FONT_MONOSPACE_BOLD="$(NETSURF_FB_FONT_MONOSPACE_BOLD)"'
CFLAGS += '-DNETSURF_FB_FONT_MONOSPACE_ITALIC="$(NETSURF_FB_FONT_MONOSPACE_ITALIC)"'
CFLAGS += '-DNETSURF_FB_FONT_MONOSPACE_ITALIC_BOLD="$(NETSURF_FB_FONT_MONOSPACE_ITALIC_BOLD)"'
CFLAGS += '-DNETSURF_FB_FONT_CURSIVE="$(NETSURF_FB_FONT_CURSIVE)"'
CFLAGS += '-DNETSURF_FB_FONT_FANTASY="$(NETSURF_FB_FONT_FANTASY)"'
CFLAGS += $(shell $(PKG_CONFIG) --cflags libnsfb)
LDFLAGS += $(shell $(PKG_CONFIG) --libs libnsfb)
ifeq ($(NETSURF_FB_FONTLIB),freetype)
CFLAGS += -DFB_USE_FREETYPE $(shell $(PKG_CONFIG) --cflags freetype2)
LDFLAGS += $(shell $(PKG_CONFIG) --libs freetype2)
endif

# A standalone build places copies of every third-party archive here.  Keeping
# this directory first makes each -l option select an archive even when a
# package has also installed a dylib under /usr/local/lib.
ifneq ($(NETSURF_OPENSTEP_STANDALONE_STATIC_LIBDIR),)
  LDFLAGS := -L$(NETSURF_OPENSTEP_STANDALONE_STATIC_LIBDIR) $(LDFLAGS)
endif

OBJCFLAGS := $(filter-out -std=c99,$(CFLAGS)) -std=gnu99 -fconstant-string-class=NSConstantString
OBJC_WARNFLAGS :=

VERSION_FULL := $(shell sed -n '/_version.*=.*"/{s/.*"\(.*\)".*/\1/;p;}' desktop/version.c)
VERSION_MAJ := $(shell sed -n '/_major/{s/.* = \([0-9]*\).*/\1/;p;}' desktop/version.c)
VERSION_MIN := $(shell sed -n '/_minor/{s/.* = \([0-9]*\).*/\1/;p;}' desktop/version.c)


# ----------------------------------------------------------------------------
# Source file setup
# ----------------------------------------------------------------------------

# sources for the OPENSTEP build
S_FRONTEND := \
	AppDelegate.m	\
	BrowserWindowController.m	\
	FrameBufferRenderer.m	\
	PlotView.m	\
	NetsurfCallback.m	\
	tables/misc.m	\
	tables/clipboard.m	\
	tables/fetch.m	\
	tables/window.m	\
	../framebuffer/framebuffer.c	\
	../framebuffer/bitmap.c	\
	../framebuffer/findfile.c	\
	../framebuffer/font_$(NETSURF_FB_FONTLIB).c

# This is the final source build list
# Note this is deliberately *not* expanded here as common and image
#   are not yet available
SOURCES = $(S_COMMON) $(S_IMAGE) $(S_BROWSER) $(S_FRONTEND)

# Ensure the testament is run
content/fetchers/about/about.c: testament

EXETARGET := NetSurf

R_RESOURCES := \
	NetSurf.iconheader	\
	NetSurf.tiff	\
	Left.tiff	\
	Reload.tiff	\
	Right.tiff	\
	Stop.tiff	\


R_RESOURCES := $(addprefix $(FRONTEND_RESOURCES_DIR)/,$(R_RESOURCES))

FONT_RESOURCES := $(addprefix $(FRONTEND_RESOURCES_DIR)/fonts/, \
	DejaVuSans.ttf DejaVuSans-Bold.ttf \
	DejaVuSans-Oblique.ttf DejaVuSans-BoldOblique.ttf \
	DejaVuSansMono.ttf DejaVuSansMono-Bold.ttf \
	DejaVuSansMono-Oblique.ttf DejaVuSansMono-BoldOblique.ttf \
	DejaVuSerif.ttf DejaVuSerif-Bold.ttf \
	DejaVuSerif-Italic.ttf DejaVuSerif-BoldItalic.ttf)
FONT_LICENSE := $(FRONTEND_RESOURCES_DIR)/fonts/LICENSE-DejaVu

E_RESOURCES := \
	adblock.css	\
	default.css	\
	internal.css	\
	quirks.css	\
	forward.png	\
	back.png	\
	refresh.png	\
	search.png	\

E_RESOURCES := $(addprefix resources/,$(E_RESOURCES))


LANGUAGES := en
LOCALIZED_RESOURCES := Localizable.strings

# ----------------------------------------------------------------------------
# Install target
# ----------------------------------------------------------------------------

install-openstep: NetSurf.app

.PHONY: package-openstep-resources
NetSurf.app: NetSurf $(FRONTEND_SOURCE_DIR)/Makefile $(R_RESOURCES) $(FONT_RESOURCES) $(FONT_LICENSE) package-openstep-resources
	$(VQ)echo Assembling NetSurf.app bundle
	$(Q)test -d NetSurf.app || mkdir NetSurf.app
	$(Q)cp NetSurf NetSurf.app/
	$(Q)cp $(FRONTEND_RESOURCES_DIR)/NetSurf.icns NetSurf.app
	$(Q)cp $(FRONTEND_RESOURCES_DIR)/NetSurf.tiff NetSurf.app
	$(Q)mkdir -p NetSurf.app/Resources
	$(Q)cp -pLR $(R_RESOURCES) NetSurf.app/Resources
	$(Q)cp -pLR $(E_RESOURCES) NetSurf.app/
	$(Q)mkdir -p NetSurf.app/Resources/Fonts NetSurf.app/Resources/Licenses
	$(Q)cp -p $(FONT_RESOURCES) NetSurf.app/Resources/Fonts/
	$(Q)cp -p $(FONT_LICENSE) NetSurf.app/Resources/Licenses/
	$(Q)cp -pR $(FRONTEND_RESOURCES_DIR)/licenses/. NetSurf.app/Resources/Licenses/
	$(Q)cp -p COPYING NetSurf.app/Resources/Licenses/NetSurf-COPYING
	$(Q)cp -p $(FRONTEND_SOURCE_DIR)/THIRD_PARTY_NOTICES NetSurf.app/Resources/Licenses/
	$(Q)cp -p $(FRONTEND_SOURCE_DIR)/RELEASE-README.txt NetSurf.app/Resources/README.txt
	$(Q)cp -p $(FRONTEND_RESOURCES_DIR)/ca-bundle NetSurf.app/ca-bundle

CLEANS += clean-package-openstep

clean-package-openstep:
	$(VQ)echo "   CLEAN: NetSurf.app"
	$(Q)$(RM) -r NetSurf.app
