# TCGP Deck Builder

A web app for managing your Pokemon TCG Pocket card collection and building optimal decks.

## Features

- **Card Collection Tracker** - Browse the full TCGP card database, mark cards you own
- **Video Import** - Upload a screen recording of your TCGP collection; Claude Vision AI identifies your cards automatically
- **Custom Deck Builder** - Build decks with full TCGP rule enforcement (20 cards, 2 copy max, Basic Pokemon required, 3 energy type limit)
- **Meta Deck Suggestions** - See which top-tier meta decks you can build with your collection, ranked by completeness

## Setup

```bash
npm install
npm run dev
```

## Video Import

To import your collection from the TCGP Android app:

1. Open Pokemon TCG Pocket on your phone
2. Go to your card collection
3. Screen-record yourself scrolling through all your cards
4. Upload the video to this app
5. Enter your Anthropic API key (stored locally, only sent to Anthropic)
6. The app extracts frames and uses Claude Vision to identify cards

## Tech Stack

- React + TypeScript + Vite
- Tailwind CSS
- Claude Vision API for card recognition
- Card data from [pokemon-tcg-pocket-database](https://github.com/flibustier/pokemon-tcg-pocket-database)
