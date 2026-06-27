#pragma once

#include <stdint.h>
#include <stddef.h>

namespace webcc
{
    // --- Constants ---
    static constexpr float PI = 3.14159265358979323846f;
    static constexpr float HALF_PI = 1.57079632679489661923f;
    static constexpr float TAU = 6.28318530717958647692f;
    static constexpr float DEG2RAD = PI / 180.0f;
    static constexpr float RAD2DEG = 180.0f / PI;

    // --- Basic Math ---
    inline float abs(float x) { return x < 0 ? -x : x; }

    inline float sqrt(float x)
    {
        if (x <= 0)
            return 0;
        return __builtin_sqrtf(x);
    }

    // --- Trigonometry ---
    inline float sin(float x)
    {
        float sin_val = 1.27323954f * x - 0.405284735f * x * abs(x);
        // Extra precision step
        sin_val = 0.225f * (sin_val * abs(sin_val) - sin_val) + sin_val;
        return sin_val;
    }

    inline float cos(float x)
    {
        return sin(x + HALF_PI);
    }

    inline float tan(float x)
    {
        return sin(x) / cos(x);
    }

    // --- Linear Algebra ---
    struct Vec3
    {
        float x, y, z;

        // Operator overloads for clean syntax: v1 + v2
        Vec3 operator+(const Vec3 &v) const { return {x + v.x, y + v.y, z + v.z}; }
        Vec3 operator-(const Vec3 &v) const { return {x - v.x, y - v.y, z - v.z}; }
        Vec3 operator*(float s) const { return {x * s, y * s, z * s}; }

        float dot(const Vec3 &v) const { return x * v.x + y * v.y + z * v.z; }

        Vec3 cross(const Vec3 &v) const
        {
            return {
                y * v.z - z * v.y,
                z * v.x - x * v.z,
                x * v.y - y * v.x};
        }

        float length() const { return webcc::sqrt(dot(*this)); }

        Vec3 normalize() const
        {
            float len = length();
            return (len > 0) ? (*this * (1.0f / len)) : Vec3{0, 0, 0};
        }
    };

    struct Mat4
    {
        float m[16]; // Column-major 

        static Mat4 identity()
        {
            return {{1, 0, 0, 0,
                     0, 1, 0, 0,
                     0, 0, 1, 0,
                     0, 0, 0, 1}};
        }

        // Basic translation matrix
        static Mat4 translation(float x, float y, float z)
        {
            Mat4 res = identity();
            res.m[12] = x;
            res.m[13] = y;
            res.m[14] = z;
            return res;
        }

        // Matrix multiplication
        Mat4 operator*(const Mat4 &b) const
        {
            Mat4 res = {0};
            for (int col = 0; col < 4; ++col)
            {
                for (int row = 0; row < 4; ++row)
                {
                    for (int k = 0; k < 4; ++k)
                    {
                        res.m[col * 4 + row] += m[k * 4 + row] * b.m[col * 4 + k];
                    }
                }
            }
            return res;
        }
    };

} // namespace webcc