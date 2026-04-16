# Changelog

## v1.1.6
- Refresh release metadata so Sparkle updates stay aligned per release (version, appcast URL, signature, and archive length).

## v1.1.4
- Added Sparkle-based updates and update menu support.
- Added anonymous, privacy-friendly analytics with endpoint configuration.
- Wired Cloudflare Worker-compatible analytics endpoint support.

## v1.1.0
- Fixed menu bar click handling so the dropdown reliably opens when clicking the internet speed indicator.
- Restored network speed updates after sleep/wake cycles so speeds no longer stay at 0 the next day.
- Improved stability of the network monitor by resetting sampling baselines on wake.

## v1.1.1
- Fixed download usage overflow when system network counters reset.

## v1.1.2
- Added per-second units to the menu bar speed indicator.
