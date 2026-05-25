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
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "utils/url.h"
#import "netsurf/fetch.h"
#import "utils/nsurl.h"

/*******************/
/****** Fetch ******/
/*******************/

// Return the MIME type of the specified file. Returned string can be inval on next req.
static const char *openstep_fetch_filetype(const char *unix_path) {
	const char *bnam;
	const char *slash;
	const char *ext;

	slash = strrchr(unix_path, '/');
	bnam = slash == NULL ? unix_path : slash + 1;
	ext = strrchr(bnam, '.');
	if (ext == NULL) {
		return "text/html";
	}
	ext += 1;

	if (strncmp(ext, "css", 3) == 0) {
		return "text/css";
	} else if (strncmp(ext, "jpeg", 4) == 0 || strncmp(ext, "jpg", 3) == 0) {
		return "image/jpeg";
	} else if (strncmp(ext, "gif", 3) == 0) {
		return "image/gif";
	} else if (strncmp(ext, "png", 3) == 0) {
		return "image/png";
	} else if (strncmp(ext, "txt", 3) == 0) {
		return "text/plain";
	} else {
		return "text/html";
	}
}

static nsurl *openstep_fetch_get_resource_url(const char *path) {
	struct nsurl *url = NULL;
	char *url_string;
	const char *file_path;
	NSString *nspath = [[NSBundle mainBundle] pathForResource: [NSString
		stringWithCString: path] ofType: @""];
	if (nspath == nil) {
		return NULL;
	}
	file_path = [nspath cString];
	url_string = malloc(strlen(file_path) + 8);
	if (url_string == NULL) {
		return NULL;
	}
	sprintf(url_string, "file://%s", file_path);
	nsurl_create(url_string, &url);
	free(url_string);
	return url;
}

static nserror openstep_fetch_get_resource_data(const char *path,
		const uint8_t **data, size_t *data_len) {
	FILE *fp;
	long length;
	size_t read_len;
	uint8_t *buffer;
	const char *file_path;
	NSString *nspath;
	const char empty_user_css[] = "/* OPENSTEP user stylesheet */\n";

	if (strcmp(path, "user.css") == 0) {
		length = (long) strlen(empty_user_css);
		buffer = malloc((size_t) length);
		if (buffer == NULL) {
			return NSERROR_NOMEM;
		}
		memcpy(buffer, empty_user_css, (size_t) length);
		*data = buffer;
		*data_len = (size_t) length;
		return NSERROR_OK;
	}

	nspath = [[NSBundle mainBundle] pathForResource: [NSString
		stringWithCString: path] ofType: @""];
	if (nspath == nil) {
		return NSERROR_NOT_FOUND;
	}

	file_path = [nspath cString];
	fp = fopen(file_path, "rb");
	if (fp == NULL) {
		return NSERROR_NOT_FOUND;
	}

	if (fseek(fp, 0, SEEK_END) != 0) {
		fclose(fp);
		return NSERROR_NOT_FOUND;
	}

	length = ftell(fp);
	if (length < 0) {
		fclose(fp);
		return NSERROR_NOT_FOUND;
	}

	if (fseek(fp, 0, SEEK_SET) != 0) {
		fclose(fp);
		return NSERROR_NOT_FOUND;
	}

	buffer = malloc((size_t) length);
	if (buffer == NULL && length != 0) {
		fclose(fp);
		return NSERROR_NOMEM;
	}

	read_len = fread(buffer, 1, (size_t) length, fp);
	fclose(fp);
	if (read_len != (size_t) length) {
		free(buffer);
		return NSERROR_NOT_FOUND;
	}

	*data = buffer;
	*data_len = (size_t) length;
	return NSERROR_OK;
}

static nserror openstep_fetch_release_resource_data(const uint8_t *data) {
	free((void *) data);
	return NSERROR_OK;
}

struct gui_fetch_table openstep_fetch_table = {
	.filetype = openstep_fetch_filetype,
	.get_resource_url = openstep_fetch_get_resource_url,
	.get_resource_data = openstep_fetch_get_resource_data,
	.release_resource_data = openstep_fetch_release_resource_data
};
