<p align="center">
  <img src="https://img.shields.io/badge/WoW%20Forever-1.60.1-c9a0ff?style=flat-square" alt="WoW Forever 1.60.1">
  <img src="https://img.shields.io/badge/status-not%20yet%20played%20in%20game-e98fd0?style=flat-square" alt="Status: not yet played in game">
  <img src="https://img.shields.io/badge/speaks-Mary%20Sue%20Protocol-2b2333?style=flat-square" alt="Speaks the Mary Sue Protocol">
</p>

> [!WARNING]
> **Very much a work in progress.** This first stage has passed its test harness but hasn't been played in the game. Expect things to need fixing.

**Guise is a roleplay profile add-on for WoW Forever.** When you meet someone, you see who their character is. When they meet you,
they see yours. Nobody has to ask out of character.

It speaks the **Mary Sue Protocol**, the format Total RP 3, MyRolePlay and XRP share. If those add-ons come to Forever, their users and
Guise's see each other's profiles without anyone doing anything.

## What it does

### Your profile
Your RP name (it starts as your Forever first and last name), a title, pronouns, age, build and eyes, and a short **Currently** line for
what you're doing right now. Up to five **glances**: an icon, a title and a few lines each, for what anyone would notice. A **description**
with headings and emphasis. An OOC note. Your **status**: In character, Out of character, Looking for contact or Storyteller.

**Boundaries** tell people what's welcome before they walk up: walk-ups, combat, injury, romance and death, each *welcome*, *ask first*
or *not for me*, and how experienced you are.

Keep several profiles and switch costumes with one click. Everything saves as you type, and the editor shows your tooltip as others
will see it.

### Meeting people
- **Tooltip:** their RP name in its colour, title, status, pronouns, what they're doing, their OOC note, glance icons, and the first
  line of your own note about them.
- **Glance strip:** your target's glances under the target frame. Hover one to read it. It hides in combat.
- **Character sheet:** one window for anyone, yourself included. At a glance, their description, and your private notes and relation
  (friend, ally, family, rival, enemy).
- **Directory:** everyone you've met with a profile. Search, filter (in your zone, looking for contact, relations), sort, and forget
  people you haven't seen in 90 days.
- **Guise bar:** your status in one click, your sheet, the editor and the directory. Plus a minimap button.

### Being a good neighbour
- Others' text shows as plain text. A stranger's profile can't put links, textures or colour codes on your screen.
- Ignored players are never asked for anything. Hide any profile with one click.
- **Mature profiles** are marked by their owners. Until you turn on "Show mature profiles", you see only their name and status.
- Guise asks only the person you're looking at, only for what changed, and never twice in 15 seconds. Someone who doesn't answer is
  left alone for 5 minutes. It sends nothing during encounters or chat lockdown, or in battlegrounds unless you allow it, and it
  never sends chat text.
- When the game hides a name for security reasons (secret values), Guise leaves the game's own tooltip alone.

## Commands

| | |
|---|---|
| `/guise` | your target's sheet, or yours |
| `/guise edit` | edit your profile |
| `/guise dir` | the directory |
| `/guise ic`, `ooc`, `lfc`, `st` | set your status |
| `/guise settings` | settings (also in Options > AddOns > Guise) |
| `/guise bar` | bring the bar back if it's lost |
| `/guise forget First Last` | forget someone |

`/rp` does the same when no other add-on uses it.

## Not in this version
RP names in chat, speech colour in emotes, RP names on nameplates, a "nearby" view from a shared zone, and importing a TurtleRP
profile are planned for later stages (see `docs/guise-v1.md` in the project).

## Licence
All rights reserved; see `LICENSE`. ChatThrottleLib is public domain; the fonts are under the SIL Open Font License.
Guise was inspired by TurtleRP for Turtle WoW but shares none of its code or art.
