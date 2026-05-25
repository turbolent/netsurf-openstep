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

#import "FrameBufferRenderer.h"

#include <stdlib.h>

#import <libnsfb.h>
#import <libnsfb_plot.h>
#import <AppKit/NSGraphics.h>

#import "netsurf/browser_window.h"
#import "netsurf/plotters.h"
#import "framebuffer/framebuffer.h"

static nsfb_t *openstep_fb_surface;
static unsigned char *openstep_fb_upload;
static int openstep_fb_upload_size;
static int openstep_fb_width;
static int openstep_fb_height;

static BOOL openstep_framebuffer_ensure_surface(NSRect rect)
{
	int width = (int)NSMaxX(rect);
	int height = (int)NSMaxY(rect);

	if (width < 1) {
		width = 1;
	}
	if (height < 1) {
		height = 1;
	}

	if (openstep_fb_surface != NULL &&
			width == openstep_fb_width &&
			height == openstep_fb_height) {
		return YES;
	}

	if (openstep_fb_surface != NULL) {
		nsfb_free(openstep_fb_surface);
		openstep_fb_surface = NULL;
	}
	if (openstep_fb_upload != NULL) {
		free(openstep_fb_upload);
		openstep_fb_upload = NULL;
		openstep_fb_upload_size = 0;
	}

	openstep_fb_surface = nsfb_new(NSFB_SURFACE_RAM);
	if (openstep_fb_surface == NULL) {
		return NO;
	}

	if (nsfb_set_geometry(openstep_fb_surface,
			width,
			height,
			NSFB_FMT_XRGB8888) == -1) {
		nsfb_free(openstep_fb_surface);
		openstep_fb_surface = NULL;
		return NO;
	}

	if (nsfb_init(openstep_fb_surface) == -1) {
		nsfb_free(openstep_fb_surface);
		openstep_fb_surface = NULL;
		return NO;
	}

	openstep_fb_width = width;
	openstep_fb_height = height;
	return YES;
}

static BOOL openstep_framebuffer_ensure_upload_buffer(void)
{
	int size = openstep_fb_width * openstep_fb_height * 4;
	unsigned char *upload;

	if (openstep_fb_upload != NULL && size == openstep_fb_upload_size) {
		return YES;
	}

	upload = realloc(openstep_fb_upload, size);
	if (upload == NULL) {
		free(openstep_fb_upload);
		openstep_fb_upload = NULL;
		openstep_fb_upload_size = 0;
		return NO;
	}

	openstep_fb_upload = upload;
	openstep_fb_upload_size = size;
	return YES;
}

static void openstep_framebuffer_repack_xrgb_to_rgba(unsigned char *src,
		int srcStride)
{
	int x;
	int y;
	unsigned char *dst;

	for (y = 0; y < openstep_fb_height; y++) {
		unsigned char *srcRow = src + y * srcStride;
		unsigned char *dstRow = openstep_fb_upload +
				y * openstep_fb_width * 4;

		for (x = 0; x < openstep_fb_width; x++) {
			dst = dstRow + x * 4;
			dst[0] = srcRow[x * 4 + 2];
			dst[1] = srcRow[x * 4 + 1];
			dst[2] = srcRow[x * 4 + 0];
			dst[3] = 0xff;
		}
	}
}

static unsigned char openstep_framebuffer_gamma_compensate(unsigned char v)
{
	unsigned int c = v;

	return (unsigned char)(((c * c + 127) / 255 + c) / 2);
}

static void openstep_framebuffer_apply_gamma_compensation(void)
{
	int x;
	int y;

	for (y = 0; y < openstep_fb_height; y++) {
		unsigned char *row = openstep_fb_upload +
				y * openstep_fb_width * 4;

		for (x = 0; x < openstep_fb_width; x++) {
			unsigned char *dst = row + x * 4;

			dst[0] = openstep_framebuffer_gamma_compensate(dst[0]);
			dst[1] = openstep_framebuffer_gamma_compensate(dst[1]);
			dst[2] = openstep_framebuffer_gamma_compensate(dst[2]);
		}
	}
}

BOOL openstep_framebuffer_render_browser(struct browser_window *browser,
		NSRect rect,
		BOOL showCaret,
		NSRect caretRect)
{
	struct redraw_context ctx;
	struct rect clip;
	struct plot_style_s clear_style;
	nsfb_t *previous;
	unsigned char *buffer;
	int stride;
	const unsigned char *planes[5];

	if (browser == NULL || !openstep_framebuffer_ensure_surface(rect)) {
		return NO;
	}

	ctx.interactive = true;
	ctx.background_images = true;
	ctx.plot = &fb_plotters;

	clip.x0 = NSMinX(rect);
	clip.y0 = NSMinY(rect);
	clip.x1 = NSMaxX(rect);
	clip.y1 = NSMaxY(rect);

	previous = framebuffer_set_surface(openstep_fb_surface);
	clear_style.stroke_type = PLOT_OP_TYPE_NONE;
	clear_style.fill_type = PLOT_OP_TYPE_SOLID;
	clear_style.fill_colour = 0x00ffffff;
	fb_plotters.rectangle(&ctx, &clip, &clear_style);
	browser_window_redraw(browser, 0, 0, &clip, &ctx);

	if (showCaret) {
		nsfb_bbox_t caret;
		caret.x0 = caretRect.origin.x;
		caret.y0 = caretRect.origin.y;
		caret.x1 = caret.x0 + caretRect.size.width;
		caret.y1 = caret.y0 + caretRect.size.height;
		nsfb_plot_rectangle_fill(openstep_fb_surface,
				&caret,
				0x00000000);
	}

	framebuffer_set_surface(previous);

	buffer = NULL;
	stride = 0;
	if (nsfb_get_buffer(openstep_fb_surface, &buffer, &stride) == -1 ||
			buffer == NULL || stride <= 0) {
		return NO;
	}
	if (!openstep_framebuffer_ensure_upload_buffer()) {
		return NO;
	}
	openstep_framebuffer_repack_xrgb_to_rgba(buffer, stride);
	openstep_framebuffer_apply_gamma_compensation();

	planes[0] = openstep_fb_upload;
	planes[1] = NULL;
	planes[2] = NULL;
	planes[3] = NULL;
	planes[4] = NULL;
	NSDrawBitmap(NSMakeRect(0, 0, openstep_fb_width, openstep_fb_height),
			openstep_fb_width,
			openstep_fb_height,
			8,
			4,
			32,
			openstep_fb_width * 4,
			NO,
			YES,
			NSDeviceRGBColorSpace,
			planes);
	return YES;
}
