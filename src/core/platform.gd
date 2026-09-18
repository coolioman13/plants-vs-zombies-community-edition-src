class_name Platform
extends Object
## What kind of device the game is running on, and what that device is allowed to do.
##
## The port ships for Windows, for the browser and for Android. Only the Windows build gets
## multiplayer: the netcode is deterministic lockstep over ENet on a LAN (localhost / LAN /
## Radmin / Hamachi), which a browser build cannot open sockets for and a phone has no way to
## reach, so every other platform hides it behind a message instead of failing halfway in.
##
## "Mobile" covers a native Android build and a browser running on a phone or tablet; both get
## the zoomed-in, non-widescreen presentation described in App.apply_presentation().

enum { DESKTOP, MOBILE }

static var _kind := -1
static var _web_mobile := false
## Set by the capture/test tools (and the --mobile command line flag) to preview the phone layout
## on a desktop. Nothing in the game itself writes it.
static var force_mobile := false

static func _detect() -> void:
	if _kind != -1:
		return
	var os := OS.get_name()
	if os == "Android" or os == "iOS":
		_kind = MOBILE
	elif os == "Web":
		# the browser build reports "Web" everywhere, so ask the page what it is running on
		_web_mobile = OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or DisplayServer.is_touchscreen_available()
		_kind = MOBILE if _web_mobile else DESKTOP
	else:
		_kind = DESKTOP

static func is_web() -> bool:
	return OS.get_name() == "Web"

static func is_android() -> bool:
	return OS.get_name() == "Android"

static func is_windows() -> bool:
	var os := OS.get_name()
	return os == "Windows" or os == "UWP"

## True on a phone or tablet, natively or in a browser.
static func is_mobile() -> bool:
	if force_mobile:
		return true
	_detect()
	return _kind == MOBILE

## True when the on-screen presentation should zoom in and drop the widescreen margins.
static func wants_mobile_view() -> bool:
	return is_mobile()

## LAN multiplayer needs real sockets and a shared network, so it is Windows only.
static func supports_multiplayer() -> bool:
	return is_windows() and not force_mobile

## One line explaining why multiplayer is missing, shown when it is tapped anyway.
static func multiplayer_unavailable_reason() -> String:
	return "[MULTIPLAYER_WRONG_DEVICE]"

## Human name for the current device, for logs and the options page.
static func describe() -> String:
	if is_web():
		return "Browser (mobile)" if is_mobile() else "Browser"
	return OS.get_name()
