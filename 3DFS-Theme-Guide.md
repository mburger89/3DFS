# 3DFS Theme Guide

3DFS supports custom themes defined in **JSON** or **YAML** files. Themes control every color in the 3D world — volume faces, text, backgrounds, and more.

---

## Getting Started

1. Create a `.json` or `.yaml` file using the format below
2. Open 3DFS and click the **🎨 palette icon** in the toolbar
3. Choose **Import Theme…** and select your file
4. Your theme is saved to `~/Library/Application Support/3DFS/Themes/` and will appear in the menu on every launch

---

## Color Format

All colors are hex strings in `#RRGGBB` or `#RRGGBBAA` format.

| Format | Example | Meaning |
|---|---|---|
| `"#RRGGBB"` | `"#FF0000"` | Fully opaque red |
| `"#RRGGBBAA"` | `"#FF000080"` | 50% transparent red |

> **Important:** In YAML files, hex colors must be quoted because `#` starts a comment.  
> ✅ `background: "#FF0000"` — correct  
> ❌ `background: #FF0000` — `#FF0000` is treated as a comment, value becomes empty

---

## Full Schema

### JSON

```json
{
  "name": "My Theme",

  "scene": {
    "background": "#080B12",
    "bottomFace": "#0A0A0A"
  },

  "directory": {
    "sideBackground": "#0F1421",
    "sideBorder":     "#334DBF99",
    "nameText":       "#FFFFFF",
    "subtitleText":   "#8C8C8C",
    "childText":      "#8DBFFF",
    "moreText":       "#595959",
    "topColor":       "#2E60D1",
    "topEmission":    "#0D1F66"
  },

  "file": {
    "sideColor":       "#0F1A14",
    "topBackground":   "#0F1F16",
    "topBorder":       "#338C4D80",
    "badgeText":       "#59D980",
    "badgeBackground": "#1A4D26",
    "nameText":        "#FFFFFF",
    "typeText":        "#8CD98A",
    "sizeText":        "#BFBFBF",
    "dateText":        "#666666"
  }
}
```

### YAML

```yaml
name: "My Theme"

scene:
  background: "#080B12"
  bottomFace: "#0A0A0A"

directory:
  sideBackground: "#0F1421"
  sideBorder: "#334DBF99"
  nameText: "#FFFFFF"
  subtitleText: "#8C8C8C"
  childText: "#8DBFFF"
  moreText: "#595959"
  topColor: "#2E60D1"
  topEmission: "#0D1F66"

file:
  sideColor: "#0F1A14"
  topBackground: "#0F1F16"
  topBorder: "#338C4D80"
  badgeText: "#59D980"
  badgeBackground: "#1A4D26"
  nameText: "#FFFFFF"
  typeText: "#8CD98A"
  sizeText: "#BFBFBF"
  dateText: "#666666"
```

---

## Field Reference

### `scene`

Controls the world environment.

| Field | Affects |
|---|---|
| `background` | The void behind and around all volumes |
| `bottomFace` | The underside of every volume (rarely visible) |

### `directory`

Controls how folder volumes look.

| Field | Affects |
|---|---|
| `sideBackground` | Background fill of the four side faces |
| `sideBorder` | Outline drawn around each side face (supports alpha) |
| `nameText` | Folder name displayed near the top of each side |
| `subtitleText` | Item count line below the name |
| `childText` | The list of child item names |
| `moreText` | The "+ N more…" overflow indicator |
| `topColor` | Flat color of the top face |
| `topEmission` | Emissive glow added on top of `topColor` — use a darker shade for subtle depth |

### `file`

Controls how file tiles look. Files show their metadata on the **top face only** — sides are a plain color.

| Field | Affects |
|---|---|
| `sideColor` | Solid color of the four side faces |
| `topBackground` | Background fill of the top face |
| `topBorder` | Outline around the top face (supports alpha) |
| `badgeText` | File extension label (e.g. `SWIFT`, `PDF`) |
| `badgeBackground` | Pill background behind the extension badge |
| `nameText` | Filename displayed on the top face |
| `typeText` | Human-readable file type (e.g. "Swift Source") |
| `sizeText` | File size in KB / MB / GB |
| `dateText` | "Modified …" date line |

---

## Built-in Themes

These ship with 3DFS and can be used as starting points.

### Default

