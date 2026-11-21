extends RefCounted
class_name AcknexEngineTiming

## Frame/tick timing of the original Acknex A5 engine, for WDL statements that
## run per frame instead of per tick.
##
## Measured on the running original (SamShare.exe under Wine) and confirmed in
## the binary:
## - The frame limiter sleeps until 1000/fps_max - 4 ms (fps_max 70), so the
##   engine runs at about 100 frames per second (16 ticks per second).
## - `x *= k` and `accel` friction (`dest = dest * (1 - f) + src * time`) are
##   not scaled by time: they apply once per frame.
## - `wait n` / `waitt n` resume on the next frame plus (n - 1) frames / ticks;
##   the scheduler wakes a `waitt` once less than one frame of time remains.
## - ticks1 (mm1.wdl main loop) counts frames.

const TICKS_PER_SECOND := 16.0
const FRAMES_PER_SECOND := 100.0
const FRAMES_PER_TICK := FRAMES_PER_SECOND / TICKS_PER_SECOND


## Per-frame multiplicative factor (`v *= k`, `accel` friction 1 - k) over `delta` seconds.
static func frame_factor(factor_per_frame: float, delta: float) -> float:
	return pow(clampf(factor_per_frame, 0.0, 1.0), FRAMES_PER_SECOND * maxf(delta, 0.0))


## Frames a `waitt wait_ticks` statement takes before its loop runs again.
static func waitt_frames(wait_ticks: float) -> int:
	var frame_ticks := TICKS_PER_SECOND / FRAMES_PER_SECOND
	var remaining := -maxf(wait_ticks - 1.0, 0.0)
	var frames := 1
	while remaining <= -minf(frame_ticks, 1.0):
		remaining += frame_ticks
		frames += 1
	return frames


## Seconds between emits of `While (1) { If (ticks1 % modulo == 0) {emit} waitt wait_ticks; }`.
static func ticks1_emit_interval(modulo: int, wait_ticks: float) -> float:
	var frames_per_loop := waitt_frames(wait_ticks)
	var safe_modulo := maxi(modulo, 1)
	var a := frames_per_loop
	var b := safe_modulo
	while b != 0:
		var t := b
		b = a % b
		a = t
	return float(frames_per_loop * safe_modulo / a) / FRAMES_PER_SECOND


## Seconds between iterations of a plain `waitt wait_ticks` loop.
static func waitt_interval(wait_ticks: float) -> float:
	return float(waitt_frames(wait_ticks)) / FRAMES_PER_SECOND
