#include "ipc.h"

#include <cwchar>

namespace sg {

bool SendCommand(HWND to, uint32_t cmd, const void* data, size_t size, HWND from) {
    COPYDATASTRUCT cds{cmd, static_cast<DWORD>(size), const_cast<void*>(data)};
    DWORD_PTR result = 0;
    return SendMessageTimeoutW(to, WM_COPYDATA, reinterpret_cast<WPARAM>(from), reinterpret_cast<LPARAM>(&cds), SMTO_ABORTIFHUNG | SMTO_BLOCK, 3000,
                               &result) != 0;
}

ReplyWindow::ReplyWindow() {
    static ATOM atom = [] {
        WNDCLASSEXW wc{sizeof(wc)};
        wc.lpfnWndProc = Proc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.lpszClassName = L"SaiyanGlass.Reply";
        return RegisterClassExW(&wc);
    }();
    hwnd_ = CreateWindowExW(0, MAKEINTATOM(atom), L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), this);
}

ReplyWindow::~ReplyWindow() {
    if (hwnd_) DestroyWindow(hwnd_);
}

LRESULT CALLBACK ReplyWindow::Proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_NCCREATE) {
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams));
    } else if (msg == WM_COPYDATA) {
        auto self = reinterpret_cast<ReplyWindow*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        auto cds = reinterpret_cast<COPYDATASTRUCT*>(lp);
        if (self) {
            if (cds->cbData >= sizeof(wchar_t)) {
                auto p = static_cast<const wchar_t*>(cds->lpData);
                self->buffer_.append(p, wcsnlen(p, cds->cbData / sizeof(wchar_t)));
            }
            self->last_ = static_cast<uint32_t>(cds->dwData);
        }
        return TRUE;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

bool ReplyWindow::WaitFor(uint32_t endMsg, DWORD timeoutMs, std::wstring& text) {
    ULONGLONG deadline = GetTickCount64() + timeoutMs;
    last_ = 0;
    while (last_ != endMsg) {
        ULONGLONG now = GetTickCount64();
        if (now >= deadline) break;
        MsgWaitForMultipleObjects(0, nullptr, FALSE, static_cast<DWORD>(deadline - now), QS_ALLINPUT);
        MSG m;
        while (PeekMessageW(&m, nullptr, 0, 0, PM_REMOVE)) DispatchMessageW(&m);
    }
    text += buffer_;
    buffer_.clear();
    return last_ == endMsg;
}

}  // namespace sg
