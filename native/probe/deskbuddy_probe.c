/*
 * deskbuddy_probe: tiny Windows helper for DeskBuddy (Milestone 2).
 *
 * Once per second it prints one line to stdout:
 *     <idle_ms>|<foreground exe name>
 * e.g. "1532|code.exe". idle_ms is -1 when unknown.
 *
 *   idle_ms : GetLastInputInfo (time since the last keyboard/mouse input)
 *   exe name: GetForegroundWindow -> GetWindowThreadProcessId ->
 *             QueryFullProcessImageNameW (file name only)
 *
 * Privacy: it never reads window titles, URLs, keystrokes or screen content,
 * writes nothing to disk and has no network code. The exe name is only
 * queried when the second argument is 1.
 *
 * Usage: deskbuddy_probe.exe <parent_pid> <want_foreground 0|1>
 * Exits when the parent process ends or stdout is closed.
 *
 * Build (MinGW):  gcc -O2 -s -o ../bin/deskbuddy_probe.exe deskbuddy_probe.c
 * or run build.bat in this folder.
 */
#define WIN32_LEAN_AND_MEAN
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

#ifndef PROCESS_QUERY_LIMITED_INFORMATION
#define PROCESS_QUERY_LIMITED_INFORMATION 0x1000
#endif

typedef BOOL (WINAPI *QueryNameFn)(HANDLE, DWORD, LPWSTR, PDWORD);

static QueryNameFn query_name = NULL;

static void exe_name(DWORD pid, char *out, int cap)
{
    HANDLE h;
    WCHAR path[MAX_PATH];
    DWORD len = MAX_PATH;
    WCHAR *base;

    out[0] = 0;
    if (pid == 0 || query_name == NULL)
        return;
    h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (h == NULL)
        return;
    if (query_name(h, 0, path, &len)) {
        base = wcsrchr(path, L'\\');
        base = base ? base + 1 : path;
        if (WideCharToMultiByte(CP_UTF8, 0, base, -1, out, cap, NULL, NULL) == 0)
            out[0] = 0;
    }
    CloseHandle(h);
}

int main(int argc, char **argv)
{
    DWORD parent = argc > 1 ? (DWORD)strtoul(argv[1], NULL, 10) : 0;
    int want_fg = argc > 2 && atoi(argv[2]) == 1;
    HANDLE parent_handle = parent ? OpenProcess(SYNCHRONIZE, FALSE, parent) : NULL;
    DWORD last_pid = (DWORD)-1;
    char name[512] = "";

    query_name = (QueryNameFn)GetProcAddress(GetModuleHandleA("kernel32.dll"), "QueryFullProcessImageNameW");

    for (;;) {
        LASTINPUTINFO li;
        int written;

        if (parent_handle != NULL && WaitForSingleObject(parent_handle, 0) == WAIT_OBJECT_0)
            break;

        li.cbSize = sizeof(li);
        if (want_fg) {
            DWORD pid = 0;
            HWND w = GetForegroundWindow();
            if (w != NULL)
                GetWindowThreadProcessId(w, &pid);
            if (pid != last_pid) {
                last_pid = pid;
                exe_name(pid, name, (int)sizeof(name));
            }
        }
        if (GetLastInputInfo(&li))
            written = printf("%lu|%s\n", (unsigned long)(GetTickCount() - li.dwTime), want_fg ? name : "");
        else
            written = printf("-1|%s\n", want_fg ? name : "");
        if (written < 0 || fflush(stdout) != 0)
            break;
        Sleep(1000);
    }
    if (parent_handle != NULL)
        CloseHandle(parent_handle);
    return 0;
}
