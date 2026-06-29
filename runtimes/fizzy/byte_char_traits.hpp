// fizzy uses std::basic_string<uint8_t> / basic_string_view<uint8_t> (bytes.hpp),
// which needs std::char_traits<uint8_t>. libc++ (LLVM 19+) removed the
// non-standard char_traits specializations for non-char types, so we provide a
// minimal one. Force-included (-include) ahead of <string> so it's visible at
// every instantiation point. Modeled on the old libc++ unsigned-char traits.
#pragma once
// fizzy's parser passes string_view<uint8_t> iterators where raw `const uint8_t*`
// is expected. libc++ ABI v2 makes string_view::const_iterator a __wrap_iter
// (not a pointer), breaking those conversions. string_view is header-only, so we
// undo just that ABI flag before <string_view> is first pulled in — no mismatch
// with the prebuilt libc++ (string_view carries no iterator in its ABI).
#include <cstddef>  // establishes libc++ __config (defines the ABI flag)
#ifdef _LIBCPP_ABI_USE_WRAP_ITER_IN_STD_STRING_VIEW
#  undef _LIBCPP_ABI_USE_WRAP_ITER_IN_STD_STRING_VIEW
#endif
#include <cstdint>
#include <cstring>
#include <string_view>
#include <string>

namespace std {
template <>
struct char_traits<uint8_t>
{
    using char_type = uint8_t;
    using int_type = unsigned int;
    using off_type = streamoff;
    using pos_type = streampos;
    using state_type = mbstate_t;

    static inline void assign(char_type& a, const char_type& b) noexcept { a = b; }
    static inline bool eq(char_type a, char_type b) noexcept { return a == b; }
    static inline bool lt(char_type a, char_type b) noexcept { return a < b; }

    static int compare(const char_type* s1, const char_type* s2, size_t n) noexcept
    {
        return n == 0 ? 0 : memcmp(s1, s2, n);
    }
    static size_t length(const char_type* s) noexcept
    {
        size_t i = 0;
        while (s[i] != char_type(0))
            ++i;
        return i;
    }
    static const char_type* find(const char_type* s, size_t n, const char_type& a) noexcept
    {
        return n == 0 ? nullptr : static_cast<const char_type*>(memchr(s, a, n));
    }
    static char_type* move(char_type* d, const char_type* s, size_t n) noexcept
    {
        return n == 0 ? d : static_cast<char_type*>(memmove(d, s, n));
    }
    static char_type* copy(char_type* d, const char_type* s, size_t n) noexcept
    {
        return n == 0 ? d : static_cast<char_type*>(memcpy(d, s, n));
    }
    static char_type* assign(char_type* s, size_t n, char_type a) noexcept
    {
        return n == 0 ? s : static_cast<char_type*>(memset(s, a, n));
    }

    static inline int_type not_eof(int_type c) noexcept { return eq_int_type(c, eof()) ? ~eof() : c; }
    static inline char_type to_char_type(int_type c) noexcept { return char_type(c); }
    static inline int_type to_int_type(char_type c) noexcept { return int_type(c); }
    static inline bool eq_int_type(int_type a, int_type b) noexcept { return a == b; }
    static inline int_type eof() noexcept { return int_type(EOF); }
};
}  // namespace std
