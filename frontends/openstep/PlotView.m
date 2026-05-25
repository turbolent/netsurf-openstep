/*
 * Copyright 2011 Sven Weidauer <sven.weidauer@gmail.com>
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

#import <stdlib.h>
#import <AppKit/AppKit.h>

#import "FrameBufferRenderer.h"
#import "PlotView.h"
#import "BrowserWindowController.h"
#import "utils/errors.h"
#import "utils/log.h"
#import "netsurf/browser_window.h"
#import "netsurf/keypress.h"
#import "utils/nsurl.h"
#import "netsurf/content.h"
#import "netsurf/form.h"
#import "desktop/browser_history.h"

@implementation PlotView

-(void)awakeFromNib {
	caretRect = NSMakeRect(0, 0, 1, 0);
}

-(BOOL)resignFirstResponder {
	[self removeCaret];
	return [super resignFirstResponder];
}

-(void)setBrowser: (void*)aBrowser {
	browser = aBrowser;
}

-(void)placeCaretAtX: (int)x y: (int)y height: (int)height {
	if (showCaret) {
		[self setNeedsDisplayInRect: caretRect];
	}
	showCaret = YES;
	caretRect.origin.x = x;
	caretRect.origin.y = y;
	caretRect.size.width = 1;
	caretRect.size.height = height;
	[self setNeedsDisplayInRect: caretRect];
}

-(void)removeCaret {
	showCaret = NO;
	[self setNeedsDisplayInRect: caretRect];
}

-(void)drawRect: (NSRect)rect {
	NSSize newSize = [[self superview] frame].size;
	BOOL sizeChanged = newSize.width != lastSize.width ||
			newSize.height != lastSize.height;

	[[NSColor whiteColor] set];
	NSRectFill(rect);

	if (browser == NULL) {
		lastSize = newSize;
		return;
	}

	if (sizeChanged) {
		browser_window_schedule_reformat(browser);
	}

	openstep_framebuffer_render_browser(browser, rect, showCaret, caretRect);
	lastSize = newSize;
}

-(BOOL)isFlipped {
	return YES;
}

- (NSPoint) convertMousePoint: (NSEvent *)event {
	return [self convertPoint: [event locationInWindow] fromView: nil];
}

- (void) popUpContextMenuForEvent: (NSEvent *) event
{
	NSMenu *popupMenu;
	NSPoint point;
	struct browser_window_features cont;

	if (browser == NULL) {
		return;
	}

	popupMenu = [[NSMenu alloc] initWithTitle: @""];
	point = [self convertMousePoint: event];
	browser_window_get_features(browser, point.x, point.y, &cont);

	if (cont.object != NULL) {
		const char *cstr = nsurl_access(hlcache_handle_get_url(cont.object));
		NSString *imageURL = [NSString stringWithCString: cstr];

		[[popupMenu addItemWithTitle: @"Open image in new window"
			action: @selector(cmOpenURLInWindow:)
			keyEquivalent: @""] setRepresentedObject: imageURL];
		if (cont.link != NULL) {
			[popupMenu addItem: [NSMenuItem separatorItem]];
		}
	}
	if (cont.link != NULL) {
		NSString *target = [NSString stringWithCString:
				nsurl_access(cont.link)];

		[[popupMenu addItemWithTitle: @"Open link in new window"
			action: @selector(cmOpenURLInWindow:)
			keyEquivalent: @""] setRepresentedObject: target];
		[[popupMenu addItemWithTitle: @"Copy link"
			action: @selector(cmLinkCopy:)
			keyEquivalent: @""] setRepresentedObject: target];
	}
	if (cont.link == NULL && cont.object == NULL) {
		char *selection;

		[popupMenu addItemWithTitle: @"Back"
			action: @selector(back:) keyEquivalent: @""];
		[popupMenu addItemWithTitle: @"Forward"
			action: @selector(forward:) keyEquivalent: @""];
		[popupMenu addItemWithTitle: @"Stop"
			action: @selector(stopReloading:) keyEquivalent: @""];
		[popupMenu addItemWithTitle: @"Reload"
			action: @selector(reload:) keyEquivalent: @""];
		[popupMenu addItem: [NSMenuItem separatorItem]];
		selection = browser_window_get_selection(browser);
		if (selection != NULL) {
			if (cont.form_features == CTX_FORM_TEXT) {
				[popupMenu addItemWithTitle: @"Cut"
					action: @selector(cut:) keyEquivalent: @""];
			}
			[popupMenu addItemWithTitle: @"Copy"
				action: @selector(copy:) keyEquivalent: @""];
			free(selection);
		}
		[popupMenu addItemWithTitle: @"Paste"
			action: @selector(paste:) keyEquivalent: @""];
	}
	[NSMenu popUpContextMenu: popupMenu withEvent: event forView: self];
	[popupMenu release];
}

static browser_mouse_state openstep_mouse_flags_for_event(NSEvent *evt) {
	browser_mouse_state result = 0;
	NSUInteger flags = [evt modifierFlags];

	if (flags & NSShiftKeyMask) {
		result |= BROWSER_MOUSE_MOD_1;
	}
	if (flags & NSAlternateKeyMask) {
		result |= BROWSER_MOUSE_MOD_2;
	}
	return result;
}

-(void)scrollWheel: (NSEvent*)theEvent {
	NSPoint loc;
	int scroll;

	if (browser == NULL) {
		return;
	}
	loc = [self convertMousePoint: theEvent];
	scroll = (int)[theEvent deltaY] * -25;
	if (!browser_window_scroll_at_point(browser, loc.x, loc.y, 0, scroll)) {
		[[self nextResponder] scrollWheel: theEvent];
	}
}

- (void) mouseDown: (NSEvent *)theEvent {
	if (browser == NULL) {
		return;
	}
	[[self window] makeFirstResponder: self];
	if ([theEvent modifierFlags] & NSControlKeyMask) {
		[self popUpContextMenuForEvent: theEvent];
		return;
	}
	dragStart = [self convertMousePoint: theEvent];
	browser_window_mouse_click(browser,
		BROWSER_MOUSE_PRESS_1 | openstep_mouse_flags_for_event(theEvent),
		dragStart.x,
		dragStart.y);
}

- (void) rightMouseDown: (NSEvent *)theEvent {
	if (browser == NULL) {
		return;
	}
	[self popUpContextMenuForEvent: theEvent];
}

- (void) mouseUp: (NSEvent *)theEvent {
	NSPoint location;
	browser_mouse_state modifierFlags;

	if (browser == NULL) {
		return;
	}
	location = [self convertMousePoint: theEvent];
	modifierFlags = openstep_mouse_flags_for_event(theEvent);
	if (isDragging) {
		isDragging = NO;
		browser_window_mouse_track(browser, (browser_mouse_state)0,
			location.x, location.y);
	} else {
		modifierFlags |= BROWSER_MOUSE_CLICK_1;
		if ([theEvent clickCount] == 2) {
			modifierFlags |= BROWSER_MOUSE_DOUBLE_CLICK;
		}
		browser_window_mouse_click(browser, modifierFlags,
			location.x, location.y);
	}
}

#define squared(x) ((x)*(x))
#define MinDragDistance (5.0)

- (void) mouseDragged: (NSEvent *)theEvent {
	NSPoint location;
	browser_mouse_state modifierFlags;

	if (browser == NULL) {
		return;
	}
	location = [self convertMousePoint: theEvent];
	modifierFlags = openstep_mouse_flags_for_event(theEvent);

	if (!isDragging) {
		const CGFloat distance = squared(dragStart.x - location.x) +
			squared(dragStart.y - location.y);

		if (distance >= squared(MinDragDistance)) {
			isDragging = YES;
			browser_window_mouse_click(browser,
				BROWSER_MOUSE_DRAG_1 | modifierFlags,
				dragStart.x,
				dragStart.y);
		}
	}
	if (isDragging) {
		browser_window_mouse_track(browser,
			BROWSER_MOUSE_HOLDING_1 | BROWSER_MOUSE_DRAG_ON |
				modifierFlags,
			location.x,
			location.y);
	}
}

- (void) mouseMoved: (NSEvent *)theEvent {
	NSPoint location;

	if (browser == NULL) {
		return;
	}
	location = [self convertMousePoint: theEvent];
	browser_window_mouse_track(browser, openstep_mouse_flags_for_event(theEvent),
		location.x, location.y);
}

- (void) mouseExited: (NSEvent *) theEvent {
	[[NSCursor arrowCursor] set];
}

- (void) keyDown: (NSEvent *)theEvent {
	if (browser == NULL) {
		return;
	}
	[self interpretKeyEvents: [NSArray arrayWithObject: theEvent]];
}

- (void) insertText: (id)string {
	NSUInteger i;
	NSUInteger length;

	if (browser == NULL) {
		return;
	}
	length = [string length];
	for (i = 0; i < length; i++) {
		unichar ch = [string characterAtIndex: i];
		bool handled = browser_window_key_press(browser, ch);

		if (!handled) {
			if (ch == ' ') {
				[self scrollPageDown: self];
			}
			break;
		}
	}
}

- (void) moveLeft: (id)sender {
	if (browser == NULL) {
		return;
	}
	if (browser_window_key_press(browser, NS_KEY_LEFT)) {
		return;
	}
	[self scrollHorizontal: -25.0];
}

- (void) moveRight: (id)sender {
	if (browser == NULL) {
		return;
	}
	if (browser_window_key_press(browser, NS_KEY_RIGHT)) {
		return;
	}
	[self scrollHorizontal: 25.0];
}

- (void) moveUp: (id)sender {
	if (browser == NULL) {
		return;
	}
	if (browser_window_key_press(browser, NS_KEY_UP)) {
		return;
	}
	[self scrollVertical: -([[self enclosingScrollView] lineScroll])];
}

- (void) moveDown: (id)sender {
	if (browser == NULL) {
		return;
	}
	if (browser_window_key_press(browser, NS_KEY_DOWN)) {
		return;
	}
	[self scrollVertical: [[self enclosingScrollView] lineScroll]];
}

- (void) deleteBackward: (id)sender {
	if (browser == NULL) {
		return;
	}
	if (!browser_window_key_press(browser, NS_KEY_DELETE_LEFT)) {
		[NSApp sendAction: @selector(goBack:) to: nil from: self];
	}
}

- (void) deleteForward: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_DELETE_RIGHT);
}

- (void) cancelOperation: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_ESCAPE);
}

- (CGFloat) pageScroll {
	return NSHeight([[self superview] frame]);
}

- (void) scrollPageUp: (id)sender {
	if (browser == NULL) {
		return;
	}
	if (browser_window_key_press(browser, NS_KEY_PAGE_UP)) {
		return;
	}
	[self scrollVertical: -[self pageScroll]];
}

- (void) scrollPageDown: (id)sender {
	if (browser == NULL) {
		return;
	}
	if (browser_window_key_press(browser, NS_KEY_PAGE_DOWN)) {
		return;
	}
	[self scrollVertical: [self pageScroll]];
}

- (void) insertTab: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_TAB);
}

- (void) insertBacktab: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_SHIFT_TAB);
}

- (void) moveToBeginningOfLine: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_LINE_START);
}

- (void) moveToEndOfLine: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_LINE_END);
}

- (void) moveToBeginningOfDocument: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_TEXT_START);
}

- (void) scrollToBeginningOfDocument: (id)sender {
	NSPoint origin = [self visibleRect].origin;
	origin.y = 0;
	[self scrollPoint: origin];
}

- (void) moveToEndOfDocument: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_TEXT_END);
}

- (void) scrollToEndOfDocument: (id)sender {
	NSPoint origin = [self visibleRect].origin;
	origin.y = NSHeight([self frame]);
	[self scrollPoint: origin];
}

- (void) insertNewline: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_NL);
}

- (void) selectAll: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_SELECT_ALL);
}

- (void) copy: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_COPY_SELECTION);
}

- (void) cut: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_CUT_SELECTION);
}

- (void) paste: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_key_press(browser, NS_KEY_PASTE);
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

- (void) adjustFrame {
	if (browser) {
		browser_window_schedule_reformat(browser);
	}
}

- (void) scrollHorizontal: (CGFloat) amount {
	NSPoint currentPoint = [self visibleRect].origin;
	currentPoint.x += amount;
	[self scrollPoint: currentPoint];
}

- (void) scrollVertical: (CGFloat) amount {
	NSPoint currentPoint = [self visibleRect].origin;
	currentPoint.y += amount;
	[self scrollPoint: currentPoint];
}

-(void)back: (id)sender {
	if (browser != NULL && browser_window_history_back_available(browser)) {
		browser_window_history_back(browser, false);
	}
}

-(void)forward: (id)sender {
	if (browser != NULL && browser_window_history_forward_available(browser)) {
		browser_window_history_forward(browser, false);
	}
}

-(void)stopReloading: (id)sender {
	if (browser != NULL && browser_window_stop_available(browser)) {
		browser_window_stop(browser);
	}
}

-(void)reload: (id)sender {
	if (browser != NULL && browser_window_reload_available(browser)) {
		browser_window_reload(browser, true);
	}
}

- (void) cmOpenURLInWindow: (id)sender {
	struct nsurl *url;
	nserror error;

	if (browser == NULL) {
		return;
	}
	error = nsurl_create([[sender representedObject] cString], &url);
	if (error == NSERROR_OK) {
		error = browser_window_create(BW_CREATE_HISTORY | BW_CREATE_CLONE,
			url, NULL, browser, NULL);
		nsurl_unref(url);
	}
}

- (void) cmLinkCopy: (id)sender {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes: [NSArray arrayWithObject: NSStringPboardType] owner: nil];
	[pb setString: [sender representedObject] forType: NSStringPboardType];
}

-(void)showDropdownMenuWithOptions: (NSArray*)options atLocation: (NSPoint)location control: (struct form_control*)control {
	NSMenu *popupMenu = [[NSMenu alloc] initWithTitle: @""];
	NSMenuItem *opt;
	NSInteger i;

	for (i = 0; i < [options count]; i++) {
		opt = [popupMenu addItemWithTitle: [options objectAtIndex: i]
			action: @selector(didPickDropdownOption:)
			keyEquivalent: @""];
		[opt setTag: i];
		[opt setRepresentedObject: [NSValue valueWithPointer: control]];
	}
	[NSMenu popUpContextMenu: popupMenu withEvent: nil forView: self];
	[popupMenu release];
}

-(void)didPickDropdownOption: (id)sender {
	NSValue *controlPointer = [sender representedObject];
	struct form_control *control =
		(struct form_control*)[controlPointer pointerValue];

	if (form_select_process_selection(control, [sender tag]) != NSERROR_OK) {
		NSLOG(netsurf, WARNING, "Failed to process form selection");
	}
}

-(void)resetZoom: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_set_scale(browser, 1.0, true);
}

-(void)zoomIn: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_set_scale(browser, 0.05, false);
}

-(void)zoomOut: (id)sender {
	if (browser == NULL) {
		return;
	}
	browser_window_set_scale(browser, -0.05, false);
}

@end
