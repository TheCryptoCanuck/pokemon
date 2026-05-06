# Android Chrome — deployment-target gotchas

The user runs this app on Android Chrome. Most of the time it's just "Chrome", but mobile Chrome on Android has enough quirks that they're worth a dedicated section.

## GitHub Pages cache

GitHub Pages caches the HTML for ~10 minutes at the CDN edge. After a deploy, the user often sees the *previous* version on first reload.

**Symptoms:** "I just merged a fix and it's still showing the bug" — usually this.

**Fix on the user's side:** hard refresh in Chrome — pull down past the refresh point, or open a new tab and re-paste the URL, or DevTools → Application → Clear storage → Clear site data.

**Fix on the dev side:** for cache-bustable assets, Vite already hashes the JS/CSS filenames. The HTML itself is what gets cached. If a release truly can't wait, you can append a `?v=<timestamp>` query to the URL and tell the user to use that link.

**Don't:** add `<meta http-equiv="cache-control" content="no-cache">` to `index.html`. It works but defeats the point of the CDN. Live with the 10-minute lag for normal releases.

## navigator.vibrate quirks

`navigator.vibrate(8)` works on Android Chrome, no-ops on iOS Safari, no-ops in desktop browsers without permission gestures, and no-ops when the page hasn't received a user gesture yet.

**The "first interaction" gotcha:** in some Chrome versions, vibration doesn't fire until *after* the first user gesture has been processed. So a `tap()` call in a `useEffect` that runs on mount won't vibrate, even if there was a user gesture that *caused* the mount. The fix is to call `tap()` from the event handler that the gesture arrives at, not from a downstream effect.

The current code already does this correctly (haptics fire from `onClick` handlers, not from effects). If you find yourself wanting to call `tap()` from an effect, restructure — pass the call up to the handler.

**The reduced-motion check** in `haptics.ts` no-ops `tap()` when the OS-level reduce-motion setting is on. Some users have this set without realizing — that's why their haptics "don't work". This is correct behavior; don't override.

## Viewport and safe areas

The deployed app uses `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`. The `viewport-fit=cover` is what lets us paint into the notch/cutout area on phones that have one.

**`env(safe-area-inset-*)` for padding.** Containers that span edge-to-edge use `padding-bottom: env(safe-area-inset-bottom)` to avoid the home indicator. Tailwind 4 exposes these via the `pb-[env(safe-area-inset-bottom)]` arbitrary-value syntax.

**Bottom-fixed elements** (toasts, sticky save buttons) need the safe-area inset added to whatever bottom offset they have. Forgetting this means the toast renders behind the home indicator on iPhone (and on the gesture-bar phones the user might also test on).

## Chrome version variance

The user's phone gets Chrome updates from Google Play independent of OS updates. Practical implications:

- Chrome ~115+ is a reasonable floor. Older than that, expect feature gaps.
- New CSS like `:has()`, container queries, view transitions: usable, but check `caniuse` if you're using bleeding-edge.
- The `popover` API and `dialog` element work, but their styling has been changing. If you reach for them, test on the actual phone, not just desktop Chrome.

## Touch targets

Android's accessibility guidelines call for 48×48 dp minimum. In CSS terms, with the default device pixel ratio, that's roughly 48px × 48px.

The deck-row tap target meets this comfortably. The `−` remove buttons inside rows are visually small but the actual button has padding to hit the 48px target. If you add new tap targets:

- Visible 24-32px is fine if the surrounding padding gets you to 48px hit area.
- A row of small icon buttons is the failure mode — make sure they don't overlap each other's hit areas, and consider adding visible separation.

## Network conditions

The user likely tests on Wi-Fi and on cellular. The card images come from jsDelivr CDN; the card data JSON is bundled into the deploy; the only runtime API call is the Vision flow (and only when importing).

**On a flaky cellular connection:**

- The first load may be slow (the bundled JS + cards data total is non-trivial).
- Image loading is progressive; the grid renders with placeholders.
- The Vision import will be the painful experience — large frames over slow uplink. The retry-skip behavior in the recognizer matters most here.

If you're adding any new outbound network call (e.g. a new data source), assume the user is on 1Mbps cellular and design accordingly. Cache aggressively.

## Hard-refresh ritual after a deploy

Document this for the user when a fix is critical:

1. Open the app URL.
2. Pull down past the refresh threshold.
3. Wait for the spinner to complete.
4. If the bug still shows: Chrome menu (⋮) → History → Clear browsing data → "Cookies, site, and other site data" + "Cached images and files" for "Last hour" → Clear data.
5. Re-open the URL.

The first three steps fix 90% of cases. Step 4 is the nuclear option for when the cache is really stuck.
