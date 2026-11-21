---
name: gridlines
description: "Draw vertical guide lines down an interface, find every item that misses its line, and fix paddings so sidebars, toolbars, panels, menus, dialogs and tables share a small set of edges. Covers icon columns, text lines, box lines, section headers, nested items, trailing columns, toolbar centre lines and optical corrections. Use when asked to align, fix padding or margins, do the gridline or margin exercise, polish spacing across pages, or when a layout 'looks off' and the cause is edges. Triggers on: gridlines, guide lines, margin exercise, alignment pass, optical alignment, edges don't line up, padding is off, sidebar alignment, toolbar alignment, icon column, Karri, Linear sidebar."
---

# Gridlines

Draw the lines first, then move the items. An alignment pass done by eye drifts by 2 to 4px per panel and nobody can say which edge was meant. Done with guides, every container ends up with two or three named lines, and every item either sits on one or has a written reason not to.

Source: Karri Saarinen's redraw of the Linear sidebar (dashed guides through the traffic lights, icon column, label line and trailing column) and his rules: rhythm is either edge positioning or centring, the top bar is centred on the window controls, the side panel has one padding with icons on one column, and shapes are either round or rectangular. Apple's HIG layout chapter is the backing reference: consistent margins, one alignment per group, controls centred on the toolbar line.

This skill owns horizontal edges and the vertical centre of rows. Row height and section spacing follow the project's density rules; hit areas and type size belong to other skills.

## Before you start

1. Read the project's design policy. If it records edge lines (for example "text sits 16px in, controls 8px in"), those values are the target. Do not re-derive them and do not change them without the owner's approval.
2. Run the app locally and use real data where possible. Empty and logged-out states hide most of the rows that misalign. If you can only see empty states, say so in the report.

## Process

Walk these steps in order on every page, panel and overlay in scope.

### 1. Draw

Inject `probe.js` (in this folder) and call `window.__gridlines()`. Two ways:

- **Headless:** `PW_DIR=<dir with playwright> node <this skill's folder>/audit.mjs <url> .gridlines [width] [prep.mjs]`. If Playwright is missing, install it into a scratch folder (`npm i --prefix <scratch> playwright`) and point `PW_DIR` there. If its browser isn't downloaded, run `npx playwright install chromium`, or set `CHROMIUM_PATH` to an existing Chromium build. A `prep.mjs` exporting `async (page) => {}` opens the menu, tab or dialog to measure.
- **Live browser:** paste `probe.js` into the page with the browser tool's evaluate, then call `window.__gridlines()`.

Measure at 1440px and at 390px. Open every overlay the page owns: menus, selects, popovers, dialogs, sheets, the command palette. Save every capture under `.gridlines/` in the project and keep that folder out of version control.

The probe measures ink, not boxes: a text run's glyph bounds, an icon's SVG bounds, and for a boxed control (fill, full border or shadow) the box itself. It draws, per container: the **lead line** (first ink in text rows) and the **label line** (first text after a leading icon) in solid red, the **box line** in faint red, the **icon-column centre** in fainter red, the **trailing line** in blue, and the **trailing centre** in amber.

### 2. Read

For each container, write down its lines from the summary: lead, box, icon centre, label, trailing, trailing centre. Then list every `MISS` row: which item, which edge (`leading`, `label`, `icon-column`, `trailing`, `vertical-centre`), how far off, which line it should be on. Look at the capture too; the probe groups rows by centre and can mis-assign an item, so confirm each miss by eye before acting on it.

### 3. Decide the lines

For each container, walk this tree:

```
Does the project policy name this container's lines?
├── Yes → use them. Stop.
└── No
    ├── Does it share an edge with a neighbour (stacked panels, toolbar over table)?
    │   └── Yes → take the neighbour's line. Shared edges get one line.
    └── No → take the line most rows already sit on. Move the minority.
```

Then classify every row as edge-positioned or centred. A row is never in between: an item that sits 3px off-centre and 5px off the edge belongs to neither and reads as a mistake.

### 4. Fix

- Move the outlier, never the majority. If 9 rows sit at 8px and the tab strip sits at 20px, the tab strip moves.
- Fix in the container: its padding, or a shared inset variable (`--row-inset`, `--table-inset`) that the rows and the header both read. Never fix with a one-off margin on a single item (`ml-[3px]`), because the next row added to that container will miss again.
- Use the project's spacing tokens. If the line needs a value off the scale, the container's padding is wrong, not the scale.
- When you remove a padding someone chose on purpose (a code comment explains it), update the comment with the new reason.

### 5. Re-draw

Run the probe again on the same states. Pass: every item within 1px of its line. The 1px allowance is the glyph's side bearing; 2px or more is a miss. Check the 390px width did not break: wrapped toolbars must still end on the trailing line.

### 6. Record and report

Record any new line in the project's design policy, in the same section as the existing edge rules, with the date and who set it. Report a table per page (where, before, after), the guide captures inline, and a "not covered" list: states you could not reach, and gaps you left on purpose.

## The rules

### Two leading lines per container: text and box

