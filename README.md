# MacUI

A compact Roblox UI library inspired by macOS and Raycast. Native GUI elements, acrylic surfaces, world blur, a command palette, notifications and the active Roblox account profile. Supports executors and normal LocalScripts through the same API.

## Executor

```lua
local MacUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ngducok/MacUI-luau/main/dist/MacUI.luau"))()
```

Requires an executor with `loadstring`, `game:HttpGet` and current Roblox GUI APIs. The bundle contains every library module; it does not download extra modules. Windows use `gethui()` when it returns a valid Instance, otherwise `LocalPlayer.PlayerGui`. An explicit `Parent` takes precedence. No files are written by default.

See [examples/executor.luau](examples/executor.luau) for a small working UI. **Right Shift** shows/hides the window; **Ctrl+K** opens the command palette. Click the sidebar profile to open Account.

## Roblox Studio

Put `src/shared/UILibrary` in ReplicatedStorage as a ModuleScript with its children, then require it from a LocalScript. The Studio source needs no executor APIs. If you rename the ModuleScript to `MacUI`, use `require(game.ReplicatedStorage.MacUI)`.

## Quick start

```lua
local MacUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ngducok/MacUI-luau/main/dist/MacUI.luau"))()

local Window = MacUI:CreateWindow({
	Size = UDim2.fromOffset(860, 520),
	ToggleKey = Enum.KeyCode.RightShift,
})

local Automation = Window:AddPage({ Id = "automation", Title = "Automation", Icon = "two-arrows-loop-clockwise" })
local Farming = Automation:AddSection({ Title = "Farming", Description = "Configure automated behaviours" })

local Farm = Farming:AddCard({
	Id = "auto-farm",
	Title = "Auto Farm",
	Description = "Collect rewards automatically",
	Toggle = true,            -- on/off switch in the card header
	Collapsible = true,
	Callback = function(on) print("Auto Farm", on) end,
})

Farm:AddSlider({ Id = "farm-range", Title = "Range", Min = 5, Max = 100, Default = 50 })
Farm:AddDropdown({ Id = "target", Title = "Target", Options = { "Nearest", "Lowest HP" }, Searchable = true })
Farm:AddButton({ Title = "Reset", Variant = "Destructive", Callback = function() end })

print(Window:GetFlag("farm-range"))  -- 50
```

## Structure

`Window → Page → Section → Card → Controls`

```
src/shared/UILibrary/
  init.luau              MacUI API: CreateWindow, SetTheme, RegisterTheme
  Core/                  Theme, Factory, Store, Registry, Animations, Blur, Input, Icons, Cleanup, Util
  Window/                Window, Sidebar, Account, Page, Section, DragResize
  Components/            Card, Control (base), Toggle, Slider, Dropdown, Button, Input,
                         Keybind, ColorPicker, Display (label/paragraph/status/progress/image/tooltip),
                         AnimatedImage
  Overlays/              PopupManager, CommandPalette, Notifications, Dialog
dist/MacUI.luau          standalone executor bundle
examples/executor.luau   minimal usage example
tools/build.mjs         dependency-free bundle builder
tools/test.project.json Studio test place mapping
tests/                  bundle checks and Studio UI tests
```

## API

### MacUI
| Call | Notes |
|---|---|
| `MacUI:CreateWindow(options)` | returns `Window` |
| `MacUI:SetTheme(name)` | `"Dark"`, `"Light"`, or a registered name |
| `MacUI:RegisterTheme(name, tokens)` | missing tokens fall back to Dark |
| `MacUI:SetReducedMotion(bool)` | skips tweens globally |

### CreateWindow options
| Option | Default |
|---|---|
| `Title`, `Subtitle` | Legacy options accepted for compatibility; the profile always shows `LocalPlayer.Name` and `"Account"` (or `"Account"` without a player). `SetTitle` cannot override account identity. |
| `Account` | `{ Enabled = true }`; legacy `UseLocalPlayer`, `DisplayName` and `Subtitle` options are accepted but cannot override player identity. |
| `Icon`, `AnimatedIcon` | Legacy window options accepted for compatibility; account portraits always use the local player's headshot, with a neutral person icon on failure. Card and control icon options still work normally. |
| `Size` | `UDim2.fromOffset(860, 520)` (larger preset: `900, 540`) |
| `MinSize` | `Vector2.new(720, 440)` |
| `ToggleKey` | `Enum.KeyCode.RightShift` |
| `Resizable`, `Draggable`, `Maximizable` | `true` |
| `Theme` | `"Dark"` |
| `Scale` | `1` for native text rendering; explicit overrides clamp to `0.6–1.5` |
| `AutoScale` | `true`: fit by resizing the layout first, with at most 5% automatic downscaling on small viewports. `false` uses `Scale` directly. Both modes constrain the window to the viewport. |
| `BlurEnabled`, `BlurSize`, `BlurTweenTime` | `true`, `14`, `0.18` seconds; size clamps to `0–56` |
| `Acrylic`, `BackgroundTransparency` | `true`, `0.1`; `Acrylic = false` uses an opaque surface. Settings groups and grid tiles use `0.04` transparency. |
| `ReducedMotion` | `false` |
| `PalettePreserveQuery` | `false`: reset each open. `true`: keep last query. `OpenCommandPalette(query)` overrides either mode. |
| `Persistence` | `{ Load = fn, Save = fn(data), Delay = 2 }` |
| `Parent` | `LocalPlayer.PlayerGui` |

