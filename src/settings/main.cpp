// SaiyanGlassSettings.exe - the control window. It only runs while open: it
// edits settings.ini, tells the background host to reload, and shows the
// host's status. All the work stays in the host.
#include <unknwn.h>
#include <windows.h>
#include <dwmapi.h>
#include <shellapi.h>
#undef GetCurrentTime

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.h>
#include <winrt/Windows.UI.Xaml.h>
#include <winrt/Windows.UI.Xaml.Controls.h>
#include <winrt/Windows.UI.Xaml.Controls.Primitives.h>
#include <winrt/Windows.UI.Xaml.Hosting.h>
#include <winrt/Windows.UI.Xaml.Markup.h>
#include <winrt/Windows.UI.Xaml.Media.h>
#include <winrt/Windows.UI.Xaml.Shapes.h>
#include <windows.ui.xaml.hosting.desktopwindowxamlsource.h>

#include <algorithm>
#include <map>
#include <string>

#include "../common/protocol.h"
#include "../common/settings.h"

namespace wux = winrt::Windows::UI::Xaml;
namespace wuxc = winrt::Windows::UI::Xaml::Controls;
namespace wuxm = winrt::Windows::UI::Xaml::Media;
namespace wuxs = winrt::Windows::UI::Xaml::Shapes;
using namespace sg;

namespace {

constexpr wchar_t kWindowClass[] = L"SaiyanGlass.Settings";
enum : UINT_PTR { TimerSave = 1, TimerStatus = 2 };

const wchar_t kXaml[] = LR"xaml(
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" RequestedTheme="Dark" Background="Transparent">
  <Grid.Resources>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#0EFFFFFF"/>
      <Setter Property="BorderBrush" Value="#16FFFFFF"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="16,12,16,14"/>
    </Style>
    <Style x:Key="Section" TargetType="TextBlock">
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="2,18,0,8"/>
    </Style>
    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Opacity" Value="0.7"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>
    <Style x:Key="Dot" TargetType="Ellipse">
      <Setter Property="Width" Value="18"/>
      <Setter Property="Height" Value="18"/>
      <Setter Property="Stroke" Value="#40FFFFFF"/>
      <Setter Property="StrokeThickness" Value="1"/>
    </Style>
    <Style x:Key="Chip" TargetType="Button">
      <Setter Property="Width" Value="30"/>
      <Setter Property="Height" Value="30"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="CornerRadius" Value="15"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#40FFFFFF"/>
    </Style>
  </Grid.Resources>
  <ScrollViewer VerticalScrollBarVisibility="Auto">
    <StackPanel Margin="28,18,28,28" MaxWidth="640">
      <Grid>
        <StackPanel>
          <TextBlock Text="SaiyanGlass" FontSize="28" FontWeight="SemiBold"/>
          <TextBlock x:Name="StatusLine" Style="{StaticResource Hint}" Text="Connecting..."/>
        </StackPanel>
        <ToggleSwitch x:Name="Enabled" HorizontalAlignment="Right" VerticalAlignment="Center" MinWidth="0" OnContent="Glass on" OffContent="Glass off"/>
      </Grid>

      <Border x:Name="NeedTtb" Style="{StaticResource Card}" Margin="0,16,0,0" Visibility="Collapsed" BorderBrush="#80FFB060">
        <StackPanel Spacing="8">
          <TextBlock Text="TranslucentTB is needed" FontWeight="SemiBold"/>
          <TextBlock Style="{StaticResource Hint}" Text="SaiyanGlass designs the glass; TranslucentTB (free, Microsoft Store) draws it on the taskbar. Install it, then press Refresh."/>
          <Button x:Name="GetTtb" Content="Open TranslucentTB in the Store"/>
        </StackPanel>
      </Border>

