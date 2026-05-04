.PHONY: flutter-pub-get app-icons check-android-sdk android-apk android-apk-split

# Repo root (this Makefile sits next to pubspec.yaml).
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Use Android Studio default install paths when ANDROID_HOME is not set.
ifeq ($(strip $(ANDROID_HOME)),)
  ifneq ($(wildcard $(HOME)/Library/Android/sdk/platform-tools/adb),)
    export ANDROID_HOME := $(HOME)/Library/Android/sdk
  else ifneq ($(wildcard $(HOME)/Android/Sdk/platform-tools/adb),)
    export ANDROID_HOME := $(HOME)/Android/Sdk
  endif
endif

# Optional compile-time backend URL (physical devices cannot use localhost for your Mac).
# Example: BACKEND_BASE_URL=http://192.168.1.10:8000 make android-apk
BACKEND_BASE_URL ?=
DART_DEFINES :=
ifneq ($(strip $(BACKEND_BASE_URL)),)
DART_DEFINES += --dart-define=BACKEND_BASE_URL=$(BACKEND_BASE_URL)
endif

check-android-sdk:
	@if [ -z "$(ANDROID_HOME)" ] || [ ! -d "$(ANDROID_HOME)" ]; then \
	  echo >&2 ""; \
	  echo >&2 "No Android SDK found (ANDROID_HOME is unset or that directory does not exist)."; \
	  echo >&2 ""; \
	  echo >&2 "Install the SDK, then point ANDROID_HOME at it (Flutter uses the same variable)."; \
	  echo >&2 ""; \
	  echo >&2 "  Option A — Android Studio (simplest):"; \
	  echo >&2 "    https://developer.android.com/studio"; \
	  echo >&2 "    Open SDK Manager → install a Platform (e.g. API 35) + Android SDK Build-Tools."; \
	  echo >&2 ""; \
	  echo >&2 "  Option B — After install, add to ~/.zshrc (macOS default path):"; \
	  echo >&2 "    export ANDROID_HOME=\"\$$HOME/Library/Android/sdk\""; \
	  echo >&2 "    export PATH=\"\$$PATH:\$$ANDROID_HOME/platform-tools\""; \
	  echo >&2 ""; \
	  echo >&2 "  Then: flutter doctor --android-licenses"; \
	  echo >&2 ""; \
	  exit 1; \
	fi

flutter-pub-get:
	cd "$(ROOT_DIR)" && flutter pub get

# Regenerate Android launcher mipmaps + web/favicon + web/icons from assets/branding/app_icon.png
app-icons: flutter-pub-get
	cd "$(ROOT_DIR)" && dart run flutter_launcher_icons

# Release APK (fat binary: all ABIs in one file).
android-apk: check-android-sdk flutter-pub-get
	cd "$(ROOT_DIR)" && flutter build apk --release $(DART_DEFINES)
	@echo "APK: $(ROOT_DIR)/build/app/outputs/flutter-apk/app-release.apk"

# Smaller per-CPU APKs under the same output directory.
android-apk-split: check-android-sdk flutter-pub-get
	cd "$(ROOT_DIR)" && flutter build apk --release --split-per-abi $(DART_DEFINES)
	@echo "APKs: $(ROOT_DIR)/build/app/outputs/flutter-apk/"
