## RULE ZERO
Never guess at undocumented behavior — read the source or STOP and ask.
Anti-example: Writing `card.type === 'trainer'` instead of `isTrainerCard(card)` silently breaks on Fossil cards. Cost: 30+ min to trace. Don't guess types.

---

## gstack (CIRCUIT BREAKER — run before any work)
```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```
If GSTACK_MISSING: **STOP. Do not proceed.** Tell the user to run:
```bash
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --team
```
Then restart the AI tool. Skills after install: `/qa /ship /review /investigate /browse` — use `/browse` for all web browsing. Path: `~/.claude/skills/gstack/…`

---

## Project
**TCGP Deck Builder** — React 19 + Vite 8 + TS + Tailwind 4 SPA → GitHub Pages at https://thecryptocanuck.github.io/pokemon/
Mobile-first. User tests on **Android Chrome**. Capacitor Android project in `android/`.

Read **TODOS.md** before proposing features. Move closed items to `## Done` with a PR link.

---

## Deploy
Push `main` → Actions builds + publishes in ~1 min. User may need hard-refresh (10-min GH Pages cache).
After web changes for Android: `npm run build:android && npx cap copy android`

---

## Circuit Breakers — STOP if any apply
1. Writing `card.type === 'trainer'` → use `isTrainerCard(card)`
2. Changing `localStorage` key names or value shape → existing user data will corrupt
3. Removing `order-1 lg:order-2` from `DeckEditor.tsx` → breaks mobile-first column order
4. Removing `eslint-disable react-hooks/set-state-in-effect` in `DeckAnalysis.tsx` → both setState-in-effect blocks are intentional (RAF tween + grade-pill remount)
5. Removing `clearTimeout` returns from sparkle/pin timers in `DeckBuilderPage.tsx` → animation leak on unmount

---

## Bug Diagnosis Protocol
Before touching any bug, write this block — omitting it is visible:
```
HYPOTHESIS: [what you think is wrong]
EVIDENCE:   [file:line that supports it]
VERDICT:    [confirmed / ruled out because ...]
```

---

## Skill Gates — load these when task matches
| Task involves | Load |
|---|---|
| card types, isTrainer, Fossil, card IDs | `docs/conventions.md` § Card Model |
| scoring, heuristics, archetypes, auto-build | `src/utils/deck-scoring.ts` + `docs/conventions.md` § Scoring |
| animations, sparkle, count-pulse, shimmer | `src/index.css` |
| localStorage, collection shape, deck shape | `docs/conventions.md` § Storage |
| Capacitor, Android, APK, cap copy | `capacitor.config.ts`, `android/` |
| new TCGP set, rich card data | `scripts/fetch-rich-cards.mjs` |

---

## Gotchas
- **Sandbox TLS**: card-DB fetch fails in headless dogfood. Copy `cards.extra.json` → `public/cards.dev.json`, revert before commit.
- **Vite dev server**: bound to `0.0.0.0` — phone reaches `http://<dev-ip>:5173/pokemon/` over LAN.
- **gstack browse**: needs `CONTAINER=1` env var for `--no-sandbox` in Chromium as root.

---

## Reference (load on demand — not at session start)
- [`docs/conventions.md`](docs/conventions.md) — card model, IDs, encoding, storage keys, layout invariants, animation rules
- [`TODOS.md`](TODOS.md) — open backlog + done list
- [`CHANGELOG.md`](CHANGELOG.md) — one heading per merged PR

---

## RULE ZERO (repeated — U-shaped attention)
Never guess at undocumented behavior. Read the source. When in doubt, STOP and ask.
