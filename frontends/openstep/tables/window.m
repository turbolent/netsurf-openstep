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

#import "AppDelegate.h"
#import "BrowserWindowController.h"
#import "netsurf/browser_window.h"
#import "netsurf/netsurf.h"
#import "netsurf/window.h"
#import "netsurf/types.h"
#import "utils/log.h"
#import "utils/nsurl.h"
#import "netsurf/mouse.h"
#import "netsurf/form.h"

struct window_handle {
	BrowserWindowController *window;
};

/********************/
/****** Window ******/
/********************/

// Create and open a browser window
static struct gui_window *openstep_window_create(struct browser_window *bw,
			struct gui_window *existing,
			gui_window_create_flags flags) {
	BrowserWindowController *controller = nil;
	(void)existing;
	(void)flags;
	if ([BrowserWindowController pendingBrowserTarget] != nil) {
		controller = [BrowserWindowController pendingBrowserTarget];
		[controller attachBrowser: bw];
	}
	if (controller == nil) {
		controller = [[BrowserWindowController alloc]
		initWithBrowser: bw];
		[controller loadWindow];
	}
	[BrowserWindowController setPendingBrowserTarget: nil];
	struct window_handle *window = malloc(sizeof (struct window_handle));
	window->window = controller;
	return (struct gui_window*)window;
}

// Destroy the specified window
static void openstep_window_destroy(struct gui_window *gw) {
	struct window_handle *window = (struct window_handle*)gw;
	[window->window netsurfWindowDestroy];
	free(window);
}

// Trigger a redraw of the specified area, or the entire window if null
static nserror openstep_window_invalidate(struct gui_window *gw, const struct rect *rect) {
	struct window_handle *window = (struct window_handle*)gw;
	if (rect == NULL) {
		[window->window invalidateBrowser];
	} else {
		int width = rect->x1 - rect->x0;
		int height = rect->y1 - rect->y0;
		if (width <= 0 || height <= 0) {
			return NSERROR_OK;
		}
		[window->window invalidateBrowser: NSMakeRect(rect->x0, rect->y0,
			width, height)];
	}
	return NSERROR_OK;
}

// Put the current scroll offset into sx and sy
static bool openstep_window_get_scroll(struct gui_window *gw, int *sx, int *sy) {
	struct window_handle *window = (struct window_handle*)gw;
	NSPoint scroll = [window->window getBrowserScroll];
	*sx = scroll.x;
	*sy = scroll.y;
	return true;
}

// Set the current scroll offset
static nserror openstep_window_set_scroll(struct gui_window *gw, const struct rect *rect) {
	struct window_handle *window = (struct window_handle*)gw;
	[window->window setBrowserScroll: NSMakePoint(rect->x0, rect->y0)];
	return NSERROR_OK;
}

// Put the dimensions of the specified window into width, height
static nserror openstep_window_get_dimensions(struct gui_window *gw, int *width, int *height) {
	struct window_handle *window = (struct window_handle*)gw;
	NSSize size = [window->window getBrowserSize];
	*width = size.width;
	*height = size.height;
	return NSERROR_OK;
}

// Some kind of event happened
static nserror openstep_window_event(struct gui_window *gw, enum gui_window_event event) {
	struct window_handle *window = (struct window_handle*)gw;
	switch (event) {
	case GW_EVENT_UPDATE_EXTENT:
		[window->window updateBrowserExtent];
		break;
	case GW_EVENT_REMOVE_CARET:
		[window->window removeCaret];
		break;
	case GW_EVENT_NEW_CONTENT:
		[window->window newContent];
		break;
	case GW_EVENT_START_THROBBER:
		[window->window startThrobber];
		break;
	case GW_EVENT_STOP_THROBBER:
		[window->window stopThrobber];
		break;
	default:
		break;
	}
	return NSERROR_OK;
}

static void openstep_window_set_title(struct gui_window *gw, const char *title) {
	struct window_handle *window = (struct window_handle*)gw;
	[window->window setTitle: [NSString stringWithCString: title]];
}

static nserror openstep_window_set_url(struct gui_window *gw, struct nsurl *url) {
	struct window_handle *window = (struct window_handle*)gw;
	NSString *urlStr = [NSString stringWithCString: nsurl_access(url)];
	[window->window setNavigationUrl: urlStr];
	return NSERROR_OK;
}

static void openstep_window_set_status(struct gui_window *gw, const char *text) {
	struct window_handle *window = (struct window_handle*)gw;
	NSString *statusText = text ? [NSString stringWithCString: text] : @"";
	[window->window setStatusText: statusText];
}

static void openstep_window_set_pointer(struct gui_window *gw, enum gui_pointer_shape shape) {
	struct window_handle *window = (struct window_handle*)gw;
	[window->window setPointerToShape: shape];
}

static void openstep_window_place_caret(struct gui_window *gw, int x, int y, int height, const struct rect *clip) {
	struct window_handle *window = (struct window_handle*)gw;
	(void)clip;
	[window->window placeCaretAtX: x y: y height: height];
}

static void openstep_window_create_form_select_menu(struct gui_window *gw, struct form_control *control) {
	struct form_option *opt;
	struct rect rect;
	struct window_handle *window = (struct window_handle*)gw;
	if (form_control_bounding_rect(control, &rect) != NSERROR_OK) {
		NSLOG(netsurf, WARNING,
			"Failed to get control bounding rect, skipping");
		return;
	}
	NSMutableArray *options = [NSMutableArray array];
	for(opt = form_select_get_option(control, 0); opt != NULL; opt = opt->next) {
		[options addObject: [NSString stringWithCString: opt->text]];
	}
	[window->window showDropdownMenuWithOptions: options atLocation:
		NSMakePoint(rect.x0, rect.y1) control: control];
}

static void openstep_window_file_gadget_open(struct gui_window *gw, struct hlcache_handle *hl, struct form_control *gadget) {
	(void)gw;
	(void)hl;
	(void)gadget;
}

struct gui_window_table openstep_window_table = {
	.create = openstep_window_create,
	.destroy = openstep_window_destroy,
	.invalidate = openstep_window_invalidate,
	.get_scroll = openstep_window_get_scroll,
	.set_scroll = openstep_window_set_scroll,
	.get_dimensions = openstep_window_get_dimensions,
	.event = openstep_window_event,
	.set_title = openstep_window_set_title,
	.set_url = openstep_window_set_url,
	.set_status = openstep_window_set_status,
	.place_caret = openstep_window_place_caret,
	.set_pointer = openstep_window_set_pointer,
	.create_form_select_menu = openstep_window_create_form_select_menu,
	.file_gadget_open = openstep_window_file_gadget_open,
};
