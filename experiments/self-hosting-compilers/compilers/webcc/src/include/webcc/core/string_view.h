#pragma once
#include <stdint.h>

namespace webcc
{
    class string_view
    {
    private:
        const char* m_data;
        uint32_t m_len;

        static uint32_t strlen(const char* s)
        {
            uint32_t l = 0;
            if (!s) return 0;
            while (s[l]) l++;
            return l;
        }

    public:
        constexpr string_view() : m_data(nullptr), m_len(0) {}
        constexpr string_view(const char* s, uint32_t len) : m_data(s), m_len(len) {}
        
        string_view(const char* s) : m_data(s), m_len(strlen(s)) {}

        constexpr const char* data() const { return m_data; }
        constexpr uint32_t length() const { return m_len; }
        constexpr uint32_t size() const { return m_len; }
        constexpr bool empty() const { return m_len == 0; }

        constexpr const char* begin() const { return m_data; }
        constexpr const char* end() const { return m_data + m_len; }

        constexpr char operator[](uint32_t i) const { return m_data[i]; }

        bool operator==(const string_view& other) const
        {
            if (m_len != other.m_len) return false;
            for (uint32_t i = 0; i < m_len; ++i)
                if (m_data[i] != other.m_data[i]) return false;
            return true;
        }
        
        bool operator!=(const string_view& other) const { return !(*this == other); }
    };
} // namespace webcc
