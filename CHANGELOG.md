# Changelog

All notable changes to Maldö's Inc Caller. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The release workflow takes the `## [x.y.z]` section of the version being released as the release notes and
refuses to release a version that has none, so move the `## [Unreleased]` entries into a version section first.

## [Unreleased]

## [1.0.0] - 2026-11-18

### Added

- A small window with the bases of the battleground you are in: Warsong Gulch, Arathi Basin, Alterac Valley
  and Darkspear Islands. Any other battleground uses its map markers.
- The base you are standing at is selected automatically; a click selects another one. When you move away
  from a base it is deselected again (can be switched off, the distance is adjustable).
- Call buttons 1, 2, 3, 4+, Big and Clear send the call to your team with one click. They are secure macro
  buttons, so they work in battlegrounds and in combat.
- Flag battlegrounds: call inc on the flag carrier.
- Your own buttons and phrases, with `{base}` and `{count}`.
- A pause after each call (3 seconds by default, adjustable) to prevent spam.
- Chat channel: automatic, battleground, raid or party. Outside a group the call is only shown to you.
- The window is movable, half transparent by default, with adjustable opacity and size.
- Commands `/inc` (aliases `/inccaller`, `/mic`), a demo (`/inc test`), an options page, an error report
  (`/inc log`) and debug messages (`/inc debug`).
- English and German.
