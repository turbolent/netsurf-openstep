/*
 * OPENSTEP compatibility definitions for the NetSurf build.
 *
 * Keep this namespaced header force-included by the OPENSTEP make
 * configuration rather than shadowing standard headers from the repo root.
 */

#ifndef NETSURF_UTILS_OPENSTEP_H
#define NETSURF_UTILS_OPENSTEP_H

#ifdef NeXT

#ifndef _POSIX_SOURCE
#define _POSIX_SOURCE 1
#endif
#ifndef _NEXT_SOURCE
#define _NEXT_SOURCE 1
#endif

#include <sys/types.h>
#include <stdarg.h>

#ifndef __cplusplus
#ifndef __bool_true_false_are_defined
#define bool _Bool
#define true 1
#define false 0
#define __bool_true_false_are_defined 1
#endif
#endif

#ifndef OPENSTEP_C99_TYPES_DEFINED
#define OPENSTEP_C99_TYPES_DEFINED
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

typedef unsigned char uint_least8_t;
typedef unsigned short uint_least16_t;
typedef unsigned int uint_least32_t;
typedef unsigned long long uint_least64_t;

typedef signed char int_least8_t;
typedef signed short int_least16_t;
typedef signed int int_least32_t;
typedef signed long long int_least64_t;

typedef unsigned int uint_fast8_t;
typedef signed int int_fast8_t;
typedef unsigned int uint_fast16_t;
typedef signed int int_fast16_t;
typedef unsigned int uint_fast32_t;
typedef signed int int_fast32_t;
typedef unsigned long long uint_fast64_t;
typedef signed long long int_fast64_t;

typedef unsigned long uintptr_t;
typedef long intptr_t;
typedef unsigned long long uintmax_t;
typedef signed long long intmax_t;
#endif

#ifndef __GNUC_PATCHLEVEL__
#define __GNUC_PATCHLEVEL__ 0
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#ifndef M_PI_2
#define M_PI_2 1.57079632679489661923
#endif

#ifndef INT8_MIN
#define INT8_MIN (-INT8_MAX - 1)
#define INT8_MAX 127
#define UINT8_MAX 255U
#define INT16_MIN (-INT16_MAX - 1)
#define INT16_MAX 32767
#define UINT16_MAX 65535U
#define INT32_MIN (-INT32_MAX - 1)
#define INT32_MAX 2147483647
#define UINT32_MAX 4294967295UL
#define INT64_MIN (-INT64_MAX - 1LL)
#define INT64_MAX 9223372036854775807LL
#define UINT64_MAX 18446744073709551615ULL

#define INT_LEAST8_MIN INT8_MIN
#define INT_LEAST8_MAX INT8_MAX
#define UINT_LEAST8_MAX UINT8_MAX
#define INT_LEAST16_MIN INT16_MIN
#define INT_LEAST16_MAX INT16_MAX
#define UINT_LEAST16_MAX UINT16_MAX
#define INT_LEAST32_MIN INT32_MIN
#define INT_LEAST32_MAX INT32_MAX
#define UINT_LEAST32_MAX UINT32_MAX
#define INT_LEAST64_MIN INT64_MIN
#define INT_LEAST64_MAX INT64_MAX
#define UINT_LEAST64_MAX UINT64_MAX

#define INT_FAST8_MIN INT32_MIN
#define INT_FAST8_MAX INT32_MAX
#define UINT_FAST8_MAX UINT32_MAX
#define INT_FAST16_MIN INT32_MIN
#define INT_FAST16_MAX INT32_MAX
#define UINT_FAST16_MAX UINT32_MAX
#define INT_FAST32_MIN INT32_MIN
#define INT_FAST32_MAX INT32_MAX
#define UINT_FAST32_MAX UINT32_MAX
#define INT_FAST64_MIN INT64_MIN
#define INT_FAST64_MAX INT64_MAX
#define UINT_FAST64_MAX UINT64_MAX

#define INTPTR_MIN (-INTPTR_MAX - 1L)
#define INTPTR_MAX 2147483647L
#define UINTPTR_MAX 4294967295UL
#define INTMAX_MIN INT64_MIN
#define INTMAX_MAX INT64_MAX
#define UINTMAX_MAX UINT64_MAX
#define SIZE_MAX ((size_t)-1)
#endif

#ifndef PRId8
#define PRId8 "d"
#define PRIi8 "i"
#define PRIo8 "o"
#define PRIu8 "u"
#define PRIx8 "x"
#define PRIX8 "X"
#define PRId16 "d"
#define PRIi16 "i"
#define PRIo16 "o"
#define PRIu16 "u"
#define PRIx16 "x"
#define PRIX16 "X"
#define PRId32 "d"
#define PRIi32 "i"
#define PRIo32 "o"
#define PRIu32 "u"
#define PRIx32 "x"
#define PRIX32 "X"
#define SCNx32 "x"
#define PRId64 "lld"
#define PRIi64 "lli"
#define PRIo64 "llo"
#define PRIu64 "llu"
#define PRIx64 "llx"
#define PRIX64 "llX"
#define PRIdPTR "ld"
#define PRIiPTR "li"
#define PRIoPTR "lo"
#define PRIuPTR "lu"
#define PRIxPTR "lx"
#define PRIXPTR "lX"
#endif

#ifndef asm
#define asm __asm__
#endif
#ifndef restrict
#define restrict
#endif

#ifndef F_OK
#define F_OK 0
#endif
#ifndef X_OK
#define X_OK 1
#endif
#ifndef W_OK
#define W_OK 2
#endif
#ifndef R_OK
#define R_OK 4
#endif

int access(const char *path, int mode);
int unlink(const char *path);
int rmdir(const char *path);
char *strdup(const char *s);
int snprintf(char *str, size_t size, const char *format, ...);
int vsnprintf(char *str, size_t size, const char *format, va_list ap);

#ifndef NSInteger
typedef int NSInteger;
#endif
#ifndef NSUInteger
typedef unsigned int NSUInteger;
#endif
#ifndef CGFloat
typedef float CGFloat;
#endif
#ifndef NS_ENUM
#define NS_ENUM(_type, _name) _type _name; enum
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>
@class NSWindow;
@class NSOutlineView;
@class NSAlert;
@class NSOutputStream;
@class NSURL;
@protocol NSTextFieldDelegate
@end
@protocol NSApplicationDelegate
@end
#ifndef NSOnState
#define NSOnState 1
#endif
#ifndef NSOffState
#define NSOffState 0
#endif
#endif

#endif

#endif
