# Changelog

## 0.2.1 (2026-11-07)

- **GuiseAPI**, for other add-ons: `GetProfile(nameOrUnit)` gives ready-to-show, safe text (colour split out, glances decoded) and respects
  hidden and mature profiles; plus `NameForUnit`, `Request`, `RegisterCallback`, `IsActive`. Documented in the README and `api.lua`.
- Checked that add-ons reading LibMSP's shared table see Guise's profiles, including ones kept from earlier sessions, which reach `msp.char`
  as soon as anyone looks.
- Compatibility notes: rpTags doesn't run on Forever with any profile add-on (unmaintained since 2022, "Name-Realm" lookups). Macaroni RP's
  MSP fallback should see Guise, not yet checked against its code.

## 0.2.0 (2026-11-07)

Works with the other roleplay add-ons. Passed its harness; not yet played in game.

- **Talks through LibMSP and Chomp**, embedded unchanged: the same libraries and wire format (MSP2) as Total RP 3, MyRolePlay and XRP.
  0.1 spoke the 2011 MSP format, which all of them now ignore, so it couldn't reach anyone but another Guise.
- Fields written and read the way those add-ons do it: colour inside the name and class, glances in Total RP 3's format, FC and FR
  codes as they use them (FR 4 is "guide"), boundaries as RI/RD/RR/RM/RO, relationship status, personality traits (read), heights and
  weights in centimetres and kilograms.
- New profile fields: prefix, profile icon, nickname, house, motto, weight, home, birthplace, history, relationship status. Boundaries
  gain crime and loss of control and a "not shown" choice. Experience is now new, casual, veteran or guide.
- The editor gains Details and History tabs. The sheet shows the new fields, a profile icon, and personality traits from Total RP 3 profiles.
- Descriptions keep colours and game icons from other add-ons; Total RP 3's "#Heading" and "---" and MyRolePlay's line breaks render.
- Steps aside, with a message, when Total RP 3, MyRolePlay, XRP or another MSP add-on is running for the character.
- Names: a unit is known by the name Chomp gives it ("First Last" on Forever), and a first name alone is never turned into a guess.
- 0.1 profiles are upgraded (boundary order, "Regular" experience becomes Casual).

## 0.1.0 (2026-11-07)

First build: Stage 1 of `docs/guise-v1.md`. Passed its harness; not yet played in game.

- Profiles: RP name, title, pronouns (IC and OOC), age, build, eyes, race and class labels, name colour, Currently, OOC note,
  status, up to five glances, a description with simple markup, boundaries and experience, and a mature flag. Several profiles,
  one worn per character.
- The Mary Sue Protocol over add-on whispers: per-field versions, "not changed" answers, multi-part messages, the tooltip bundle.
  Total RP 3, MyRolePlay and XRP profiles read; Guise's extra fields travel as XB, XM, XC and XP.
- Pacing: 15 s per field per person, 5 minutes for people who don't answer, 30 s between descriptions to the same person. Nothing
  sent in chat lockdown or an encounter, Mythic+ or PvP match restriction, or in battlegrounds unless allowed.
- Tooltip, glance strip under the target frame, character sheet, directory, editor with a live preview, Guise bar, minimap button,
  settings.
- Strangers' text is shown as plain text; description HTML is escaped; fields are capped. Secret values are never read.
