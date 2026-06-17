#this shit is 100% AI generated, i'm not touching this shit with a 10 feet pole.
APP_NAME := windivert-quickstart

ARCH ?= x64

SRC_DIR := src
BUILD_ROOT := build
BUILD_DIR := $(BUILD_ROOT)/$(ARCH)

WINDIVERT_DIR := thirdparty/windivert
WINDIVERT_INCLUDE := $(WINDIVERT_DIR)/include

SOURCES := $(wildcard $(SRC_DIR)/*.c)
TARGET := $(BUILD_DIR)/$(APP_NAME).exe

BUILD_DIR_ABS := $(abspath $(BUILD_DIR))
TARGET_ABS := $(abspath $(TARGET))

BUILD_DIR_WIN := $(subst /,\,$(BUILD_DIR))
BUILD_DIR_ABS_WIN := $(subst /,\,$(BUILD_DIR_ABS))
TARGET_ABS_WIN := $(subst /,\,$(TARGET_ABS))

ifeq ($(ARCH),x64)
    ARCH_FLAGS := -m64
    WINDIVERT_BIN_DIR := $(WINDIVERT_DIR)/x64
    WINDIVERT_SYS := WinDivert64.sys
else ifeq ($(ARCH),x86)
    ARCH_FLAGS := -m32
    WINDIVERT_BIN_DIR := $(WINDIVERT_DIR)/x86
    WINDIVERT_SYS := WinDivert32.sys
else
    $(error Invalid ARCH "$(ARCH)". Use ARCH=x64 or ARCH=x86)
endif

CC := gcc

CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -g
CFLAGS += -DWIN32_LEAN_AND_MEAN
CFLAGS += $(ARCH_FLAGS)
CFLAGS += -I$(WINDIVERT_INCLUDE)

LDFLAGS := $(ARCH_FLAGS)

LDLIBS := $(WINDIVERT_BIN_DIR)/WinDivert.lib
LDLIBS += -lws2_32

.PHONY: all kill-running runtime run run-cmd run-cmd-admin clean clean-all x64 x86

all: kill-running $(TARGET) runtime

kill-running:
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-Process -Name '$(APP_NAME)' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 500; if (Get-Process -Name '$(APP_NAME)' -ErrorAction SilentlyContinue) { Write-Host '$(APP_NAME).exe is still running, requesting admin kill...'; Start-Process taskkill.exe -Verb RunAs -Wait -ArgumentList '/F /T /IM $(APP_NAME).exe'; Start-Sleep -Milliseconds 800 }; if (Get-Process -Name '$(APP_NAME)' -ErrorAction SilentlyContinue) { Write-Error 'Could not stop $(APP_NAME).exe. Close it manually.'; exit 1 }"

$(TARGET): $(SOURCES)
	@if not exist "$(BUILD_DIR_WIN)" mkdir "$(BUILD_DIR_WIN)"
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS) $(LDLIBS)

runtime:
	@if not exist "$(BUILD_DIR_WIN)" mkdir "$(BUILD_DIR_WIN)"
	@if not exist "$(BUILD_DIR_WIN)\WinDivert.dll" copy /Y "$(subst /,\,$(WINDIVERT_BIN_DIR)/WinDivert.dll)" "$(BUILD_DIR_WIN)\" > nul
	@if not exist "$(BUILD_DIR_WIN)\$(WINDIVERT_SYS)" copy /Y "$(subst /,\,$(WINDIVERT_BIN_DIR)/$(WINDIVERT_SYS))" "$(BUILD_DIR_WIN)\" > nul

run: all
	powershell.exe -NoProfile -Command "Start-Process -FilePath '$(TARGET_ABS_WIN)' -WorkingDirectory '$(BUILD_DIR_ABS_WIN)' -Verb RunAs"

run-cmd: all
	powershell.exe -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/K cd /d ""$(BUILD_DIR_ABS_WIN)"" && .\$(APP_NAME).exe'"

run-cmd-admin: all
	powershell.exe -NoProfile -Command "Start-Process cmd.exe -Verb RunAs -ArgumentList '/K cd /d ""$(BUILD_DIR_ABS_WIN)"" && .\$(APP_NAME).exe'"

x64:
	$(MAKE) ARCH=x64

x86:
	$(MAKE) ARCH=x86

clean:
	@if exist "$(BUILD_DIR_WIN)" rmdir /S /Q "$(BUILD_DIR_WIN)"

clean-all:
	@if exist "$(subst /,\,$(BUILD_ROOT))" rmdir /S /Q "$(subst /,\,$(BUILD_ROOT))"