Tab changes slide one selection pill between sidebar rows, lift the incoming page by 12 px, and fade in its title. Reduced motion applies the final state immediately. Window show/hide fades without scaling text; the settled panel renders outside the fade CanvasGroup to avoid persistent glyph resampling. Its native shadow stays within 16 px of the panel (plus a 6 px downward offset); no TopBar texture or separate highlight strip is used.

Blur affects the 3D world through `Lighting.BlurEffect`; Roblox does not provide per-window backdrop blur. Visible windows share one library effect, with the largest requested size winning. Hiding the last window fades it out; destroying the last window removes it. An existing effect named `UILibraryBlur` is restored to its original size and enabled state instead of being deleted. Other effects are left alone.

### Window
`Show()` `Hide()` `Toggle()` `IsVisible()` `Destroy()`
`SetMinimized(bool)` `SetMaximized(bool)` `SetToggleKey(key)` `SetTitle(title, subtitle)` `SetTheme(name)` `SetScale(n)` `SetReducedMotion(bool)`
`AddPage(options)` `GetPage(id)` `SelectPage(id)` `Back()` `Forward()`
`Notify({ Title, Content, Duration, Kind, Actions })` — `Kind` is `info | success | warning | error`, `Duration = 0` keeps it open; returns a close function
`Confirm({ Title, Content, ConfirmText, CancelText, Destructive, OnConfirm, OnCancel })`
`OpenCommandPalette(query?)` `AddHeaderAction({ Icon, Tooltip, Callback })`

Clicking the 48px sidebar profile row opens the built-in `account` page via `SelectPage("account")`. It uses normal Back/Forward history and one search/palette entry, with no extra category row. `Account.resolve` reads `LocalPlayer` when each window is created and shares username, display name and user ID between sidebar and page. The page shows a centered 80px avatar, username heading, `@Username` and read-only Profile rows. Portraits use `GetUserThumbnailAsync` with `HeadShot` / `Size420x420`, loading once per window in the background with a neutral fallback on failure. Without a local player, account details are marked unavailable.

`Account = { Enabled = false }` disables built-in account navigation and releases the reserved `account` page ID. `AddPage({ ..., Sidebar = false })` registers a page without a category row or initial selection. Page contents and scroll positions survive navigation.
`GetFlag(id)` `SetFlag(id, value)` `OnFlagChanged(id, fn)` `ExportConfig()` `ImportConfig(data)`

### Page
`AddPage({ Id, Title, Description, Icon, Badge, Group, Keywords, Build })`
- `Group`: pages with a different group number get a gap in the sidebar.
- `Badge`: short text such as `"NEW"`, `"BETA"`, or a count.
- `Build = function(page) ... end`: makes the page lazy. Its contents are created the first time it opens, or when search runs.

Methods: `AddSection(options)` `GetSections()` `EnsureBuilt()` `SetTitle(t)` `SetBadge(t)` `Destroy()`

### Section
`AddSection({ Title, Description, Layout = "List" | "Grid", Columns })`
- `List` (default): one rounded group with divider lines between rows, like Raycast.
- `Grid`: compact tiles, 1–3 columns depending on width. Clicking a tile opens its settings in a floating inspector.

Methods: `AddCard(options)` `GetCards()` `SetVisible(bool)` `Destroy()`

### Card
`AddCard({ Id, Title, Description, Icon, AnimatedIcon, Badge, Toggle, Default, Callback, Collapsible, DefaultExpanded, Keywords })`
- `Toggle = true` adds a header switch, stored as flag `"<Id>.enabled"`.

