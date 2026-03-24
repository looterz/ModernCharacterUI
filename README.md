# Modern Character UI

High-resolution UI for the character, dressing room, and inspect windows with Midnight-style design and quality of life features

### Character Panel
- 3x larger window with a clean design inspired by the new Midnight UI
- Per-slot item level, quality-colored borders, gem/socket indicators, cooldown overlays
- Click your name to change title, specialization shown in subtitle
- Equipment Manager tab to save, load, rename, and delete gear sets
- PvP Item Levels show for items and your character while in PvP content
- Reputation tab with search, filters, color-coded standing bars, and detail panel
- Currency tab with search, filters, backpack tracking (Shift+click), and transfer log
- Movement Speed tracking based on stats and the current movement mode

![Character Panel](https://media.forgecdn.net/attachments/1596/780/wowscrnshot_032426_095429-jpg.jpg)

![Character Panel PvP Mode](https://media.forgecdn.net/attachments/1596/777/wowscrnshot_032426_095701-jpg.jpg)

![Reputation Tab](https://media.forgecdn.net/attachments/1596/779/wowscrnshot_032426_095435-jpg.jpg)

![Currency Tab](https://media.forgecdn.net/attachments/1596/778/wowscrnshot_032426_095442-jpg.jpg)

### Dressing Room
- Full Transmog-style 3-panel layout with outfit list, character preview, and built-in appearances browser
- 5x6 model grid with search, source filters, and paging
- Weapon category dropdown and class filter to browse appearances for any class
- Click any appearance to preview it instantly; previewed items are highlighted with page navigation
- Click equipment slots to browse appearances, right-click to undress
- Save and load custom outfit sets
- Click any item slot being previewed to view it in your collection instantly
- Mount preview mode with 3D model browser, search, and paging across all mounts in the game
- Ctrl+click any mount link or click the Mounts button to browse and preview mounts

![Dressing Room](https://media.forgecdn.net/attachments/1596/79/wowscrnshot_032326_213949-jpg.jpg)

![Mount Preview](https://media.forgecdn.net/attachments/1596/249/wowscrnshot_032426_002658-jpg.jpg)

### Inspect Window
- Same design as the character panel with 3D model and 18 equipment slots
- Item level, specialization, and class-colored name display
- Character, PvP, and Guild tabs matching the legacy inspect window
- View in Dressing Room and View Talents buttons
- PvP tab shows honor level, arena ratings, solo shuffle, RBG, and blitz ratings
- Guild tab shows tabard, name, faction, rank, and member count

![Inspect Window](https://media.forgecdn.net/attachments/1595/666/wowscrnshot_032326_135611-jpg.jpg)

### Quality of Life
- Combat lockout option to prevent Character window from opening mid-fight
- Optional enchant status and upgrade track overlays on equipment slots
- Configurable window scaling (50-200%) for Character Panel, Inspect, and Dressing Room
- Preview any item in the dressing room and then click the item slot to view it in your collection
- Inspect another class and browse their collection in the dressing room with automatic class filtering
- Search & Filter support for the Reputation and Currency tabs to quickly find what you need
- Preview mounts in the dressing room with a dedicated mount browser, search, and paging across all mounts in the game
- All windows remember their position between sessions

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/modern-character-ui) or [GitHub](https://github.com/looterz/ModernCharacterUI).
2. Place the `ModernCharacterUI` folder in your `Interface\AddOns` directory.

## Configuration

`/mcu` or Interface > AddOns > Modern Character UI.

- **Override Legacy Character Panel**: On
- **Override Legacy Dressing Room**: On
- **Override Legacy Inspect Window**: On
- **Block Opening in Combat**: On
- **Show Enchant Status**: Off — displays an indicator on enchanted equipment slots
- **Show Upgrade Track**: Off — displays upgrade progress (e.g. 2/6) on equipment slots
- **Character Panel Scale**: 50-200% (default 100%)
- **Inspect Window Scale**: 50-200% (default 100%)
- **Dressing Room Scale**: 50-200% (default 100%)

## Commands

- **`/mcu`**: Open settings
- **`/mcu character`**: Toggle character panel
- **`/mcu dress`**: Toggle dressing room
- **`/mcu mounts`**: Open mount preview

## Feedback and Support

Found a bug or have a suggestion? Visit the [issue tracker](https://github.com/looterz/ModernCharacterUI/issues) on GitHub.

## Contribution

Pull requests are welcome on the [GitHub repository](https://github.com/looterz/ModernCharacterUI).

## License

Released under the [MIT License](https://github.com/looterz/ModernCharacterUI/blob/main/LICENSE).
