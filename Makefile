APP_NAME := NoPad
EXECUTABLE_NAME := nopad
BUNDLE_ID := com.regexboi.nopad
VERSION := 1.0
BUILD_NUMBER := 1
MIN_MACOS := 13.0

APP_BUNDLE := /tmp/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_BIN := $(APP_CONTENTS)/MacOS/$(APP_NAME)
INSTALL_PATH := /Applications/$(APP_NAME).app

.PHONY: help release bundle sign stop install open clean uninstall

help:
	@echo "Targets:"
	@echo "  make release   Build release binary"
	@echo "  make bundle    Create /tmp/$(APP_NAME).app bundle"
	@echo "  make sign      Ad-hoc sign app bundle"
	@echo "  make stop      Stop running $(APP_NAME) process"
	@echo "  make install   Install signed app to /Applications"
	@echo "  make open      Install and launch app"
	@echo "  make uninstall Remove /Applications/$(APP_NAME).app"
	@echo "  make clean     Remove bundle and Swift build artifacts"

release:
	swift build -c release

bundle: release
	@BIN_PATH="$$(find .build -type f -path '*/release/$(EXECUTABLE_NAME)' | head -n1)"; \
	if [ -z "$$BIN_PATH" ]; then \
		echo "Could not find release binary for $(EXECUTABLE_NAME)."; \
		exit 1; \
	fi; \
	rm -rf "$(APP_BUNDLE)"; \
	mkdir -p "$(APP_CONTENTS)/MacOS" "$(APP_CONTENTS)/Resources"; \
	cp "$$BIN_PATH" "$(APP_BIN)"; \
	chmod +x "$(APP_BIN)"; \
	printf "%s\n" \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>CFBundleName</key><string>$(APP_NAME)</string>' \
		'  <key>CFBundleDisplayName</key><string>$(APP_NAME)</string>' \
		'  <key>CFBundleIdentifier</key><string>$(BUNDLE_ID)</string>' \
		'  <key>CFBundleExecutable</key><string>$(APP_NAME)</string>' \
		'  <key>CFBundlePackageType</key><string>APPL</string>' \
		'  <key>CFBundleShortVersionString</key><string>$(VERSION)</string>' \
		'  <key>CFBundleVersion</key><string>$(BUILD_NUMBER)</string>' \
		'  <key>LSMinimumSystemVersion</key><string>$(MIN_MACOS)</string>' \
		'  <key>NSHighResolutionCapable</key><true/>' \
		'</dict>' \
		'</plist>' > "$(APP_CONTENTS)/Info.plist"
	@echo "Bundle created at $(APP_BUNDLE)"

sign: bundle
	codesign --force --deep --sign - "$(APP_BUNDLE)"

stop:
	@osascript -e 'tell application id "$(BUNDLE_ID)" to quit' >/dev/null 2>&1 || true
	@for i in 1 2 3 4 5; do \
		pgrep -f "$(INSTALL_PATH)/Contents/MacOS/$(APP_NAME)" >/dev/null || break; \
		sleep 0.2; \
	done
	@pkill -f "$(INSTALL_PATH)/Contents/MacOS/$(APP_NAME)" >/dev/null 2>&1 || true

install: sign stop
	rm -rf "$(INSTALL_PATH)"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	@echo "Installed to $(INSTALL_PATH)"

open: install
	open "$(INSTALL_PATH)"

uninstall:
	rm -rf "$(INSTALL_PATH)"
	@echo "Removed $(INSTALL_PATH)"

clean:
	rm -rf "$(APP_BUNDLE)"
	swift package clean
