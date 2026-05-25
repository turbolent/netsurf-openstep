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

#import "netsurf/netsurf.h"
#import "netsurf/misc.h"
#import "NetsurfCallback.h"

/*******************/
/****** Misc *******/
/*******************/

// Schedule a callback to be run after t ms, or removed if ngtv, func and param.
static nserror openstep_misc_schedule(int t, void (*callback)(void *p), void *cbctx) {
	if (t < 0) {
		[NetsurfCallback removeScheduledWithFunctionPointer: callback
			parameter: cbctx];
		return NSERROR_OK;
	} else {
		NetsurfCallback *nsCallback = [NetsurfCallback newOrScheduledWithFunctionPointer:
			callback parameter: cbctx];
		[nsCallback scheduleAfterMillis: t];
		return NSERROR_OK;
	}
}

struct gui_misc_table openstep_misc_table = {
	.schedule = openstep_misc_schedule
};
