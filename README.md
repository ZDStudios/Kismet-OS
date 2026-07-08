# Kismet OS

> 📦 **This repo is now a public archive.**
> Kismet OS has been folded into **[AI OS](https://github.com/ZDStudios/AIOS)** — a broader project bringing together OpenClaw, Hermes, LifeOS, opencode, and the local-AI/agent ideas Kismet OS started with. Rather than splitting focus across two half-built OS/agent concepts, everything is being consolidated into AIOS so there's one place to actually build momentum. Kismet OS stays up as-is for reference and history, but there won't be further active development here. Head to AIOS for the current work 👋

## Download
Download Kismet OS here: https://tinyurl.com/kismetos
The default password is: `kismet`

Kismet OS is an AI-first desktop Linux concept focused on local intelligence, developer ergonomics, and a clean, deeply integrated workflow.

It is not trying to be magic. The goal is simpler and harder than that: build a Linux environment that feels thoughtfully assembled for modern developers, with local AI, strong defaults, and room for deeper system automation over time.

## Status
**Beta concept repository (archived)**

What exists today:
- a public-facing landing page
- product direction and positioning
- architecture notes for the OS concept
- a practical roadmap for the first real builds

What does **not** exist yet:
- a polished, production-ready ISO release
- a production-ready installer
- a true kernel-resident autonomous agent

What now exists in-repo:
- a real `kismet-agent` local daemon scaffold
- a `kismet-ctl` CLI
- an Ollama model preload service path
- a first-boot setup wizard with hardware-aware model suggestions
- a live-build based ISO configuration path for Ubuntu 24.04 + KDE Plasma

That distinction still matters.

## Project direction
Kismet OS was being shaped around a few principles:
- local-first AI workflows
- strong developer defaults
- minimal friction after install
- clean Plasma-based desktop experience
- practical automation before science fiction

The current concept leaned toward:
- Ubuntu-first base
- KDE Plasma
- themed SDDM login
- Plymouth boot splash
- a graphical installer flow
- OpenClaw integration
- Ollama for local models
- a polished developer environment out of the box
- Zorin-like polish with a touch of Garuda-style energy

## Why this existed
A lot of Linux setups are powerful, but they still feel assembled rather than designed. Kismet OS was an attempt to close that gap.

The idea was to combine:
- a tasteful desktop experience
- a serious development environment
- useful on-device AI
- careful automation
- a product feel instead of a pile of packages

## Planned architecture
The first credible versions of Kismet OS were expected to ship as an opinionated Linux build with:
- curated package manifests
- system services for AI and automation
- desktop integration helpers
- theming and branding across boot, login, and desktop
- onboarding and post-install setup flows

Longer term work would have included:
- deeper agent hooks into system state
- safer automation policies
- hardware-aware performance profiles
- richer desktop control and task orchestration

## Repository layout
```text
.
├── docs/
│   ├── architecture.md
│   ├── roadmap.md
│   └── vision.md
├── assets/
│   └── brand/
├── index.html
├── LICENSE
└── README.md
```

## Short roadmap (historical — see AIOS for active roadmap)
### Beta 0.1
- tighten the product direction
- define the base distro strategy
- document the architecture
- establish brand and UX direction

### Beta 0.2
- create package manifests and setup scripts
- prototype desktop theming
- wire local AI services and helper tooling

### Beta 0.3
- prepare first installable developer preview
- test on real hardware (we use my crappy laptop -MagicExployter)
- document setup, updates, and recovery

## Contributing
This repo is archived, so it's no longer accepting active contributions. If you want to help build on these ideas, jump over to **[AI OS](https://github.com/ZDStudios/AIOS)** — that's where architecture feedback, distro build recommendations, KDE theming help, packaging/installer workflows, and security/permissions design are actually landing.

## Notes
If you found the original landing page and thought, "this is ambitious," yes. That is the polite version.

Kismet OS was built in public, and the aim was to keep the repo grounded. The vision was bold. The implementation stayed honest. That same spirit carries forward into AIOS.

Other notes:
- Catpuccin themes coming soon!!! (or now)
- Fish terminal???? (ye ye pls add ZDStudios)
- Rofi or Wofi idk maybe klauncher (I don't even know what this OS is running on)
- App dock coming soon
- Maybe it will use ZRAM in the future
- I suck at coding -MagicExployter
