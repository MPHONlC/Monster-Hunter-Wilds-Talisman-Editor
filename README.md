# Talisman Editor

A REFramework script for Monster Hunter Wilds that edits the talismans in your equipment box: change skills, skill levels and decoration slots from an in-game menu.

It works on the save data already loaded in memory. Nothing is written to your save file until the game saves.

> [!WARNING]
> Back up your save before editing. The script writes directly into the loaded save data, and a bad value can produce a broken item. Use at your own risk.

## Key features

- Lists the talismans in your equipment box, named by their skills and slots, so you can find one by typing a skill name.
- Changes each of the three skill slots from a dropdown, or clears a slot with "(None)".
- Sets the level of each skill (1 to 5).
- Changes the slot layout (armor slots only, weapon slot plus armor slots, or weapon slot only) and the level of each slot (none to 3).
- Warns you when the same skill sits on one talisman twice.
- Has a skill list filter, because the full list is long.

## Requirements

- Monster Hunter Wilds (PC, Steam)
- [REFramework](https://github.com/praydog/REFramework) for Monster Hunter Wilds, installed and working
- [_CatLib](https://www.nexusmods.com/monsterhunterwilds/mods/65)

## Installation

1. Install REFramework and _CatLib if you do not have them.
2. Copy `talisman_editor.lua` into `reframework/autorun/` inside your game folder.
3. Start the game and load your save.
4. Open the REFramework menu (Insert by default) and find **Talisman Editor** in the script list.

To uninstall, delete `talisman_editor.lua`.

## How to use it

1. Load into the game first. The editor needs the equipment box, and it shows a notice until that is loaded.
2. Open Talisman Editor in the REFramework menu. Search for a talisman, then expand it.
3. Pick skills, levels and slots. The talisman name in the list updates as you edit.
4. Open your loadout/equipment screen to see the result. If a change does not show up, close and reopen the screen.

By default only talismans with at least two skills are listed. Tick "Include talismans with fewer than 2 skills" to see the rest.

## Compatibility

It is meant for single-player use. Do not use edited talismans in online or multiplayer sessions.

## Known issues

- **Weapon slot level.** The editor treats the first slot digit as the weapon slot level when a weapon slot is present. That reading comes from how Talisman Analyser decodes the value. Check one talisman before editing many.
- **Skill list.** The list comes from scanning the game's skill names, so it can include skills a talisman cannot normally hold (for example armor series or group skills). Stick to skills that appear on normal talismans.
- **Skill levels.** The slider goes up to 5. The game may clamp or ignore a level above a skill's maximum.

## Troubleshooting

- **"Equipment box not loaded yet"**: load into the game and wait for the save to finish loading.
- **Menu missing**: check that `talisman_editor.lua` sits in `reframework/autorun/` and that REFramework shows no script errors. A missing _CatLib is the usual cause.
- **List is empty**: you may have no talismans with two or more skills. Tick the "fewer than 2 skills" option.
- **Skill names look wrong**: the names follow your in-game language setting.

## Credits

- [praydog](https://www.nexusmods.com/profile/praydog?gameId=6993), for REFramework.
- [lingsamuel](https://www.nexusmods.com/profile/lingsamuel?gameId=6993), for [_CatLib](https://www.nexusmods.com/monsterhunterwilds/mods/65), and for [Artian Editor](https://www.nexusmods.com/monsterhunterwilds/mods/196), which this script is modeled on.
- [DavidLight](https://www.nexusmods.com/profile/DavidLight?gameId=6993), for [Talisman Analyser](https://www.nexusmods.com/monsterhunterwilds/mods/4472), and [Ninull](https://www.nexusmods.com/profile/ninull?gameId=6993), for [Talisman Data Export (mhwilds.wiki-db.com)](https://www.nexusmods.com/monsterhunterwilds/mods/3652), whose decoders showed how talisman skills and slots are stored.
