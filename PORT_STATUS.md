# Port status (Godot 4.7 port of the PvZ QE-Wide decomp)

Approach: faithful 1:1 translation of the decomp C++ (`C:\Users\nik\Music\PVZ-QEWide-Tweaks-main`) to GDScript,
snake_case names, same logic/constants. Minigames, survival and puzzle modes are out of scope for now
(their code paths may exist as stubs).

Tools:
- `python tools/port_coverage.py [Class...]` lists decomp methods with no snake_case GDScript counterpart
  (generic names like Draw/Update give false "covered" results for widgets).
- `godot --headless --path . -s tools/check_scripts.gd` compile-checks every script
  (`App` autoload errors in this mode are expected).
- `godot --headless --path . -s tools/verify_defs.gd` parses every compiled reanim/particle/trail.
- `godot --headless --path . res://tools/check_all.tscn` compile-checks every script with the App autoload active.
- `godot --headless --path . res://tools/smoke_test.tscn` drives App through every menu, dialog and screen
  (with a mouse sweep over each) plus a 1-1 intro; any `SCRIPT ERROR` in the log is a regression.
- `godot --path . res://tools/capture_screens.tscn -- <dir>` (windowed) saves PNGs of the menus/dialogs for visual checks.
- `godot --path . res://tools/capture_menu.tscn -- <dir>` (windowed) saves PNGs of just the main menu (intro, idle, hovers,
  locked profile, achievements slide).

Community edition multiplayer (main menu > Social, unlocked by finishing Adventure; code in src/net):
- ENet over localhost / LAN / Radmin VPN / Hamachi, default port 24642. Host or join (IP + port) from NetConnectDialog;
  the lobby (NetLobbyScreen) has chat, Co-op (2-4 players, any Adventure level) or Versus (1v1), then everyone picks
  loadouts at once (NetChooserScreen; Co-op picks are unique per player, x-5 / x-10 levels skip picking).
- Matches are deterministic lockstep (NetSession): only clicks are sent; the host stamps them with a frame and streams
  frame batches, every board steps with `Tod.rng` swapped to the match RNG, and board checksums are compared every
  100 frames; a drifting client is rebuilt from a SaveGame snapshot (`SaveGame.snapshot_to_bytes`). Anything the
  simulation reads from the app (profile purchases, cheats, fun modes, auto-collect) is pinned for the match.
- Board hooks: `Board.net_*` (per-player seed banks + cursors, click replay, Versus sun swap), `NetVersus` (red line,
  zombie / grave packets, purple zombie sun via shader filter 4, stationary screen-door target zombies, win rules).
- Anyone leaving (button, closing the game, timeout) ends the lobby for everyone with a message.
- `python tools/net_test.py <godot_console.exe> coop|versus <seconds> [corrupt|clientleave|hostend]` runs a headless
  host + client that auto-play and compares their checksums (corrupt = forces a desync to test the resync).
- `godot --path . res://tools/capture_net.tscn -- <dir>` screenshots the multiplayer screens with a pretend player.

Community edition main menu (mod, replaces the reanim selector scene; menu logic unchanged):
- `python tools/crop_menu_sprites.py [sheet.png]` cuts the menu spritesheet into `assets/crop/` (text the game draws itself is
  painted out; `_highlight` copies for clickable sprites). Run Godot's import afterwards.
- `python tools/menu_layout/build_layout.py` generates `src/screens/main_menu_layout.gd` (positions matched to the mockup,
  in 2134x1200 design pixels drawn at 0.6); `python tools/menu_layout/preview.py [out.png]` renders it without Godot.
- Achievements / Quick Play / Credits are stone bars in the 16:9 area right of the mockup; the Tree of Wisdom stump opens
  the tree once it is bought; shop, almanac, zen garden and quick play stay hidden until unlocked, as before.

Community edition level editor (main menu > Level Editor; code in src/editor):
- A PvZ-styled editor screen (`EditorScreen`) with a tab rail and one `EditorPanel` per tab, drawn with the game's own
  fonts, stone buttons and parchment frames like the multiplayer screens. Panels: Levels (browse / new / copy / delete /
  import / export / play), Level (name, author, rules, win conditions, balance, music), Lawn, Waves, Seeds, Crazy Dave,
  Art & Reskins, Plant Maker, Zombie Maker, Boss Maker, Scripting.
- `LevelDef` is the whole level as data; `CustomLevels` saves each level to its own folder under
  `user://custom_levels/<id>/` with its art beside it, and imports/exports a level and its art as one file.
- Lane type is deliberately separate from how a lane looks (`LevelDef.row_type`, per-cell overrides): marking a lane as
  water/high ground/blocked changes only the rules, never the picture, so a custom background can mix pool, roof and
  grass however it likes. Built-in backgrounds still draw their own lanes, so the editor warns when the two disagree.
