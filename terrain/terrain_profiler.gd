extends RefCounted
class_name TerrainProfiler

const MIN_LOG_INTERVAL_USEC := 10000

# Keep profiler instrumentation available, but disabled during normal editor use.
static var enabled := false
static var _last_log_usec := -MIN_LOG_INTERVAL_USEC
static var _pending_logs: Array[String] = []

static func begin() -> int:
	return Time.get_ticks_usec()

static func elapsed_msec(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0

static func log_timing(label: String, start_usec: int, details: String = "") -> void:
	if not enabled:
		return

	_emit_or_queue(_format_message(label, elapsed_msec(start_usec), details))

static func flush_pending() -> void:
	if not enabled or _pending_logs.is_empty():
		return

	var now := Time.get_ticks_usec()
	if now - _last_log_usec < MIN_LOG_INTERVAL_USEC:
		return

	_last_log_usec = now
	print(_pending_logs.pop_front())

static func _emit_or_queue(message: String) -> void:
	var now := Time.get_ticks_usec()
	if now - _last_log_usec >= MIN_LOG_INTERVAL_USEC:
		_last_log_usec = now
		print(message)
		return

	_pending_logs.append(message)
	if _pending_logs.size() > 1000:
		_pending_logs.pop_front()

static func _format_message(label: String, elapsed_ms: float, details: String = "") -> String:
	var suffix := "" if details.is_empty() else " | %s" % details
	return "[TerrainProfiler] %s: %.3f ms%s" % [label, elapsed_ms, suffix]
