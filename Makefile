ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
DEBUG = 0
FINALPACKAGE = 1

INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WCGesture

WCGesture_FILES = Tweak.x $(wildcard Sources/*.m)
WCGesture_OBJCFLAGS = -fobjc-arc
WCGesture_LDFLAGS = -Wl,-dead_strip
WCGesture_FRAMEWORKS = UIKit Foundation QuartzCore WebKit

include $(THEOS_MAKE_PATH)/tweak.mk
