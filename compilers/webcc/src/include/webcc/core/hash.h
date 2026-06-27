#pragma once
#include <stdint.h>
#include <stddef.h>
#include "string.h"
#include "string_view.h"

namespace webcc
{
    template <typename T>
    struct hash;

    // Integer hashes (identity)
    template <> struct hash<int32_t> { size_t operator()(int32_t x) const { return (size_t)x; } };
    template <> struct hash<uint32_t> { size_t operator()(uint32_t x) const { return (size_t)x; } };
    template <> struct hash<int64_t> { size_t operator()(int64_t x) const { return (size_t)x; } };
    template <> struct hash<uint64_t> { size_t operator()(uint64_t x) const { return (size_t)x; } };

    // FNV-1a Hash for strings
    inline size_t fnv1a_hash(const char* s, size_t len)
    {
        size_t hash = 2166136261u;
        for (size_t i = 0; i < len; ++i) {
            hash ^= (unsigned char)s[i];
            hash *= 16777619;
        }
        return hash;
    }

    template <> struct hash<const char*> {
        size_t operator()(const char* s) const {
            size_t len = 0;
            while(s[len]) len++;
            return fnv1a_hash(s, len);
        }
    };

    template <> struct hash<string> {
        size_t operator()(const string& s) const {
            return fnv1a_hash(s.data(), s.length());
        }
    };

    template <> struct hash<string_view> {
        size_t operator()(const string_view& s) const {
            return fnv1a_hash(s.data(), s.length());
        }
    };

} // namespace webcc
