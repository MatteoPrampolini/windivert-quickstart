#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <conio.h>
#include <windivert.h>

#define MAX_PACKET_SIZE 0xFFFF

static volatile LONG g_running = 1;
static PVOID volatile g_divert_handle = NULL;

static BOOL is_running(void)
{
    return InterlockedCompareExchange(&g_running, 1, 1) == 1;
}

static void set_divert_handle(HANDLE handle)
{
    InterlockedExchangePointer(
        (PVOID volatile *)&g_divert_handle,
        (PVOID)handle
    );
}

static HANDLE take_divert_handle(void)
{
    return (HANDLE)InterlockedExchangePointer(
        (PVOID volatile *)&g_divert_handle,
        NULL
    );
}

static void request_stop(void)
{
    if (InterlockedExchange(&g_running, 0) == 0) {
        return;
    }

    HANDLE handle = take_divert_handle();

    if (handle != NULL && handle != INVALID_HANDLE_VALUE) {
        WinDivertClose(handle);
    }
}

static DWORD WINAPI keyboard_thread(LPVOID parameter)
{
    (void)parameter;

    while (is_running()) {
        if (_kbhit()) {
            int ch = _getch();

            if (ch == ' ') {
                printf("\nSpace pressed. Stopping gracefully...\n");
                request_stop();
                break;
            }
        }

        Sleep(50);
    }

    return 0;
}

static BOOL WINAPI console_ctrl_handler(DWORD event)
{
    switch (event) {
    case CTRL_C_EVENT:
    case CTRL_CLOSE_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_LOGOFF_EVENT:
    case CTRL_SHUTDOWN_EVENT:
        printf("\nConsole close requested. Stopping gracefully...\n");
        request_stop();
        return TRUE;

    default:
        return FALSE;
    }
}

int main(void)
{
    const char *filter = "outbound and ip and tcp";

    SetConsoleCtrlHandler(console_ctrl_handler, TRUE);

    HANDLE handle = WinDivertOpen(
        filter,
        WINDIVERT_LAYER_NETWORK,
        0,
        0
    );

    if (handle == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        fprintf(stderr, "WinDivertOpen failed. Error: %lu\n", error);
        fprintf(stderr, "Hint: run this program as administrator.\n");
        return EXIT_FAILURE;
    }

    set_divert_handle(handle);

    HANDLE input_thread = CreateThread(
        NULL,
        0,
        keyboard_thread,
        NULL,
        0,
        NULL
    );

    if (input_thread == NULL) {
        fprintf(stderr, "CreateThread failed. Error: %lu\n", GetLastError());
        request_stop();
        return EXIT_FAILURE;
    }

    printf("WinDivert started.\n");
    printf("Filter: %s\n", filter);
    printf("Capturing outbound TCP packets.\n");
    printf("Press SPACE to stop gracefully.\n\n");

    unsigned char packet[MAX_PACKET_SIZE];
    WINDIVERT_ADDRESS address;
    UINT packet_len = 0;

    while (is_running()) {
        if (!WinDivertRecv(
                handle,
                packet,
                sizeof(packet),
                &packet_len,
                &address
            )) {
            DWORD error = GetLastError();

            if (!is_running()) {
                break;
            }

            fprintf(stderr, "WinDivertRecv failed. Error: %lu\n", error);
            continue;
        }

        printf("Captured packet: %u bytes\n", packet_len);

        if (!WinDivertSend(
                handle,
                packet,
                packet_len,
                NULL,
                &address
            )) {
            DWORD error = GetLastError();

            if (!is_running()) {
                break;
            }

            fprintf(stderr, "WinDivertSend failed. Error: %lu\n", error);
            continue;
        }
    }

    request_stop();

    WaitForSingleObject(input_thread, 1000);
    CloseHandle(input_thread);

    printf("Stopped gracefully.\n");
    return EXIT_SUCCESS;
}
