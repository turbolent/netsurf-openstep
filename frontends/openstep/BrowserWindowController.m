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

#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <string.h>
#import "BrowserWindowController.h"
#import "PlotView.h"
#import "netsurf/browser_window.h"
#import "netsurf/keypress.h"
#import "utils/log.h"
#import "utils/nsurl.h"
#import "desktop/browser_history.h"
#import "netsurf/mouse.h"

#define OPENSTEP_TOOLBAR_MARGIN 6
#define OPENSTEP_TOOLBAR_BUTTON_SIZE 40
#define OPENSTEP_TOOLBAR_BUTTON_GAP 4
#define OPENSTEP_TOOLBAR_URL_GAP 8

// Everything above the browser. Used to calculate the browser view height.
#define TOP_CONTENT_HEIGHT \
	(OPENSTEP_TOOLBAR_BUTTON_SIZE + (OPENSTEP_TOOLBAR_MARGIN * 2))
static id pendingBrowserTarget;

static NSImage *openstep_toolbar_image(NSString *name)
{
	NSImage *image = [NSImage imageNamed: name];
	NSString *path;

	if (image != nil) {
		return [image retain];
	}

	path = [[NSBundle mainBundle] pathForResource: name ofType: @"tiff"];
	if (path == nil) {
		return nil;
	}

	return [[NSImage alloc] initWithContentsOfFile: path];
}

static void openstep_configure_image_button(NSButton *button, NSImage *image)
{
	[button setTitle: @""];
	if (image != nil) {
		[button setImage: image];
	}
}

static void openstep_configure_progress_field(NSTextField *field,
		NSColor *color)
{
	[field setStringValue: @""];
	[field setEditable: NO];
	[field setSelectable: NO];
	[field setBezeled: NO];
	[field setDrawsBackground: YES];
	[field setBackgroundColor: color];
}

@interface BrowserWindowController (Private)
-(NSString*)currentTitle;
-(void)updateNavigationButtons;
-(void)showLoadingProgress;
-(void)advanceLoadingProgress;
-(void)completeLoadingProgress;
-(void)hideLoadingProgress;
-(void)updateProgressBar;
@end

@implementation BrowserWindowController

-(id)initWithBrowser: (struct browser_window*)aBrowser {
	if ((self = [super init])) {
		browser = aBrowser;
		openstepScale = 1.0f;
		backImage = openstep_toolbar_image(@"Left");
		forwardImage = openstep_toolbar_image(@"Right");
		reloadImage = openstep_toolbar_image(@"Reload");
		stopImage = openstep_toolbar_image(@"Stop");
		openstepProgress = 0.0f;
		lastRequestedPointer = 999;
		isClosing = NO;
	}
	return self;
}

-(void)dealloc {
	[backImage release];
	[forwardImage release];
	[reloadImage release];
	[stopImage release];
	[window release];
	[super dealloc];
}