Controls: `AddToggle` `AddSlider` `AddDropdown` `AddButton` `AddInput` `AddKeybind` `AddColorPicker` `AddLabel` `AddParagraph` `AddDivider` `AddStatus` `AddProgress` `AddImage` `AddAnimatedImage`
Methods: `SetExpanded(bool, instant?)` `IsExpanded()` `SetVisible(bool)` `SetDisabled(bool)` `SetLoading(bool)` `SetBadge(text, kind?)` `SetTitle` `SetDescription` `GetEnabled()` `SetEnabled(bool)` `AddAction({ Icon | Text, Tooltip, Callback })` `Focus()` `GetControls()` `Destroy()`

Card height always follows its content; adding, removing or expanding controls resizes it.

### Controls
Every control has `GetValue()` `SetValue(v)` `SetDisabled(bool)` `SetVisible(bool)` `SetTitle(t)` `SetDescription(t)` `Destroy()`.
Controls with an `Id` store their value under that flag (`Window:GetFlag(id)`). `Callback` runs only when the value actually changes, inside a protected call, so a failing callback prints a warning and doesn't break the UI.

| Control | Options |
|---|---|
| Toggle | `Default`, `OnColor`, `OffColor` |
| Slider | `Min`, `Max`, `Default`, `Step`, `Suffix`, `Color` — values snap to `Step` and clamp to range |
| Dropdown | `Options` (strings or `{ Label, Value }`), `Default`, `Multi`, `Searchable`, `Width` · `SetOptions(list)` `GetOptions()` `Open()` `Close()` |
| Button | `Title`, `Variant` = `Primary | Secondary | Ghost | Destructive`, `Icon`, `Label` (puts the button on the right of a titled row) |
| Input | `Placeholder`, `Default`, `Validate(text) -> true | "error"`, `Clearable`, `Live`, `SubmitOnEnter`, `OnSubmit(text)`, `Width` · `Focus()` |
| Keybind | `Default` (KeyCode), `OnPress(key)` — click to capture, Esc cancels, Backspace clears; the window toggle key is refused |
| ColorPicker | `Default` (Color3), `Transparency` (0–1, enables the opacity bar) · `GetTransparency()` `SetTransparency(n)`; `Callback(color, transparency)` |
| Label | `Value` |
| Paragraph | `Content` |
| Status | `Value`, `Kind` = `Neutral | Success | Warning | Danger | Accent` · `SetValue(text, kind)` |
| Progress | `Value` 0–1, or `nil` for an indeterminate bar |
| Image | `Image`, `Height`, `ScaleType` |
| AnimatedImage | see below · `Play()` `Pause()` |

## Search

Every page, searchable card and titled control is added to one registry automatically. Hierarchical IDs stay stable when titles change; registering an existing ID replaces its record safely. Generic `Open`/`Button` actions are excluded unless explicitly indexed with `SearchTitle` or `Searchable = true`. Dashboard quick links use `Searchable = false` to avoid duplicate destinations.
- **Sidebar search box**: filters as you type; ↑/↓ move through results, Enter opens one.
- **Ctrl+K**: toggles the command palette. ↑/↓/Tab move, Enter opens, Esc or a click outside closes. Results show the icon, name, location and current state. Width is 560 px (at most 90% of the safe viewport); height follows results, with up to seven 42 px rows before internal scrolling. Empty searches stay compact.

Opening a result switches to its page, scrolls to the card, expands it and briefly highlights it. Use `Keywords` or `Aliases` (string or array) on pages, cards or controls to add search terms. Page/section/card paths are indexed too. Exact and prefix title matches rank first. Buttons use contextual names such as `Auto Farm: Reset`; `SearchTitle` overrides that name.

Palette text stays at native scale `1`, independently of the main window. A non-interactive `ScreenInsets.None` layer dims the full viewport; a higher `CoreUISafeInsets` layer positions controls safely. Both are removed after the 160 ms close fade. Opening reuses the window's input listener; settled text renders outside the temporary fade CanvasGroup.

## Themes

```lua
MacUI:RegisterTheme("Midnight", {
	Background = Color3.fromRGB(10, 12, 20),
	Sidebar = Color3.fromRGB(18, 20, 32),
	Surface = Color3.fromRGB(16, 18, 28),
	Accent = Color3.fromRGB(140, 120, 255),
})
Window:SetTheme("Midnight")
```

Token names are in `Core/Theme.luau`: `Background Sidebar Surface SurfaceHover SurfaceActive Border TextPrimary TextSecondary TextMuted TextDisabled Accent Success Warning Danger Palette PaletteBorder PaletteSelected PaletteDivider PalettePlaceholder Knob OnAccent Scrim`. Changing the theme recolours everything that already exists; nothing gets rebuilt.

### Typography

