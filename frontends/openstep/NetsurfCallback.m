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
#import "NetsurfCallback.h"

static NSMutableArray *callbackList;

@implementation NetsurfCallback

+(void)initialize {
	callbackList = [[NSMutableArray alloc] init];
}

+(id)newOrScheduledWithFunctionPointer: (void (*)(void *p))aCallback parameter: (void*)p {
	NetsurfCallback *ret;
	unsigned int i;

	for (i = 0; i < [callbackList count]; i++) {
		ret = [callbackList objectAtIndex: i];
		if (ret->callback == aCallback && ret->parameter == p) {
			return ret;
		}
	}
	ret = [NetsurfCallback new];
	ret->callback = aCallback;
	ret->parameter = p;
	return ret;
}

+(void)removeScheduledWithFunctionPointer: (void (*)(void *p))aCallback parameter: (void*)p {
	NetsurfCallback *ret;
	unsigned int i;

	for (i = 0; i < [callbackList count]; i++) {
		ret = [callbackList objectAtIndex: i];
		if (ret->callback == aCallback && ret->parameter == p) {
			[ret cancel];
			return;
		}
	}
}

-(void)perform {
	[timer invalidate];
	[timer release];
	timer = nil;
	[self retain];
	[callbackList removeObject: self];
	callback(parameter);
	[self release];
}

-(void)scheduleAfterMillis: (int)ms {
	if (![callbackList containsObject: self]) {
		[callbackList addObject: self];
		[self release];
	}
	double interval = ((double)ms / 1000.0);
	if (interval < 0.01) {
		interval = 0.01;
	}
	[timer invalidate];
	[timer release];
	timer = [[NSTimer scheduledTimerWithTimeInterval: interval
		target: self selector: @selector(perform) userInfo: nil repeats: NO]
		retain];
}

-(void)cancel {
	[timer invalidate];
	[timer release];
	timer = nil;
	[callbackList removeObject: self];
}

-(void)dealloc {
	[timer invalidate];
	[timer release];
	[super dealloc];
}

@end