-(void)loadWindow {
	NSRect frame = NSMakeRect(80, 80, 760, 520);
	NSWindow *newWindow;
	NSView *content;
	NSRect bounds;
	NSRect progressFrame;
	NSButton *button;

	if (window != nil) {
		return;
	}

	newWindow = [[NSWindow alloc] initWithContentRect: frame
		styleMask: NSTitledWindowMask | NSClosableWindowMask |
			NSMiniaturizableWindowMask | NSResizableWindowMask
		backing: NSBackingStoreBuffered
		defer: NO];
	window = newWindow;
	[window setTitle: @"NetSurf"];
	[window setReleasedWhenClosed: NO];
	[window setDelegate: self];

	content = [window contentView];
	bounds = [content bounds];

	button = [[NSButton alloc] initWithFrame: NSMakeRect(
		OPENSTEP_TOOLBAR_MARGIN,
		bounds.size.height - OPENSTEP_TOOLBAR_MARGIN -
			OPENSTEP_TOOLBAR_BUTTON_SIZE,
		OPENSTEP_TOOLBAR_BUTTON_SIZE,
		OPENSTEP_TOOLBAR_BUTTON_SIZE)];
	openstep_configure_image_button(button, backImage);
	[button setTarget: self];
	[button setAction: @selector(back:)];
	[button setAutoresizingMask: NSViewMinYMargin | NSViewMaxXMargin];
	[content addSubview: button];
	backButton = button;
	[button release];

	button = [[NSButton alloc] initWithFrame: NSMakeRect(
		OPENSTEP_TOOLBAR_MARGIN + OPENSTEP_TOOLBAR_BUTTON_SIZE +
			OPENSTEP_TOOLBAR_BUTTON_GAP,
		bounds.size.height - OPENSTEP_TOOLBAR_MARGIN -
			OPENSTEP_TOOLBAR_BUTTON_SIZE,
		OPENSTEP_TOOLBAR_BUTTON_SIZE,
		OPENSTEP_TOOLBAR_BUTTON_SIZE)];
	openstep_configure_image_button(button, forwardImage);
	[button setTarget: self];
	[button setAction: @selector(forward:)];
	[button setAutoresizingMask: NSViewMinYMargin | NSViewMaxXMargin];
	[content addSubview: button];
	forwardButton = button;
	[button release];

	button = [[NSButton alloc] initWithFrame: NSMakeRect(
		bounds.size.width - OPENSTEP_TOOLBAR_MARGIN -
			OPENSTEP_TOOLBAR_BUTTON_SIZE,
		bounds.size.height - OPENSTEP_TOOLBAR_MARGIN -
			OPENSTEP_TOOLBAR_BUTTON_SIZE,
		OPENSTEP_TOOLBAR_BUTTON_SIZE,
		OPENSTEP_TOOLBAR_BUTTON_SIZE)];
	openstep_configure_image_button(button, reloadImage);
	[button setTarget: self];
	[button setAction: @selector(stopOrRefresh:)];
	[button setAutoresizingMask: NSViewMinYMargin | NSViewMinXMargin];
	[content addSubview: button];
	refreshButton = button;
	[button release];

	urlBar = [[NSTextField alloc] initWithFrame: NSMakeRect(
		OPENSTEP_TOOLBAR_MARGIN +
			(OPENSTEP_TOOLBAR_BUTTON_SIZE * 2) +
			OPENSTEP_TOOLBAR_BUTTON_GAP +
			OPENSTEP_TOOLBAR_URL_GAP,
		bounds.size.height - OPENSTEP_TOOLBAR_MARGIN -
			OPENSTEP_TOOLBAR_BUTTON_SIZE + 13,
		bounds.size.width -
			(OPENSTEP_TOOLBAR_MARGIN * 2) -
			(OPENSTEP_TOOLBAR_BUTTON_SIZE * 3) -
			OPENSTEP_TOOLBAR_BUTTON_GAP -
			(OPENSTEP_TOOLBAR_URL_GAP * 2),
		22)];
	[urlBar setTarget: self];
	[urlBar setAction: @selector(enterUrl:)];
	[urlBar setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview: urlBar];
	[urlBar release];

	progressFrame = [urlBar frame];
	progressFrame.origin.y -= 7;
	progressFrame.size.height = 0;
	progressTrack = [[NSTextField alloc] initWithFrame: progressFrame];
	openstep_configure_progress_field(progressTrack, [NSColor lightGrayColor]);
	[progressTrack setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview: progressTrack];
	[progressTrack release];

	progressFill = [[NSTextField alloc] initWithFrame: progressFrame];
	openstep_configure_progress_field(progressFill, [NSColor darkGrayColor]);
	[progressFill setAutoresizingMask: NSViewMinYMargin | NSViewMaxXMargin];
	[content addSubview: progressFill];
	[progressFill release];

	scrollView = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, bounds.size.width, bounds.size.height - TOP_CONTENT_HEIGHT)];
	[scrollView setHasVerticalScroller: YES];
	[scrollView setHasHorizontalScroller: YES];
	[scrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	plotView = [[PlotView alloc] initWithFrame: [[scrollView contentView] bounds]];
	[plotView setBrowser: browser];
	[scrollView setDocumentView: plotView];
	[content addSubview: scrollView];
	[plotView release];
	[scrollView release];

	[self awakeFromNib];
	[self updateNavigationButtons];
	[window makeKeyAndOrderFront: self];
}

