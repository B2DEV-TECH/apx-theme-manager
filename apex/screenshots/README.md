# Runtime screenshots

These are actual screenshots of the authenticated original manager application
in the disposable APXTM_LAB workspace, captured on 2026-10-20 with Chrome and
Playwright against Oracle APEX 26.2.0. They are not mockups.

- `overview-desktop.png`: native Cards and registered-application report at a
  1440×1080 viewport.
- `application-mobile.png`: application selector, details and native snapshot
  report at a 390×844 viewport. Wide tables scroll within their own region.
- `guide-mobile.png`: the native workflow guide at a 390×844 viewport.

The screenshots include synthetic test history. Displayed counts reflect the
captured lab state; installation starts with an empty registry and disabled
modification policy. The optional `scripts/apex-browser-smoke.mjs` reproduces the
read-only browser checks using the ignored local lab configuration.
