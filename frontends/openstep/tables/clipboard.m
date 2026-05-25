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
#import "netsurf/clipboard.h"

/***********************/
/****** Clipboard ******/
/***********************/

// Put content of clipboard into buffer up to a maximum length
static void openstep_clipboard_get(char **buffer, size_t *length) {
	NSString *pb = [[NSPasteboard generalPasteboard] stringForType: NSStringPboardType];
	char *cstring = "";
	int len = 0;
	if (pb) {
		cstring = [pb cString];
		len = [pb cStringLength];
	}
	*length = len;
	*buffer = malloc(len + 1);
	strncpy(*buffer, cstring, len);
	(*buffer)[len] = '\0';
}

// Save the provided clipboard for later retreival above
static void openstep_clipboard_set(const char *buffer, size_t length, nsclipboard_styles styles[], int n_styles) {
	NSString *pb = [NSString stringWithCString: buffer length: length];
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes: [NSArray arrayWithObject: NSStringPboardType]
		owner: nil];
	[pasteboard setString: pb forType: NSStringPboardType];
}

struct gui_clipboard_table openstep_clipboard_table = {
	.get = openstep_clipboard_get,
	.set = openstep_clipboard_set
};