- `CustomAssets` copies imported .reanim/.png/audio into the level folder and installs them only while that level is
  open or playing; `CustomDefs` builds plant/zombie definitions (and seed types) for the level's own plants and zombies,
  including per-part reanim skins, and tears them down again on exit. A custom zombie's or boss's own .reanim is
  swapped in by `Zombie.load_reanim`, so everything that poses it afterwards poses the custom art.
- `LevelScript` is a Scratch-style block language (events, control, actions, queries, variables) edited on the Scripting
  tab and run by `CustomRuntime`, which also drives waves, the boss fight, Crazy Dave's lines and the win checks.
- `CustomRuntime` attaches to `Board` through the `custom_level()` hooks in board_core/board_update, so a custom level
  runs on the real board with no special-casing in the game code.
- Plants and zombies a level defines are unlocked for that level: `App.has_seed_type` says yes to any custom seed type,
  and the seed chooser lists them after the stock 49 (`chooser_seeds` / `chooser_slot`, so `chosen_seeds` stays indexed
  by seed type).
- `godot --headless --path . res://tools/editor_test.tscn` builds a level, draws every tab, saves/loads/exports/imports
  it, plays it and checks the custom plants, zombies, waves and scripts behave, then exercises wheel and scrollbar
  scrolling, two edge-case lawns (one with no lane a land zombie can use, one with no lanes at all), a conveyor level
  and a custom plant in the seed chooser; any failure prints and exits non-zero.
- `godot --path . res://tools/capture_editor.tscn -- <dir>` (windowed) screenshots every tab plus a level running.

Platforms (src/core/platform.gd):
- Windows is the full build. The Web and Android presets in `export_presets.cfg` ship the same game
  minus multiplayer: the netcode is deterministic lockstep over ENet on a LAN, which a browser cannot
  open sockets for and a phone has no way to reach, so `Platform.supports_multiplayer()` is Windows
  only and the main menu greys Social out and answers a tap with `[MULTIPLAYER_WRONG_DEVICE]`.
- `Platform.is_mobile()` covers a native Android build and a browser on a phone or tablet (Godot
  reports "Web" for both, so it asks the page via `web_android` / `web_ios` / touchscreen).
- On mobile the lawn is presented non-widescreen: `App.update_presentation()` narrows the box the
  engine fits to the window from 1280x720 to 1040x720, which scales the picture up about 23% where
  it would otherwise letterbox. What falls off is the widescreen street margin the board never puts
  anything on, and the HUD that hugs that edge moves in by `App.board_view_crop`
  (`Board.relayout_hud()`). Menus keep the full 1280 - they are drawn corner to corner.
- `--mobile` on the command line forces that layout on a desktop build for a look at it.
- `godot --headless --path . res://tools/platform_test.tscn` checks the multiplayer gate and that
  nothing in the lawn HUD falls off screen in the mobile view.
- `godot --path . res://tools/capture_mobile.tscn -- <dir>` screenshots the menu and the lawn on a
  desktop window and on a 4:3 "tablet" window with the phone layout forced on.

Conventions:
- IDs (ZombieID, ReanimationID...) are object references; `freed` marks deleted objects;
  `BoardCore.try_get`, `Zombie.zv`, `Plant.rv` replace DataArrayTryToGet.
- Blocking `WaitForResult` / `LawnMessageBox` are coroutines: `await dialog.wait_for_result(true)`.
- Rendering is immediate mode through `Graphics` -> `RenderTarget` canvas-item segments.
- The mouse wheel goes to the widget under the pointer and bubbles to its parents, falling back to the focus widget;
  `Widget.mouse_wheel` returns true when it consumed the event.

Done: core (res, defs, reanim, particles, trails, attachments, fonts, strings, music, foley, languages),
widgets (incl. ListWidget, Widget::Layout, ShowFinger), board (core/update/input/draw), plant, projectile, coin,
seed bank/packet, grid items, mowers, zombie (all types + boss), app (LawnApp), cut scenes, challenge (adventure parts),
zen garden, save game, pool effect, achievements, typing checks.
Screens/dialogs: TitleScreen, GameSelector, QuickPlay, SeedChooserScreen, StoreScreen, AwardScreen, AlmanacDialog,
NewOptionsDialog (+ 4 advanced pages), CreditScreen (music video, synced to the song), MiniCreditsScreen, AchievementScreen,
ChallengeScreen, ChallengePagesDialog, UserDialog, NewUserDialog, ContinueDialog, CheatDialog, GameOverDialog.
All scripts compile; the smoke test runs clean.

Intentionally skipped: ImitaterDialog (never created in the QE build; the seed chooser picks the imitater inline),
DRM/Discord/update checks, resource packs (none ship; the options page shows "no resource pack").

Todo: playtesting adventure 1-1 through 5-10 against the original (visual/timing diffs), minigames/survival/puzzle
gameplay (out of scope for now; their screens exist), Godot-native animation support alongside reanims for future content.
