ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
DEBUG = 0
FINALPACKAGE = 1

INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OneWx

OneWx_FILES = Tweak.x $(shell find Sources -type f -name '*.m' -o -type f -name '*.x')
OneWx_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)
OneWx_LDFLAGS = -Wl,-dead_strip
OneWx_FRAMEWORKS = UIKit Foundation QuartzCore WebKit AVFoundation UserNotifications CoreMedia MediaPlayer UniformTypeIdentifiers CoreImage CoreVideo PhotosUI ImageIO

include $(THEOS_MAKE_PATH)/tweak.mk