      <Border Style="{StaticResource Card}" Margin="0,16,0,0">
        <Grid ColumnSpacing="14">
          <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" Spacing="6" VerticalAlignment="Center">
            <Ellipse x:Name="DotTint" Style="{StaticResource Dot}"/>
            <Ellipse x:Name="DotAccent2" Style="{StaticResource Dot}"/>
            <Ellipse x:Name="DotAccent" Style="{StaticResource Dot}"/>
          </StackPanel>
          <StackPanel Grid.Column="1" VerticalAlignment="Center">
            <TextBlock x:Name="WallpaperName" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" Text="Wallpaper"/>
            <TextBlock x:Name="WallpaperInfo" Style="{StaticResource Hint}"/>
          </StackPanel>
          <Button x:Name="Reanalyze" Grid.Column="2" Content="Sample again" VerticalAlignment="Center"/>
        </Grid>
      </Border>

      <TextBlock Text="Glass" Style="{StaticResource Section}"/>
      <Border Style="{StaticResource Card}">
        <StackPanel Spacing="8">
          <Grid>
            <TextBlock Text="Preset" VerticalAlignment="Center"/>
            <ComboBox x:Name="Preset" HorizontalAlignment="Right" MinWidth="150">
              <x:String>Clear</x:String><x:String>Balanced</x:String><x:String>Frosted</x:String><x:String>Custom</x:String>
            </ComboBox>
          </Grid>
          <Slider x:Name="Opacity" Header="Darkening" Minimum="0" Maximum="80" StepFrequency="1"/>
          <Slider x:Name="Blur" Header="Blur strength (0 = clear glass)" Minimum="0" Maximum="40" StepFrequency="1"/>
          <ToggleSwitch x:Name="TopLine" Header="Highlight line on the top edge"/>
          <ToggleSwitch x:Name="Guard" Header="Readability guard"/>
          <TextBlock Style="{StaticResource Hint}" Text="Darkens a little more only when the wallpaper behind the taskbar is bright, so the clock, language and weather text stay readable (4.5:1 contrast)."/>
        </StackPanel>
      </Border>

      <TextBlock Text="Color" Style="{StaticResource Section}"/>
      <Border Style="{StaticResource Card}">
        <StackPanel Spacing="10">
          <StackPanel Orientation="Horizontal" Spacing="4">
            <RadioButton x:Name="TintAuto" GroupName="tint" Content="From wallpaper"/>
            <RadioButton x:Name="TintFixed" GroupName="tint" Content="Fixed"/>
            <RadioButton x:Name="TintNeutral" GroupName="tint" Content="Neutral dark"/>
          </StackPanel>
          <StackPanel x:Name="FixedPanel" Orientation="Horizontal" Spacing="8">
            <Button x:Name="ChipGold" Style="{StaticResource Chip}" Background="#FFC94A" ToolTipService.ToolTip="Super Saiyan gold"/>
            <Button x:Name="ChipCrimson" Style="{StaticResource Chip}" Background="#E8455A" ToolTipService.ToolTip="God crimson"/>
            <Button x:Name="ChipBlue" Style="{StaticResource Chip}" Background="#3AB8FF" ToolTipService.ToolTip="Blue / cyan"/>
            <Button x:Name="ChipViolet" Style="{StaticResource Chip}" Background="#A36BFF" ToolTipService.ToolTip="Ultra Ego / Beast violet"/>
            <TextBox x:Name="FixedHex" Width="100" PlaceholderText="#3AA0FF" MaxLength="7"/>
          </StackPanel>
          <Slider x:Name="Intensity" Header="Color strength" Minimum="0" Maximum="100" StepFrequency="1"/>
        </StackPanel>
      </Border>

      <TextBlock Text="System" Style="{StaticResource Section}"/>
      <Border Style="{StaticResource Card}">
        <StackPanel Spacing="10">
          <ToggleSwitch x:Name="Startup" Header="Start with Windows"/>
          <StackPanel Orientation="Horizontal" Spacing="8">
            <Button x:Name="Restore" Content="Restore my previous look"/>
            <Button x:Name="OpenData" Content="Open data folder"/>
          </StackPanel>
          <TextBlock Style="{StaticResource Hint}" Text="Restore puts back the TranslucentTB look you had before SaiyanGlass. Emergency: Start menu &gt; SaiyanGlass &gt; Restore previous look, or run SaiyanGlass.exe --restore."/>
          <TextBlock Style="{StaticResource Hint}" Text="Start menu: keeps Windows' own acrylic glass; SaiyanGlass styles the taskbar."/>
        </StackPanel>
      </Border>