Dark blue-gray world. Directories are navy blue, files are dark green.

```yaml
name: "Default"

scene:
  background: "#080B12"
  bottomFace: "#0A0A0A"

directory:
  sideBackground: "#0F1421"
  sideBorder: "#334DBF99"
  nameText: "#FFFFFF"
  subtitleText: "#8C8C8C"
  childText: "#8DBFFF"
  moreText: "#595959"
  topColor: "#2E60D1"
  topEmission: "#0D1F66"

file:
  sideColor: "#0F1A14"
  topBackground: "#0F1F16"
  topBorder: "#338C4D80"
  badgeText: "#59D980"
  badgeBackground: "#1A4D26"
  nameText: "#FFFFFF"
  typeText: "#8CD98A"
  sizeText: "#BFBFBF"
  dateText: "#666666"
```

---

### Vapor Wave

Deep purple void. Hot pink directory tops, cyan child text, neon green file badges.

```yaml
name: "Vapor Wave"

scene:
  background: "#0D0221"
  bottomFace: "#08011A"

directory:
  sideBackground: "#1A0533"
  sideBorder: "#FF71CE99"
  nameText: "#FFFFFF"
  subtitleText: "#B967FF"
  childText: "#01CDFE"
  moreText: "#6600CC"
  topColor: "#CC1177"
  topEmission: "#660033"

file:
  sideColor: "#0D1A1A"
  topBackground: "#0D1F26"
  topBorder: "#05FFA180"
  badgeText: "#05FFA1"
  badgeBackground: "#0A2918"
  nameText: "#FFFFFF"
  typeText: "#05FFA1"
  sizeText: "#FFFB96"
  dateText: "#B967FF"
```

---

### Forest

Dark woodland. Muted greens throughout, warm off-white text.

```yaml
name: "Forest"

scene:
  background: "#0A140A"
  bottomFace: "#060D06"

directory:
  sideBackground: "#0F2010"
  sideBorder: "#4A8C2A99"
  nameText: "#E8F5E8"
  subtitleText: "#7AB87A"
  childText: "#A8D88A"
  moreText: "#3D6B3D"
  topColor: "#2D5A1B"
  topEmission: "#142A0A"

file:
  sideColor: "#0A1A10"
  topBackground: "#0F2618"
  topBorder: "#5AAD3380"
  badgeText: "#7AD95A"
  badgeBackground: "#1A3D10"
  nameText: "#F0FFF0"
  typeText: "#8AD870"
  sizeText: "#C8D8B8"
  dateText: "#5A7A5A"
```

---

### Midnight

Near-black with barely visible dark indigo accents. Minimal and silent.

```yaml
name: "Midnight"

scene:
  background: "#000005"
  bottomFace: "#000000"

directory:
  sideBackground: "#05050F"
  sideBorder: "#1A1A4D99"
  nameText: "#C8C8FF"
  subtitleText: "#4D4D80"
  childText: "#3D3D99"
  moreText: "#2B2B4D"
  topColor: "#0D0D33"
  topEmission: "#05051A"

file:
  sideColor: "#050510"
  topBackground: "#05050F"
  topBorder: "#1A1A4D80"
  badgeText: "#3D3D99"
  badgeBackground: "#05050D"
  nameText: "#B8B8E8"
  typeText: "#3D3D80"
  sizeText: "#666680"
  dateText: "#2B2B4D"
```

---

## Tips

**Start from a built-in theme** — copy one of the examples above and tweak a few colors at a time rather than building from scratch.

**Use alpha for borders** — `sideBorder` and `topBorder` look best with some transparency (`80`–`CC` in the alpha channel) so the edge glow blends into the face color rather than cutting hard.

**Keep `topEmission` darker than `topColor`** — the emission value is added on top of the base color. If it's brighter it will wash out the lighting and make the top face look flat.

**High contrast text matters** — `nameText` and `sizeText` should have strong contrast against `sideBackground` / `topBackground` so they're legible when viewed at an angle.

**Test at depth** — the scene has directional lighting, so colors appear slightly darker on some faces. A color that looks good in a color picker may need to be lightened slightly to read well in the 3D view.

---

## Sharing

Theme files are plain text — share them as `.yaml` or `.json` files. Anyone with 3DFS can import them using the **🎨 → Import Theme…** menu.