`Theme.Typography` centralizes Roboto `FontFace` and integer sizes. `Factory.text({ Typography = "Feature", ... })` applies a role; normal controls default to `Control`. Existing `Theme.Fonts`, `Theme.TextSize`, and explicit `FontFace`/`TextSize` overrides remain available.

| Role | Size | Weight |
|---|---|---|
| `WindowTitle` | 18 | SemiBold |
| `Navigation`, `Feature` | 14 | Medium |
| `Section` | 13 | Medium |
| `Control` | 13 | Regular |
| `Description` | 12 | Regular |
| `Hint` | 11 | Medium |
| `Search` | 14 | Regular |

Roblox's bundled Roboto family has no dedicated 600 face, so `FontWeight.SemiBold` resolves natively to an available weight. Japanese glyph fallback also stays with Roblox's text renderer; strings are preserved without byte slicing. Exact 600 rendering would require an uploaded font family.

Normal text uses `TextScaled = false`, full opacity and centered vertical alignment. Dark text colors are primary `(245,245,247)`, secondary `(178,178,184)`, muted `(143,143,151)` and disabled `(111,111,119)`. Disabled text retains its original theme/semantic binding and restores it on enable. Long headings truncate within their existing rows; descriptions retain content-driven wrapping. Desktop scale remains `1`; small-screen responsive scaling and existing press/entrance animations are preserved.

## Icons

Icons use **Builder Icons**, the icon font that ships with every Roblox client, so you don't upload anything. Pass a kebab-case name (`"gear"`, `"magnifying-glass"`, `"sword"`) or a PascalCase name (`"MagnifyingGlass"`). There are around 780 names; the list is in Studio's install folder under `ExtraContent/LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/Icon.lua`. Short aliases (`settings`, `search`, `combat`, `movement`, `visuals`…) are in `Core/Icons.luau`.

For your own images pass `"rbxassetid://…"`. For a coloured app-style tile pass `{ Icon = "sparkles", Tile = Color3.fromRGB(232, 58, 58) }`.

## Animated images (GIFs)

Roblox can't play GIF files. Convert the GIF to a sprite sheet: one image with every frame laid out in a grid.

1. Split the GIF into frames, for example with `ffmpeg -i in.gif frame_%03d.png`, or ezgif.com → "GIF to sprite sheet".
2. Pack the frames into a grid. ImageMagick: `magick montage frame_*.png -tile 4x -geometry +0+0 -background none sheet.png`
3. Keep the sheet at most **1024×1024**; Roblox downscales larger uploads and the frame offsets break. For example, 16 frames at 128 px is 4 columns × 4 rows = 512×512.
4. Upload `sheet.png` (Creator Hub → Decals or Images) and copy its asset ID.
5. Use it:

```lua
Card:AddAnimatedImage({
	Image = "rbxassetid://YOUR_ID",
	FrameSize = Vector2.new(128, 128),
	Columns = 4,
	Frames = 16,
	FPS = 12,
	Loop = true,
	Autoplay = true,
})
```

All animations share one Heartbeat connection. Hidden ones skip updates, and destroying one removes it from the scheduler. They also work as card icons (`AnimatedIcon = {...}`). Account avatars always use the Roblox player's headshot.

## Persistence

By default nothing is saved; values reset when the player leaves. To save, pass an adapter:

```lua
Persistence = {
	Load = function() return Remote:InvokeServer("load") end,
	Save = function(data) Remote:FireServer("save", data) end,
	Delay = 2,
}
```

`data` is plain JSON-safe tables; Color3 and EnumItem values are encoded. Client-side data can't be trusted: if values matter for gameplay, validate them on the server before saving them to a DataStore.

## Build and tests

Node.js 22.17+ builds the executor file without installing packages:

```sh
node tools/build.mjs
node --test tests/bundle.test.mjs
```

Bundle runtime tests require the Luau CLI on `PATH`, or `LUAU_BIN` set to its executable path. They check module paths, shared require cache, circular dependency errors, `gethui` success/failure, explicit parents and source/bundle consistency.

To run the UI suite in Studio, install Rojo 7.7.1 and build:

```sh
rojo build tools/test.project.json -o MacUI-tests.rbxlx
```

```lua
require(game.ReplicatedStorage.Shared.Tests)()
```

Open the test place and run this from the client command bar in Play mode. The suite covers controls, persistence, search, typography, layout, Account identity/navigation, traffic lights, blur ownership, animations and cleanup. Executor compatibility also depends on the host's supported Roblox APIs; compilation and bundle tests do not replace a live executor run.

The repository contains library source, the executor bundle, a small example, build tools and tests. Local Studio place files, preview plugins, screenshots, editor settings and temporary files stay out of Git.
