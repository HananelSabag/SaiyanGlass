#pragma once
#include <windows.h>

#include <string>

#include "../common/protocol.h"

namespace sg {

bool SendCommand(HWND to, uint32_t cmd, const void* data, size_t size, HWND from = nullptr);

// A message-only window that collects WM_COPYDATA text replies.
class ReplyWindow {
public:
    ReplyWindow();
    ~ReplyWindow();
    HWND hwnd() const { return hwnd_; }
    // Pumps messages until `endMsg` arrives or the timeout passes.
    bool WaitFor(uint32_t endMsg, DWORD timeoutMs, std::wstring& text);

private:
    static LRESULT CALLBACK Proc(HWND, UINT, WPARAM, LPARAM);
    HWND hwnd_ = nullptr;
    std::wstring buffer_;
    uint32_t last_ = 0;
};

}  // namespace sg
