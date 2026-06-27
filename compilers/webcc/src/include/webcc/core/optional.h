#pragma once
#include "new.h"

namespace webcc
{

    template <typename T>
    class optional
    {
    private:
        // A buffer big enough to hold T, properly aligned
        alignas(T) char m_data[sizeof(T)];
        bool m_has_value = false;

    public:
        optional() : m_has_value(false) {}

        // Construct by copying a value
        optional(const T &value)
        {
            construct(value);
        }

        ~optional() { reset(); }

        void construct(const T &value)
        {
            if (m_has_value)
                reset();
            new (m_data) T(value); // Placement new: builds T inside m_data
            m_has_value = true;
        }

        void reset()
        {
            if (m_has_value)
            {
                ((T *)m_data)->~T(); // Explicitly call the destructor
                m_has_value = false;
            }
        }

        bool has_value() const { return m_has_value; }
        operator bool() const { return m_has_value; }

        T &operator*() { return *(T *)m_data; }
        T *operator->() { return (T *)m_data; }
    };
} // namespace webcc