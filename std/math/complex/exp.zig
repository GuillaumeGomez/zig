const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

const ldexp_cexp = @import("ldexp.zig").ldexp_cexp;

pub fn exp(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);

    return switch (T) {
        f32 => exp32(z),
        f64 => exp64(z),
        else => @compileError("exp not implemented for " ++ @typeName(z)),
    };
}

fn exp32(z: &const Complex(f32)) Complex(f32) {
    @setFloatMode(this, @import("builtin").FloatMode.Strict);

    const exp_overflow  = 0x42b17218;    // max_exp * ln2 ~= 88.72283955
    const cexp_overflow = 0x43400074;   // (max_exp - min_denom_exp) * ln2

    const x = z.re;
    const y = z.im;

    const hy = @bitCast(u32, y) & 0x7fffffff;
    // cexp(x + i0) = exp(x) + i0
    if (hy == 0) {
        return Complex(f32).new(math.exp(x), y);
    }

    const hx = @bitCast(u32, x);
    // cexp(0 + iy) = cos(y) + isin(y)
    if ((hx & 0x7fffffff) == 0) {
        return Complex(f32).new(math.cos(y), math.sin(y));
    }

    if (hy >= 0x7f800000) {
        // cexp(finite|nan +- i inf|nan) = nan + i nan
        if ((hx & 0x7fffffff) != 0x7f800000) {
            return Complex(f32).new(y - y, y - y);
        }
        // cexp(-inf +- i inf|nan) = 0 + i0
        else if (hx & 0x80000000 != 0) {
            return Complex(f32).new(0, 0);
        }
        // cexp(+inf +- i inf|nan) = inf + i nan
        else {
            return Complex(f32).new(x, y - y);
        }
    }

    // 88.7 <= x <= 192 so must scale
    if (hx >= exp_overflow and hx <= cexp_overflow) {
        return ldexp_cexp(z, 0);
    }
    // - x < exp_overflow => exp(x) won't overflow (common)
    // - x > cexp_overflow, so exp(x) * s overflows for s > 0
    // - x = +-inf
    // - x = nan
    else {
        const exp_x = math.exp(x);
        return Complex(f32).new(exp_x * math.cos(y), exp_x * math.sin(y));
    }
}

fn exp64(z: &const Complex(f64)) Complex(f64) {
    const exp_overflow  = 0x40862e42;    // high bits of max_exp * ln2 ~= 710
    const cexp_overflow = 0x4096b8e4;   // (max_exp - min_denorm_exp) * ln2

    const x = z.re;
    const y = z.im;

    const fy = @bitCast(u64, y);
    const hy = u32(fy >> 32) & 0x7fffffff;
    const ly = @truncate(u32, fy);

    // cexp(x + i0) = exp(x) + i0
    if (hy | ly == 0) {
        return Complex(f64).new(math.exp(x), y);
    }

    const fx = @bitCast(u64, x);
    const hx = u32(fx >> 32);
    const lx = @truncate(u32, fx);

    // cexp(0 + iy) = cos(y) + isin(y)
    if ((hx & 0x7fffffff) | lx == 0) {
        return Complex(f64).new(math.cos(y), math.sin(y));
    }

    if (hy >= 0x7ff00000) {
        // cexp(finite|nan +- i inf|nan) = nan + i nan
        if (lx != 0 or (hx & 0x7fffffff) != 0x7ff00000) {
            return Complex(f64).new(y - y, y - y);
        }
        // cexp(-inf +- i inf|nan) = 0 + i0
        else if (hx & 0x80000000 != 0) {
            return Complex(f64).new(0, 0);
        }
        // cexp(+inf +- i inf|nan) = inf + i nan
        else {
            return Complex(f64).new(x, y - y);
        }
    }

    // 709.7 <= x <= 1454.3 so must scale
    if (hx >= exp_overflow and hx <= cexp_overflow) {
        const r = ldexp_cexp(z, 0);
        return *r;
    }
    // - x < exp_overflow => exp(x) won't overflow (common)
    // - x > cexp_overflow, so exp(x) * s overflows for s > 0
    // - x = +-inf
    // - x = nan
    else {
        const exp_x = math.exp(x);
        return Complex(f64).new(exp_x * math.cos(y), exp_x * math.sin(y));
    }
}

const epsilon = 0.0001;

test "complex.cexp32" {
    const a = Complex(f32).new(5, 3);
    const c = exp(a);

    debug.assert(math.approxEq(f32, c.re, -146.927917, epsilon));
    debug.assert(math.approxEq(f32, c.im, 20.944065, epsilon));
}

test "complex.cexp64" {
    const a = Complex(f32).new(5, 3);
    const c = exp(a);

    debug.assert(math.approxEq(f64, c.re, -146.927917, epsilon));
    debug.assert(math.approxEq(f64, c.im, 20.944065, epsilon));
}
