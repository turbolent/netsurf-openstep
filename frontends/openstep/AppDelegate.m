/*
 * Copyright 2022 Anthony Cohn-Richardby <anthonyc@gmx.co.uk>
 * Copyright 2026 Bastian Mueller <bastian@turbolent.com>
 *
 * This file is part of NetSurf, http://www.netsurf-browser.org/
 *
 * NetSurf is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License.
 *
 * NetSurf is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <stdlib.h>
#import <string.h>
#import "netsurf/netsurf.h"
#import "utils/nsoption.h"
#import "utils/nsurl.h"
#import "utils/log.h"

#import "AppDelegate.h"
#import "BrowserWindowController.h"
#import "tables/tables.h"
#import "tables/misc.h"
#import "netsurf/browser_window.h"
#import "netsurf/plot_style.h"
#import <libnsfb.h>
#import "framebuffer/bitmap.h"
#import "framebuffer/findfile.h"
#import "framebuffer/font.h"

#define NS_PREFS_FILE ([@"~/.config/NetSurf/prefs" stringByExpandingTildeInPath])

static BrowserWindowController *openstep_active_browser_window;

static char *openstep_strdup(const char *s)
{
	char *copy;
	size_t len;

	if (s == NULL) {
		return NULL;
	}

	len = strlen(s) + 1;
	copy = malloc(len);
	if (copy != NULL) {
		memcpy(copy, s, len);
	}

	return copy;
}

static nserror set_defaults(struct nsoption_s *defaults)
{
	const char * const ca_bundle = [[[NSBundle mainBundle]
		pathForResource: @"ca-bundle" ofType: @""] cString];

	if (ca_bundle == NULL) {
		return NSERROR_BAD_URL;
	}

	nsoption_setnull_charp(ca_bundle, openstep_strdup(ca_bundle));
	defaults[NSOPTION_enable_javascript].value.b = true;
	defaults[NSOPTION_font_default].value.i = PLOT_FONT_FAMILY_SERIF;
	defaults[NSOPTION_font_size].value.i = 105;
	defaults[NSOPTION_font_min_size].value.i = 70;
	defaults[NSOPTION_max_fetchers].value.i = 8;
	defaults[NSOPTION_max_fetchers_per_host].value.i = 2;
	defaults[NSOPTION_max_cached_fetch_handles].value.i = 2;
	return NSERROR_OK;
}

@implementation AppDelegate

-(void)applicationDidFinishLaunching: (NSNotification*)aNotification
{
	[self installOpenStepMenu];
	[self didTapNewWindow: nil];
}

static NSMenu *openstep_add_submenu(NSMenu *mainMenu, NSString *title, int tag)
{
	NSMenu *submenu;
	NSMenuItem *menuItem;

	submenu = [[NSMenu alloc] initWithTitle: title];
	menuItem = [mainMenu addItemWithTitle: title action: (SEL)nil
		keyEquivalent: @""];
	[menuItem setTag: tag];
	[mainMenu setSubmenu: submenu forItem: menuItem];
	return submenu;
}

static void openstep_add_menu_item(NSMenu *menu, NSString *title, SEL action,
		NSString *key, id target, int tag)
{
	NSMenuItem *item;

	item = [menu addItemWithTitle: title action: action keyEquivalent: key];
	if (target != nil) {
		[item setTarget: target];
	}
	if (tag != 0) {
		[item setTag: tag];
	}
}

-(void)installOpenStepMenu
{
	NSMenu *mainMenu;
	NSMenu *fileMenu;
	NSMenu *editMenu;
	NSMenu *navigateMenu;
	NSMenu *viewMenu;

	mainMenu = [[NSMenu alloc] initWithTitle: @"NetSurf"];

	fileMenu = openstep_add_submenu(mainMenu, @"File", 0);
	openstep_add_menu_item(fileMenu, @"New Window", @selector(didTapNewWindow:),
		@"n", self, 0);
	openstep_add_menu_item(fileMenu, @"Close", @selector(performClose:),
		@"w", nil, 0);

	editMenu = openstep_add_submenu(mainMenu, @"Edit", 0);
	openstep_add_menu_item(editMenu, @"Cut", @selector(cut:), @"x", nil,
		TAG_MENU_CUT);
	openstep_add_menu_item(editMenu, @"Copy", @selector(copy:), @"c", self,
		TAG_MENU_COPY);
	openstep_add_menu_item(editMenu, @"Paste", @selector(paste:), @"v", nil,
		TAG_MENU_PASTE);
	openstep_add_menu_item(editMenu, @"Select All", @selector(selectAll:), @"a",
		nil, 0);

	navigateMenu = openstep_add_submenu(mainMenu, @"Navigate", 0);
	openstep_add_menu_item(navigateMenu, @"Back", @selector(back:), @"[",
		self, 0);
	openstep_add_menu_item(navigateMenu, @"Forward", @selector(forward:), @"]",
		self, 0);
	openstep_add_menu_item(navigateMenu, @"Reload", @selector(reload:), @"r",
		self, 0);
	openstep_add_menu_item(navigateMenu, @"Stop", @selector(stopLoading:), @".",
		self, 0);

	viewMenu = openstep_add_submenu(mainMenu, @"View", 0);
	openstep_add_menu_item(viewMenu, @"Zoom In", @selector(zoomIn:), @"+",
		self, 0);
	openstep_add_menu_item(viewMenu, @"Zoom Out", @selector(zoomOut:), @"-",
		self, 0);
	openstep_add_menu_item(viewMenu, @"Actual Size", @selector(resetZoom:), @"0",
		self, 0);

	openstep_add_menu_item(mainMenu, @"Quit", @selector(terminate:), @"q",
		NSApp, 0);

	[NSApp setMainMenu: mainMenu];
}

-(void)awakeFromNib
{
	[self didTapNewWindow: nil];
}

-(void)didTapNewWindow: (id)sender
{
	BrowserWindowController *controller = [[BrowserWindowController alloc]
		initWithBrowser: NULL];
	openstep_active_browser_window = controller;
	[controller loadWindow];
}

-(BrowserWindowController*)activeBrowserWindow
{
	return openstep_active_browser_window;
}

-(NSString*)currentUrl
{
	return [[self activeBrowserWindow] visibleUrl];
}

-(void)back: (id)sender { [[self activeBrowserWindow] back: sender]; }
-(void)forward: (id)sender { [[self activeBrowserWindow] forward: sender]; }
-(void)reload: (id)sender { [[self activeBrowserWindow] reload: sender]; }
-(void)stopLoading: (id)sender { [[self activeBrowserWindow] stopLoading: sender]; }
-(void)copy: (id)sender { [[self activeBrowserWindow] copy: sender]; }
-(void)zoomIn: (id)sender { [[self activeBrowserWindow] zoomIn: sender]; }
-(void)zoomOut: (id)sender { [[self activeBrowserWindow] zoomOut: sender]; }
-(void)resetZoom: (id)sender { [[self activeBrowserWindow] resetZoom: sender]; }

@end

int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSString *bundleFontPath;
	NSString *resourceSearchPath;
	nserror error;
	NSApplication *app;
	AppDelegate *delegate;
	struct netsurf_table openstep_table = {
		.misc = &openstep_misc_table,
		.window = &openstep_window_table,
		.clipboard = &openstep_clipboard_table,
		.fetch = &openstep_fetch_table,
		.bitmap = framebuffer_bitmap_table,
		.layout = framebuffer_layout_table,
		.utf8 = framebuffer_utf8_table,
	};

	nslog_init(NULL, &argc, argv);
	error = netsurf_register(&openstep_table);
	NSCAssert(error == NSERROR_OK, @"NetSurf operation table failed registration");

	error = nsoption_init(set_defaults, &nsoptions, &nsoptions_default);
	NSCAssert(error == NSERROR_OK, @"Options failed to initialise");
	error = nsoption_read([NS_PREFS_FILE cString], nsoptions);
	if (error != NSERROR_OK) {
		NSLOG(netsurf, INFO, "Failed to load user preferences");
	}
	bundleFontPath = [[[NSBundle mainBundle] resourcePath]
		stringByAppendingPathComponent: @"Fonts"];
	resourceSearchPath = [NSString stringWithFormat: @"%@:%s:%s",
		bundleFontPath,
		NETSURF_OPENSTEP_RES_PATH,
		NETSURF_FB_FONTPATH];
	respaths = fb_init_resource_path([resourceSearchPath cString]);
	NSCAssert(respaths != NULL,
		@"Framebuffer resource path initialisation failed");
	error = netsurf_init(NULL);
	NSCAssert(error == NSERROR_OK, @"NetSurf failed to initialise");

	NSCAssert(fb_font_init() == true,
		@"Framebuffer font system failed to initialise");

	app = [NSApplication sharedApplication];
	delegate = [AppDelegate new];
	[app setDelegate: delegate];
	[app run];
	[pool release];
	return 0;
}