Every container has one **text line** (labels, headings, values, bare icons) and at most one **box line** (buttons, selects, inputs, pills, chips). When a boxed control sits at the edge, inset the box so its own label lands on the text line: box line = text line minus the box's horizontal padding. With a 16px text line and 8px button padding, the box sits at 8px and nests in the corner while its label continues the text above it.

Why: readers track the text, not the boxes. A box aligned to the text line pushes its label inward and breaks the column; a box nested in the corner keeps the column.

### Sidebars and lists: icon column, then text line

- **Icons sit on one column.** Left-align them on the box line, or centre them on one vertical line. Pick one per sidebar. Different icon widths (a 14px dot beside a 20px glyph) must centre on the column, never left-align, or the labels after them stagger.
- **Labels start on one text line**, after the icon column plus the gap. Every row: nav items, the workspace switcher, favorites, teams.
- **Section headers ("Workspace", "Favorites") start on the icon column's leading edge**, not on the label line. The header owns the group; starting it to the left of the labels says so.
- **Nested items indent by exactly one column**: the child's icon sits where the parent's label starts. Children without an icon start their label on the child text line, not on the parent's. Never indent by an arbitrary 12 or 20px.
- **A logo or avatar larger than the icon column** starts on the box line and still puts its name on the text line. Size the gap after it, not the text line.
- **Trailing badges and counts** sit on the trailing line or on the trailing centre line, the same one as the toolbar buttons above them.

Why: Linear's redraw has one line through the icons, one through the labels, and one through every trailing item from the history clock to the compose button to the inbox count. That is the whole sidebar; nothing floats.

### Top bars and toolbars: one centre line

- Every item in a bar centres on one horizontal line. Measure centres, not tops: a 24px button and a 16px icon in the same bar must share a centre.
- In a desktop app window, that line is the window controls' centre (the traffic lights on macOS). The app's first bar aligns to them or is vertically centred with them.
- The bar's first item starts on the container's text or box line, and its last item ends on the trailing line or centres on the trailing centre line. A toolbar is a row of the panel below it, not its own grid.
- Trailing controls of different widths (a count badge, a 28px icon button, a 20px icon) centre on one vertical line. Same-width controls align their trailing edge.

### Panels and the frame

- Panels that share an edge share the line: the filters on a table toolbar end exactly under the trailing edge of the panel above.
- The window frame (navbar, status bar) gets its own line from the window edge, shared by the first and last item of every frame bar.
- Inside one product area, every panel uses the same text line. Different areas may differ (dense data panels at 8px, settings pages at 16px) when the policy says so.

### Optical corrections

- **Align the content, not the affordance.** When a select's label must end on a trailing line, put its chevron before the label. A chevron or caret on the line pushes the label off it.
- **Invisible borders count.** A transparent 1px border offsets the label by 1px; take it back with a -1px margin on that side.
- **Icon viewBox padding counts.** A 24px icon drawn in a 20px area sits 2px in from its box. Measure the glyph; correct with the icon's size or the column, not per row.
- **Tabs align their label, not their hit area.** Drop the tab list's padding and pull the strip in so the first label's ink sits on the text line.
- **Round shapes look smaller.** A circle on a line overhangs it by about 1px compared with a square of the same size; a play triangle centres on its visual mass, about 1px toward the point.
- **Text side bearing is 0 to 1px.** Never correct it per glyph.

### Shapes

Buttons and fields in one container are either all rounded rectangles or all pills (fully round). Mix only for one special control, such as the single primary compose button, and say why in the policy.

Why: two shape families in one bar read as two systems, and the eye compares their edges instead of reading their labels.

## What never changes in this pass

- Row heights, hit areas and control sizes that the policy approves. If closing a gap needs one of them, leave the gap, note its size, and ask.
- Semantic elements and behaviour. This is a padding pass.
- Colours, type sizes and radii.

## Common mistakes

- **Fixing by eye.** Without guides, a 2px miss looks fine on one row and wrong on the page. Always draw first.
- **Moving the majority to the outlier.** The line is where most rows already are, unless the policy says otherwise.
- **Per-item nudges.** `ml-px` on one label is a fix that the next row added to that container will not inherit.
- **Measuring boxes instead of ink.** A button's box at 8px with its label at 16px is correct, not a miss.
- **Auditing empty states only** and reporting the page as aligned.
- **Centring the top bar on the bar** when the window controls sit higher or lower than the bar's middle.

## Checklist

- [ ] Policy's recorded lines read first, used as the target
- [ ] Guides drawn at 1440px and 390px, overlays opened, captures in `.gridlines/`
- [ ] Every container has a named text line, box line and trailing line
- [ ] Every row is edge-positioned or centred, nothing in between
- [ ] Sidebar: icon column, text line, headers on the icon edge, children indented one column
- [ ] Bars: one centre line, aligned to the window controls in desktop apps
- [ ] Fixes made in container padding or shared inset variables, not on single items
- [ ] Re-drawn: every item within 1px of its line
- [ ] New lines recorded in the policy; report lists what was not covered