      <TextBlock Text="Diagnostics" Style="{StaticResource Section}"/>
      <Border Style="{StaticResource Card}">
        <StackPanel>
          <TextBlock x:Name="Diag" FontFamily="Cascadia Mono, Consolas" FontSize="11" IsTextSelectionEnabled="True" TextWrapping="Wrap" Opacity="0.85"/>
          <Button x:Name="Refresh" Content="Refresh" Margin="0,10,0,0"/>
        </StackPanel>
      </Border>
    </StackPanel>
  </ScrollViewer>
</Grid>)xaml";

struct App {
    HWND hwnd = nullptr;
    HWND island = nullptr;
    wux::Hosting::DesktopWindowXamlSource source{nullptr};
    wux::FrameworkElement root{nullptr};
    Settings settings;
    bool loading = false;
    std::map<std::wstring, std::wstring> status;
} app;

template <typename T>
T Find(const wchar_t* name) {
    return app.root.FindName(name).as<T>();
}

std::wstring ExeDir() {
    wchar_t path[MAX_PATH];
    DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
    std::wstring s(path, n);
    return s.substr(0, s.find_last_of(L'\\'));
}

void RunHostExe(const wchar_t* args, bool wait) {
    std::wstring exe = ExeDir() + L"\\SaiyanGlass.exe";
    std::wstring cmd = L"\"" + exe + L"\" " + args;
    STARTUPINFOW si{sizeof(si)};
    PROCESS_INFORMATION pi{};
    if (CreateProcessW(exe.c_str(), cmd.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
        if (wait) WaitForSingleObject(pi.hProcess, 10000);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
    }
}

HWND Host() { return FindWindowW(kHostWindowClass, nullptr); }

void SendHost(uint32_t cmd) {
    HWND host = Host();
    if (!host) {
        RunHostExe(L"--background", false);
        for (int i = 0; i < 40 && !(host = Host()); ++i) Sleep(100);
        if (!host) return;
    }
    ReplyTo r{reinterpret_cast<uint64_t>(app.hwnd)};
    COPYDATASTRUCT cds{cmd, sizeof(r), &r};
    DWORD_PTR res;
    SendMessageTimeoutW(host, WM_COPYDATA, reinterpret_cast<WPARAM>(app.hwnd), reinterpret_cast<LPARAM>(&cds), SMTO_ABORTIFHUNG, 2000, &res);
}

winrt::Windows::UI::Color Hex(const std::wstring& s) {
    unsigned v = s.size() == 7 && s[0] == L'#' ? wcstoul(s.c_str() + 1, nullptr, 16) : 0x808080;
    return {255, static_cast<uint8_t>(v >> 16), static_cast<uint8_t>(v >> 8), static_cast<uint8_t>(v)};
}

std::wstring Get(const wchar_t* key) {
    auto it = app.status.find(key);
    return it == app.status.end() ? L"" : it->second;
}

void ShowStatus() {
    auto line = Find<wuxc::TextBlock>(L"StatusLine");
    if (app.status.empty()) {
        line.Text(L"Background host not running. Changes start it automatically.");
        return;
    }
    std::wstring state = Get(L"state");
    line.Text((state == L"active" ? std::wstring(L"Active on the taskbar") : L"Status: " + state) + L"  ·  Windows " + Get(L"windows"));
    Find<wuxc::Border>(L"NeedTtb").Visibility(Get(L"translucenttb.installed") == L"1" ? wux::Visibility::Collapsed : wux::Visibility::Visible);

    std::wstring wp = Get(L"wallpaper");
    size_t slash = wp.find_last_of(L"\\/");
    Find<wuxc::TextBlock>(L"WallpaperName").Text(wp.empty() ? L"Current wallpaper" : wp.substr(slash == std::wstring::npos ? 0 : slash + 1));
    std::wstring fam = Get(L"family"), fam2 = Get(L"family2");
    std::wstring info = fam == L"neutral" ? L"No strong color" : L"Color: " + fam + (fam2.empty() || fam2 == fam ? L"" : L" + " + fam2);
    info += L"  ·  glass " + Get(L"glass") + (Get(L"readabilityRaised") == L"1" ? L" (raised for readability)" : L"");
    Find<wuxc::TextBlock>(L"WallpaperInfo").Text(info);
    Find<wuxs::Ellipse>(L"DotTint").Fill(wuxm::SolidColorBrush(Hex(Get(L"tint"))));
    Find<wuxs::Ellipse>(L"DotAccent").Fill(wuxm::SolidColorBrush(Hex(Get(L"accent"))));
    Find<wuxs::Ellipse>(L"DotAccent2").Fill(wuxm::SolidColorBrush(Hex(Get(L"accent2"))));

    app.loading = true;
    Find<wuxc::ToggleSwitch>(L"Startup").IsOn(Get(L"startup") == L"1");
    app.loading = false;

    std::wstring diag;
    for (auto& [k, v] : app.status) diag += k + L" = " + v + L"\n";
    Find<wuxc::TextBlock>(L"Diag").Text(diag);
}

void LoadIntoControls() {
    app.loading = true;
    auto& s = app.settings;
    Find<wuxc::ToggleSwitch>(L"Enabled").IsOn(s.enabled);
    Find<wuxc::ComboBox>(L"Preset").SelectedIndex(static_cast<int>(s.preset));
    Find<wuxc::Slider>(L"Opacity").Value(s.opacity);
    Find<wuxc::Slider>(L"Blur").Value(s.blur);
    Find<wuxc::Slider>(L"Intensity").Value(s.intensity);
    Find<wuxc::ToggleSwitch>(L"TopLine").IsOn(s.topLine);
    Find<wuxc::ToggleSwitch>(L"Guard").IsOn(s.guard);
    Find<wuxc::RadioButton>(L"TintAuto").IsChecked(s.tint == TintMode::Auto);
    Find<wuxc::RadioButton>(L"TintFixed").IsChecked(s.tint == TintMode::Fixed);
    Find<wuxc::RadioButton>(L"TintNeutral").IsChecked(s.tint == TintMode::Neutral);
    wchar_t hex[16];
    swprintf_s(hex, L"#%06X", s.fixedColor & 0xFFFFFF);
    Find<wuxc::TextBox>(L"FixedHex").Text(hex);
    Find<wuxc::StackPanel>(L"FixedPanel").Opacity(s.tint == TintMode::Fixed ? 1.0 : 0.45);
    app.loading = false;
}

// Saves and notifies the host shortly after the last change, so dragging a
// slider sends a handful of updates rather than hundreds.
void Changed() {
    if (app.loading) return;
    SetTimer(app.hwnd, TimerSave, 150, nullptr);
}

void SetFixed(uint32_t rgb) {
    app.settings.fixedColor = rgb;
    app.settings.tint = TintMode::Fixed;
    LoadIntoControls();
    Changed();
}

void OnSlider(const wchar_t* name, int Settings::*field, bool custom) {
    Find<wuxc::Slider>(name).ValueChanged([name, field, custom](auto&&, auto&&) {
        if (app.loading) return;
        app.settings.*field = static_cast<int>(Find<wuxc::Slider>(name).Value());
        if (custom && app.settings.preset != Preset::Custom) {
            app.settings.preset = Preset::Custom;
            app.loading = true;
            Find<wuxc::ComboBox>(L"Preset").SelectedIndex(static_cast<int>(Preset::Custom));
            app.loading = false;
        }
        Changed();
    });
}

void OnToggle(const wchar_t* name, bool Settings::*field) {
    Find<wuxc::ToggleSwitch>(name).Toggled([name, field](auto&&, auto&&) {
        if (app.loading) return;
        app.settings.*field = Find<wuxc::ToggleSwitch>(name).IsOn();
        Changed();
    });
}

void OnTint(const wchar_t* name, TintMode mode) {
    Find<wuxc::RadioButton>(name).Checked([mode](auto&&, auto&&) {
        if (app.loading) return;
        app.settings.tint = mode;
        Find<wuxc::StackPanel>(L"FixedPanel").Opacity(mode == TintMode::Fixed ? 1.0 : 0.45);
        Changed();
    });
}

void Wire() {
    Find<wuxc::ToggleSwitch>(L"Enabled").Toggled([](auto&&, auto&&) {
        if (app.loading) return;
        app.settings.enabled = Find<wuxc::ToggleSwitch>(L"Enabled").IsOn();
        Changed();
    });
    Find<wuxc::ComboBox>(L"Preset").SelectionChanged([](auto&&, auto&&) {
        if (app.loading) return;
        int i = Find<wuxc::ComboBox>(L"Preset").SelectedIndex();
        if (i < 0) return;
        app.settings.preset = static_cast<Preset>(i);
        if (app.settings.preset != Preset::Custom) {
            auto pv = PresetFor(app.settings.preset);
            app.settings.opacity = pv.opacity, app.settings.blur = pv.blur;
            LoadIntoControls();
        }
        Changed();
    });
    OnSlider(L"Opacity", &Settings::opacity, true);
    OnSlider(L"Blur", &Settings::blur, true);
    OnSlider(L"Intensity", &Settings::intensity, false);
    OnToggle(L"TopLine", &Settings::topLine);
    OnToggle(L"Guard", &Settings::guard);
    OnTint(L"TintAuto", TintMode::Auto);
    OnTint(L"TintFixed", TintMode::Fixed);
    OnTint(L"TintNeutral", TintMode::Neutral);
    Find<wuxc::Button>(L"ChipGold").Click([](auto&&, auto&&) { SetFixed(0xFFC94A); });
    Find<wuxc::Button>(L"ChipCrimson").Click([](auto&&, auto&&) { SetFixed(0xE8455A); });
    Find<wuxc::Button>(L"ChipBlue").Click([](auto&&, auto&&) { SetFixed(0x3AB8FF); });
    Find<wuxc::Button>(L"ChipViolet").Click([](auto&&, auto&&) { SetFixed(0xA36BFF); });
    Find<wuxc::TextBox>(L"FixedHex").TextChanged([](auto&&, auto&&) {
        if (app.loading) return;
        std::wstring t(Find<wuxc::TextBox>(L"FixedHex").Text());
        if (t.size() != 7 || t[0] != L'#') return;
        wchar_t* end = nullptr;
        unsigned long v = wcstoul(t.c_str() + 1, &end, 16);
        if (!end || *end) return;
        app.settings.fixedColor = static_cast<uint32_t>(v);
        if (app.settings.tint == TintMode::Fixed) Changed();
    });
    Find<wuxc::ToggleSwitch>(L"Startup").Toggled([](auto&&, auto&&) {
        if (app.loading) return;
        RunHostExe(Find<wuxc::ToggleSwitch>(L"Startup").IsOn() ? L"--startup on" : L"--startup off", true);
        SendHost(HostStatus);
    });
    Find<wuxc::Button>(L"Restore").Click([](auto&&, auto&&) {
        app.settings.enabled = false;
        SaveSettings(app.settings);
        SendHost(HostRestore);
        LoadIntoControls();
        SetTimer(app.hwnd, TimerStatus, 700, nullptr);
    });
    Find<wuxc::Button>(L"Reanalyze").Click([](auto&&, auto&&) {
        SendHost(HostReanalyze);
        SetTimer(app.hwnd, TimerStatus, 900, nullptr);
    });
    Find<wuxc::Button>(L"Refresh").Click([](auto&&, auto&&) { SendHost(HostReload); SetTimer(app.hwnd, TimerStatus, 700, nullptr); });
    Find<wuxc::Button>(L"GetTtb").Click([](auto&&, auto&&) {
        ShellExecuteW(nullptr, L"open", L"https://apps.microsoft.com/search?query=TranslucentTB", nullptr, nullptr, SW_SHOWNORMAL);
    });
    Find<wuxc::Button>(L"OpenData").Click([](auto&&, auto&&) {
        std::wstring dir = DataDirectory();
        ShellExecuteW(nullptr, L"open", dir.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
    });
}

void Layout() {
    RECT rc;
    GetClientRect(app.hwnd, &rc);
    if (app.island) SetWindowPos(app.island, nullptr, 0, 0, rc.right, rc.bottom, SWP_NOZORDER | SWP_SHOWWINDOW);
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_SIZE:
            Layout();
            return 0;
        case WM_GETMINMAXINFO: {
            UINT dpi = GetDpiForWindow(hwnd);
            reinterpret_cast<MINMAXINFO*>(lp)->ptMinTrackSize = {MulDiv(460, dpi, 96), MulDiv(520, dpi, 96)};
            return 0;
        }
        case WM_DPICHANGED: {
            auto r = reinterpret_cast<RECT*>(lp);
            SetWindowPos(hwnd, nullptr, r->left, r->top, r->right - r->left, r->bottom - r->top, SWP_NOZORDER | SWP_NOACTIVATE);
            return 0;
        }
        case WM_COPYDATA: {
            auto cds = reinterpret_cast<COPYDATASTRUCT*>(lp);
            if (cds->dwData == MsgStatus && cds->cbData >= sizeof(wchar_t)) {
                auto p = static_cast<const wchar_t*>(cds->lpData);
                std::wstring text(p, wcsnlen(p, cds->cbData / sizeof(wchar_t)));
                app.status.clear();
                for (size_t i = 0; i < text.size();) {
                    size_t e = text.find(L'\n', i);
                    if (e == std::wstring::npos) e = text.size();
                    std::wstring line = text.substr(i, e - i);
                    size_t eq = line.find(L'=');
                    if (eq != std::wstring::npos) app.status[line.substr(0, eq)] = line.substr(eq + 1);
                    i = e + 1;
                }
                PostMessageW(hwnd, WM_APP, 0, 0);  // update the UI outside the sender's call
            }
            return TRUE;
        }
        case WM_APP:
            ShowStatus();
            return 0;
        case WM_TIMER:
            KillTimer(hwnd, wp);
            if (wp == TimerSave) {
                SaveSettings(app.settings);
                SendHost(HostReload);
                SetTimer(hwnd, TimerStatus, 600, nullptr);
            } else if (wp == TimerStatus) {
                SendHost(HostStatus);
            }
            return 0;
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE, PWSTR, int show) {
    if (HWND existing = FindWindowW(kWindowClass, nullptr)) {
        ShowWindow(existing, SW_RESTORE);
        SetForegroundWindow(existing);
        return 0;
    }
    winrt::init_apartment(winrt::apartment_type::single_threaded);

    WNDCLASSEXW wc{sizeof(wc)};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = inst;
    wc.lpszClassName = kWindowClass;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hIcon = LoadIconW(inst, MAKEINTRESOURCEW(1));
    wc.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    RegisterClassExW(&wc);

    UINT dpi = GetDpiForSystem();
    int w = MulDiv(600, dpi, 96), h = MulDiv(880, dpi, 96);
    RECT work;
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
    h = std::min<int>(h, work.bottom - work.top - MulDiv(40, dpi, 96));
    app.hwnd = CreateWindowExW(0, kWindowClass, L"SaiyanGlass", WS_OVERLAPPEDWINDOW, (work.right - w) / 2, work.top + (work.bottom - work.top - h) / 2, w, h,
                               nullptr, nullptr, inst, nullptr);

    // Our own window: documented DWM dark title bar and Mica backdrop.
    BOOL dark = TRUE;
    DwmSetWindowAttribute(app.hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));
    int backdrop = DWMSBT_MAINWINDOW;
    DwmSetWindowAttribute(app.hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop, sizeof(backdrop));
    MARGINS m{-1};
    DwmExtendFrameIntoClientArea(app.hwnd, &m);

    auto manager = wux::Hosting::WindowsXamlManager::InitializeForCurrentThread();
    app.source = wux::Hosting::DesktopWindowXamlSource();
    auto native = app.source.as<IDesktopWindowXamlSourceNative2>();
    native->AttachToWindow(app.hwnd);
    native->get_WindowHandle(&app.island);
    app.root = wux::Markup::XamlReader::Load(kXaml).as<wux::FrameworkElement>();
    app.source.Content(app.root);

    app.settings = LoadSettings();
    LoadIntoControls();
    Wire();
    Layout();
    ShowWindow(app.hwnd, show);
    SendHost(HostStatus);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        BOOL handled = FALSE;
        native->PreTranslateMessage(&msg, &handled);
        if (handled) continue;
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    app.source.Close();
    manager.Close();
    return 0;
}
