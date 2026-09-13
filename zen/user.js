// Zen Browser hardening for i915 GPU stability
// Disable hardware acceleration to prevent GPU hangs
// Comment these out to re-enable if system is stable
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.webrender.software", true);
user_pref("media.hardware-video-decoding.enabled", false);
