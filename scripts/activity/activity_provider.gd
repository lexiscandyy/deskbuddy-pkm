extends RefCounted
## ActivityProvider interface.
##
## Implementations:
##  - MockActivityProvider   : demo/testing, driven by buttons ("Simulasi").
##  - NativeActivityProvider : Windows (GetLastInputInfo / GetForegroundWindow),
##                             added in Milestone 2.
##
## Providers return raw signals only. Turning them into ACTIVE / IDLE / UNKNOWN
## is done by the Activity autoload so the idle threshold lives in one place.

enum State { UNKNOWN, ACTIVE, IDLE }


func get_label() -> String:
	return "Abstrak"


func is_available() -> bool:
	return false


func get_status_text() -> String:
	return "Tidak tersedia"


## Seconds since the last keyboard/mouse input of the current Windows session.
## A negative value means "unknown".
func get_idle_seconds() -> float:
	return -1.0


## Executable name of the foreground app (e.g. "game.exe"). Empty = unknown.
## Never return window titles, URLs or anything else.
func get_foreground_process() -> String:
	return ""