-(void)awakeFromNib {
}

-(void)attachBrowser: (struct browser_window*)aBrowser {
	[plotView setBrowser: aBrowser];
	browser = aBrowser;
	[self setNavigationUrl: [self visibleUrl]];
	[window setTitle: [self currentTitle]];
	[self updateNavigationButtons];
	[plotView setNeedsDisplay: YES];
}

-(void)windowWillClose: (NSNotification*)aNotification {
	isClosing = YES;
	if (browser != NULL) {
		browser_window_destroy(browser);
	}
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

-(void)close: (id)sender {
	if (browser != NULL) {
		browser_window_destroy(browser);
	} else {
		[window close];
	}
}
-(void)netsurfWindowDestroy {
	browser = NULL;
	[plotView setBrowser: NULL];
	if (isClosing) {
		return;
	}
	[window close];
}

-(struct browser_window *)browser {
	return browser;
}

-(void)back: (id)sender {
	if (browser == NULL) {
		return;
	}
	[plotView back: sender];
	[self updateNavigationButtons];
}

-(void)forward: (id)sender {
	if (browser == NULL) {
		return;
	}
	[plotView forward: sender];
	[self updateNavigationButtons];
}

-(void)stopOrRefresh: (id)sender {
	int tag = [sender tag];
	if (browser == NULL) {
		return;
	}
	if (tag == 1) {
		[plotView stopReloading: sender];
	} else {
		[plotView reload: sender];
	}
}

-(void)enterUrl: (id)sender {
	NSString *string = [sender stringValue];
	[self openUrlString: string];
}

-(NSSize)getBrowserSize {
	return [[plotView superview] frame].size;
}
-(NSPoint)getBrowserScroll {
	return [plotView visibleRect].origin;
}
-(void)setBrowserScroll: (NSPoint)scroll {
	[plotView scrollPoint: scroll];
}
-(void)invalidateBrowser {
	[plotView setNeedsDisplay: YES];
}
-(void)invalidateBrowser: (NSRect)rect {
	[plotView setNeedsDisplayInRect: rect];
}
-(void)updateBrowserExtent {
	int width, height;
	if (browser == NULL) {
		return;
	}
	browser_window_get_extents(browser, true, &width, &height);
	[plotView setFrame: NSMakeRect(0, 0, width, height)];
}
-(void)placeCaretAtX: (int)x y: (int)y height: (int)height {
	[plotView placeCaretAtX: x y: y height: height];
}
-(void)removeCaret {
	[plotView removeCaret];
}
-(void)setPointerToShape: (enum gui_pointer_shape)shape {
	if (shape == lastRequestedPointer)
		return;
	lastRequestedPointer = shape;
	if (shape == GUI_POINTER_CARET) {
		[[NSCursor IBeamCursor] set];
	} else {
		[[NSCursor arrowCursor] set];
	}
}
-(void)newContent {
	[[NSCursor arrowCursor] set];
	[self updateNavigationButtons];
}
-(void)startThrobber {
	openstep_configure_image_button(refreshButton, stopImage);
	[refreshButton setTag: 1];
	[self showLoadingProgress];
	[[NSCursor arrowCursor] set];
}
-(void)stopThrobber {
	openstep_configure_image_button(refreshButton, reloadImage);
	[refreshButton setTag: 0];
	[self completeLoadingProgress];
	[self updateNavigationButtons];
	[[NSCursor arrowCursor] set];
}
-(void)setNavigationUrl: (NSString*)urlString {
	[urlBar setStringValue: urlString];
	[self updateNavigationButtons];
}
-(void)setStatusText: (NSString*)statusText {
	(void)statusText;
	[self advanceLoadingProgress];
}
-(void)setTitle: (NSString*)title {
	[window setTitle: title];
}

-(void)zoomIn: (id)sender {
	NSSize size;
	nserror error;

	if (browser == NULL) {
		return;
	}
	openstepScale += 0.10f;
	if (openstepScale > 10.0f) {
		openstepScale = 10.0f;
	}
	error = browser_window_set_scale(browser, openstepScale, true);
	size = [self getBrowserSize];
	browser_window_reformat(browser, false, size.width, size.height);
	[self updateBrowserExtent];
	(void)error;
	[plotView setNeedsDisplay: YES];
}

-(void)zoomOut: (id)sender {
	NSSize size;
	nserror error;

	if (browser == NULL) {
		return;
	}
	openstepScale -= 0.10f;
	if (openstepScale < 0.10f) {
		openstepScale = 0.10f;
	}
	error = browser_window_set_scale(browser, openstepScale, true);
	size = [self getBrowserSize];
	browser_window_reformat(browser, false, size.width, size.height);
	[self updateBrowserExtent];
	(void)error;
	[plotView setNeedsDisplay: YES];
}

-(void)resetZoom: (id)sender {
	NSSize size;
	nserror error;

	if (browser == NULL) {
		return;
	}
	openstepScale = 1.0f;
	error = browser_window_set_scale(browser, openstepScale, true);
	size = [self getBrowserSize];
	browser_window_reformat(browser, false, size.width, size.height);
	[self updateBrowserExtent];
	(void)error;
	[plotView setNeedsDisplay: YES];
}

-(void)reload: (id)sender {
	[plotView reload: sender];
}

-(void)stopLoading: (id)sender {
	[plotView stopReloading: sender];
}


-(NSString*)visibleUrl {
	struct nsurl *url;

	if (browser == NULL) {
		return @"about:blank";
	}
	url = browser_window_access_url(browser);
	if (url == NULL) {
		return @"about:blank";
	}
	return [NSString stringWithCString: nsurl_access(url)];
}

-(void)openUrlString: (NSString*)aUrlString {
	nserror error;
	struct nsurl *url;
	NSString *targetUrl = aUrlString;

	if ([targetUrl rangeOfString: @":"].location == NSNotFound) {
		targetUrl = [NSString stringWithFormat: @"http://%@", targetUrl];
	}
	if (browser == NULL) {
		error = nsurl_create([targetUrl cString], &url);
		if (error != NSERROR_OK) {
			NSLOG(netsurf, WARNING, "Failed to create URL for %s",
				[targetUrl cString]);
			[urlBar setStringValue: aUrlString];
			return;
		}
		[BrowserWindowController setPendingBrowserTarget: self];
		error = browser_window_create(BW_CREATE_HISTORY, url, NULL, NULL, NULL);
		[BrowserWindowController setPendingBrowserTarget: nil];
		nsurl_unref(url);
		if (error != NSERROR_OK) {
			NSLOG(netsurf, WARNING, "Failed to create browser window");
			[urlBar setStringValue: aUrlString];
		}
		return;
	}
	error = nsurl_create([targetUrl cString], &url);
	if (error != NSERROR_OK) {
		NSLOG(netsurf, WARNING, "Failed to create URL for %s",
			[targetUrl cString]);
		return;
	}
	error = browser_window_navigate(browser, url, NULL, BW_NAVIGATE_HISTORY, NULL, NULL,
		NULL);
	if (error != NSERROR_OK) {
		NSLOG(netsurf, WARNING, "Failed to navigate browser window");
	}
	nsurl_unref(url);
}

-(void)updateNavigationButtons {
	if (browser == NULL) {
		[backButton setEnabled: NO];
		[forwardButton setEnabled: NO];
		return;
	}

	[backButton setEnabled: browser_window_back_available(browser) ? YES : NO];
	[forwardButton setEnabled:
		browser_window_forward_available(browser) ? YES : NO];
}

-(void)showLoadingProgress {
	openstepProgress = 0.08f;
	[self updateProgressBar];
}

-(void)advanceLoadingProgress {
	if ([refreshButton tag] != 1) {
		return;
	}
	if (openstepProgress < 0.15f) {
		openstepProgress = 0.15f;
	} else if (openstepProgress < 0.90f) {
		openstepProgress += 0.14f;
		if (openstepProgress > 0.90f) {
			openstepProgress = 0.90f;
		}
	}
	[self updateProgressBar];
}

-(void)completeLoadingProgress {
	openstepProgress = 1.0f;
	[self updateProgressBar];
	[self hideLoadingProgress];
}

-(void)hideLoadingProgress {
	if ([refreshButton tag] == 1) {
		return;
	}
	openstepProgress = 0.0f;
	[self updateProgressBar];
}

-(void)updateProgressBar {
	NSRect oldTrackFrame;
	NSRect oldFillFrame;
	NSRect trackFrame;
	NSRect fillFrame;
	id contentView;

	if (progressTrack == nil || progressFill == nil || urlBar == nil) {
		return;
	}

	oldTrackFrame = [progressTrack frame];
	oldFillFrame = [progressFill frame];
	contentView = [progressTrack superview];

	trackFrame = [urlBar frame];
	trackFrame.origin.y -= 7;
	trackFrame.size.height = (openstepProgress > 0.0f) ? 4 : 0;
	[progressTrack setFrame: trackFrame];

	fillFrame = trackFrame;
	fillFrame.size.width = trackFrame.size.width * openstepProgress;
	[progressFill setFrame: fillFrame];
	if (contentView != nil) {
		[contentView setNeedsDisplayInRect: oldTrackFrame];
		[contentView setNeedsDisplayInRect: oldFillFrame];
		[contentView setNeedsDisplayInRect: trackFrame];
		[contentView setNeedsDisplayInRect: fillFrame];
	}
	[progressTrack setNeedsDisplay: YES];
	[progressFill setNeedsDisplay: YES];
}

-(void)copy: (id)sender {
	id firstResponder;
	char *selection;
	NSPasteboard *pasteboard;
	NSString *string;

	if (browser == NULL) {
		return;
	}

	selection = browser_window_get_selection(browser);
	if (selection != NULL && selection[0] != '\0') {
		string = [NSString stringWithCString: selection];
		free(selection);
		if (string == nil) {
			return;
		}

		pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard declareTypes: [NSArray arrayWithObject: NSStringPboardType]
			owner: nil];
		[pasteboard setString: string forType: NSStringPboardType];
		return;
	}
	if (selection != NULL) {
		free(selection);
	}

	if (browser_window_key_press(browser, NS_KEY_COPY_SELECTION)) {
		return;
	}

	firstResponder = [window firstResponder];
	if (firstResponder != plotView &&
			[firstResponder respondsToSelector: @selector(copy:)]) {
		[firstResponder copy: sender];
	}
}

-(NSString*)currentTitle {
	const char *title;

	if (browser == NULL) {
		return @"NetSurf";
	}
	title = browser_window_get_title(browser);
	if (title == NULL) {
		title = "";
	}
	return [NSString stringWithCString: title];
}

-(void)showDropdownMenuWithOptions: (NSArray*)options atLocation: (NSPoint)location control: (struct form_control*)control {
	[plotView showDropdownMenuWithOptions: options atLocation: location
		control: control];
}

+(id)pendingBrowserTarget {
	return pendingBrowserTarget;
}

+(void)setPendingBrowserTarget: (id)target {
	pendingBrowserTarget = target;
}

@end
