// Zen Browser hardening for i915 GPU stability
// Disable hardware acceleration to prevent GPU hangs
// Comment these out to re-enable if system is stable
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.webrender.software", true);
user_pref("media.hardware-video-decoding.enabled", false);

// Trust the homelab step-ca root (O=Betalixt CA), and any other CA in the
// system trust store.
//
// Firefox and Zen do NOT use the system CA store by default -- they carry their
// own NSS database per profile. This pref makes them additionally read the
// system store through p11-kit, so a CA installed once into
// /etc/ca-certificates/trust-source/anchors/ works everywhere rather than
// needing a certutil import into every profile's cert9.db.
//
// The cert itself lives in system/ca-certificates/betalixt-root.crt and is
// deployed by install-sway-arch.sh.
user_pref("security.enterprise_roots.enabled", true);
