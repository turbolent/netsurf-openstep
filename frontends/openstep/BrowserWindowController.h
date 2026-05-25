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
#import "netsurf/netsurf.h"
#import "netsurf/mouse.h"

struct browser_window;
struct form_control;

@interface BrowserWindowController : NSObject<NSTextFieldDelegate> {
	NSWindow *window;
	id backButton;
	id forwardButton;
	id urlBar;
	id progressTrack;
	id progressFill;
	id refreshButton;
	id caretView;
	enum gui_pointer_shape lastRequestedPointer;
	BOOL isClosing;
	id scrollView;
	id plotView;
	struct browser_window *browser;
	float openstepScale;
	id backImage;
	id forwardImage;
	id reloadImage;
	id stopImage;
	float openstepProgress;
}

-(id)initWithBrowser: (struct browser_window*)aBrowser;
-(void)loadWindow;
-(void)back: (id)sender;
-(void)forward: (id)sender;
-(void)stopOrRefresh: (id)sender;
-(NSString*)visibleUrl;
-(void)openUrlString: (NSString*)aUrlString;
-(void)attachBrowser: (struct browser_window*)aBrowser;
-(void)close: (id)sender;

// Browser control
-(struct browser_window *)browser;
-(NSSize)getBrowserSize;
-(NSPoint)getBrowserScroll;
-(void)setBrowserScroll: (NSPoint)scroll;
-(void)invalidateBrowser;
-(void)invalidateBrowser: (NSRect)rect;
-(void)updateBrowserExtent;
-(void)placeCaretAtX: (int)x y: (int)y height: (int)height;
-(void)removeCaret;
-(void)setPointerToShape: (enum gui_pointer_shape)shape;
-(void)newContent;
-(void)setNavigationUrl: (NSString*)urlString;
-(void)setStatusText: (NSString*)statusText;
-(void)setTitle: (NSString*)title;
-(void)netsurfWindowDestroy;

-(void)startThrobber;
-(void)stopThrobber;
-(void)zoomIn: (id)sender;
-(void)zoomOut: (id)sender;
-(void)resetZoom: (id)sender;
-(void)copy: (id)sender;
-(void)reload: (id)sender;
-(void)stopLoading: (id)sender;

-(void)showDropdownMenuWithOptions: (NSArray*)options atLocation: (NSPoint)location control: (struct form_control*)control;


+(id)pendingBrowserTarget;
+(void)setPendingBrowserTarget: (id)target;
@end
