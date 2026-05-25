/*
 * OPENSTEP compatibility routines.
 */

#ifdef NeXT

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <iconv.h>

#include "utils/utsname.h"

#ifdef iconv_open
#undef iconv_open
#endif
#ifdef iconv
#undef iconv
#endif
#ifdef iconv_close
#undef iconv_close
#endif

extern iconv_t libiconv_open(const char *tocode, const char *fromcode);
extern size_t libiconv(iconv_t cd, char **inbuf, size_t *inbytesleft,
		char **outbuf, size_t *outbytesleft);
extern int libiconv_close(iconv_t cd);

iconv_t iconv_open(const char *tocode, const char *fromcode)
{
	return libiconv_open(tocode, fromcode);
}

size_t iconv(iconv_t cd, char **inbuf, size_t *inbytesleft,
		char **outbuf, size_t *outbytesleft)
{
	return libiconv(cd, inbuf, inbytesleft, outbuf, outbytesleft);
}

int iconv_close(iconv_t cd)
{
	return libiconv_close(cd);
}

struct tm *gmtime_r(const time_t *timep, struct tm *result)
{
	struct tm *tmp;

	tmp = gmtime(timep);
	if (tmp == NULL) {
		return NULL;
	}

	*result = *tmp;
	return result;
}

struct tm *localtime_r(const time_t *timep, struct tm *result)
{
	struct tm *tmp;

	tmp = localtime(timep);
	if (tmp == NULL) {
		return NULL;
	}

	*result = *tmp;
	return result;
}

double log2(double x)
{
	return log(x) / log(2.0);
}

double trunc(double x)
{
	return (x < 0.0) ? ceil(x) : floor(x);
}

double cbrt(double x)
{
	return (x < 0.0) ? -pow(-x, 1.0 / 3.0) : pow(x, 1.0 / 3.0);
}

double __builtin_inf(void)
{
	return HUGE_VAL;
}

char *strdup(const char *s)
{
	size_t len;
	char *copy;

	if (s == NULL) {
		return NULL;
	}

	len = strlen(s) + 1;
	copy = malloc(len);
	if (copy != NULL) {
		memcpy(copy, s, len);
	}
	return copy;
}

int vsnprintf(char *str, size_t size, const char *format, va_list ap)
{
	char buffer[65536];
	int len;

	len = vsprintf(buffer, format, ap);
	if (str != NULL && size != 0) {
		size_t copy = (len >= 0 && (size_t)len < size) ? (size_t)len : size - 1;
		memcpy(str, buffer, copy);
		str[copy] = 0;
	}

	return len;
}

int snprintf(char *str, size_t size, const char *format, ...)
{
	va_list ap;
	int len;

	va_start(ap, format);
	len = vsnprintf(str, size, format, ap);
	va_end(ap);

	return len;
}

long long int strtoll(const char *nptr, char **endptr, int base)
{
	return (long long int)strtol(nptr, endptr, base);
}

float strtof(const char *nptr, char **endptr)
{
	return (float)strtod(nptr, endptr);
}

float ceilf(float x)
{
	return (float)ceil((double)x);
}

int isascii(int c)
{
	return (c & ~0x7f) == 0;
}

#endif
