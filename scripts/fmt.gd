class_name Fmt
extends RefCounted
## Number and time formatting for small screens.

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg"]

static func num(v: float) -> String:
	if is_nan(v) or is_inf(v):
		return "∞"
	var neg := v < 0.0
	v = absf(v)
	if absf(v - roundf(v)) < 1e-6 * maxf(1.0, v):
		v = roundf(v)   # 61.9999 from float math must show as 62
	var s: String
	if v < 1000.0:
		if v < 10.0 and v != floorf(v):
			s = "%.1f" % v
		else:
			s = str(int(floorf(v)))
	elif v < 1.0e6:
		s = _commas(int(floorf(v)))
	else:
		var tier := int(floorf(log(v) / log(1000.0)))
		tier = mini(tier, SUFFIXES.size() - 1)
		var scaled := v / pow(1000.0, tier)
		s = "%.2f %s" % [scaled, SUFFIXES[tier]]
	return ("-" if neg else "") + s

## Multiplier text: 1.75 -> "1.75", 3.0 -> "3", 7.5 -> "7.5".
static func mult(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.left(-1)
	return s.trim_suffix(".")

static func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

static func time(sec: float) -> String:
	if sec < 1.0:
		return "%.1fs" % maxf(sec, 0.0)
	var s := int(ceilf(sec))
	var h := s / 3600
	var m := (s % 3600) / 60
	var r := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, r]
	if m > 0:
		return "%d:%02d" % [m, r]
	return "%ds" % r
