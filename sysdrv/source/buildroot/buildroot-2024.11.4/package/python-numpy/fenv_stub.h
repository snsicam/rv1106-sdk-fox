/*
 * Minimal <fenv.h> stub for uClibc toolchains that lack fenv support.
 *
 * This SDK's ARM uClibc toolchain (arm-rockchip830-linux-uclibcgnueabihf)
 * does not ship <fenv.h> at all, so numpy's floating-point status/rounding
 * code cannot compile.  We provide this stub on numpy's internal include
 * path (numpy/core/include) so that `#include <fenv.h>` resolves here.
 *
 * Floating-point exception/rounding control becomes a no-op, which is
 * acceptable for klipper (array math does not rely on FP exception flags).
 */
#ifndef NPY_UCLIBC_FENV_STUB_H
#define NPY_UCLIBC_FENV_STUB_H

typedef int fenv_t;
typedef int fexcept_t;

#define FE_INEXACT    0
#define FE_DIVBYZERO  0
#define FE_UNDERFLOW  0
#define FE_OVERFLOW   0
#define FE_INVALID    0
#define FE_ALL_EXCEPT 0
#define FE_TONEAREST  0
#define FE_DOWNWARD   0
#define FE_UPWARD     0
#define FE_TOWARDZERO 0

#define FE_DFL_ENV ((const fenv_t *)0)

static inline int fetestexcept(int excepts)
{
    (void)excepts;
    return 0;
}

static inline void feclearexcept(int excepts)
{
    (void)excepts;
}

static inline int feraiseexcept(int excepts)
{
    (void)excepts;
    return 0;
}

static inline int fegetround(void)
{
    return 0;
}

static inline int fesetround(int round)
{
    (void)round;
    return 0;
}

#endif /* NPY_UCLIBC_FENV_STUB_H */
