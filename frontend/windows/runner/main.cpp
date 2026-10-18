#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwchar>

#include "flutter_window.h"
#include "utils.h"

namespace {

// The window title, also how a second launch finds the first instance's window.
constexpr const wchar_t kWindowTitle[] = L"Bastide";

// Brings the running instance's window to the front. The new process may do
// so: it is the one the user just launched, so it owns the foreground.
void FocusRunningInstance() {
  HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", kWindowTitle);
  if (existing == nullptr) {
    return;
  }
  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  }
  ::SetForegroundWindow(existing);
}

// Whether the installer started us for one of its hooks rather than the user:
// Velopack runs the app with `--veloapp-install`, `--veloapp-updated`,
// `--veloapp-obsolete` or `--veloapp-uninstall <version>` and kills it if it
// hasn't exited within 15 to 30 seconds. Bastide has nothing to do at those
// moments, and above all no backend to start, so it leaves at once.
bool IsInstallerHook(const wchar_t *command_line) {
  return command_line != nullptr &&
         ::wcsstr(command_line, L"--veloapp-") != nullptr;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Before the single-instance check: `--veloapp-obsolete` runs while the old
  // version may still be open, and must not focus its window.
  if (IsInstallerHook(command_line)) {
    return EXIT_SUCCESS;
  }

#ifdef NDEBUG
  // One running instance per user session: two would start two backends on
  // one database. A second launch focuses the first window and exits. Debug
  // builds skip this so `flutter run` works beside an installed copy.
  // The handle is never closed; the OS releases the mutex when we exit.
  ::CreateMutexW(nullptr, FALSE, L"Local\\Bastide.SingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    FocusRunningInstance();
    return EXIT_SUCCESS;
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
