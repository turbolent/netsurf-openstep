/*
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

#ifndef NETSURF_OPENSTEP_FRAMEBUFFER_RENDERER_H
#define NETSURF_OPENSTEP_FRAMEBUFFER_RENDERER_H

#import <AppKit/AppKit.h>

struct browser_window;

BOOL openstep_framebuffer_render_browser(struct browser_window *browser,
		NSRect rect,
		BOOL showCaret,
		NSRect caretRect);

#endif
