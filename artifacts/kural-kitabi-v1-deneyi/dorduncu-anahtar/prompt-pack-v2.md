# Dördüncü Anahtar — style-master v2 prompt paketi

Use case: `illustration-story`
Execution: built-in image generation, her panel ayrı çağrı.
Input images: Kabul edilmiş karakter sheet'leri kimlik referansıdır; v1 paneli yalnız karşılaştırma içindir ve görsel referans olarak kullanılmaz.

## Global style block

```text
Modern clean digital romance manhwa illustration. Thin delicate lineart with slightly varied line weight; muted low-saturation pastel palette; airy watercolor-gradient shading; realistic elegant body proportions; fine hair strands; expressive detailed eyes and subtle blush.

ENVIRONMENT RULE: draw the setting as an illustrated weekly-webtoon background, not as a photograph. Build architecture with clean economical contour lines, simplified correct perspective, large quiet color shapes and only a few intentional texture marks. Use two or three matte value groups. Reduce distant detail by omitting lines, never by lens blur. Rain is thin drawn strokes; wet ground has only a few short matte broken reflections.

CHARACTER INVARIANT: match the supplied accepted character sheets exactly. Do not redesign face, hairstyle, body proportions, outfit, accessories or color palette. Characters remain the sharpest and most detailed layer.

NO photorealism, no photobash, no photo texture, no 3D render, no hyper-detailed stone or brick, no glossy architecture, no mirror-like wet pavement, no cinematic depth-of-field, no bokeh, no lens flare, no film still, no dramatic color grading, no excessive bloom, no hard cel shading, no heavy black shadows, no screentone, no text, no letters, no logo, no watermark, no speech balloons.
```

## Register ekleri

```text
E: Show correct, readable place geometry and 3-5 landmark details, but keep every surface simplified, matte and visibly drawn. No micro-texture.
N: Keep only 1-3 location cues behind the acting. Use broad pale shapes and a few thin contours; most of the environment is intentionally omitted.
B: Reduce the background to a pale gradient, one location motif and sparse linework. A faint localized rim glow may touch only the emotional focal point; no full-frame bloom.
C: Flat cream background with a few comedic doodle symbols. No rendered environment.
```

## Panel-specific prompt suffixes

Her çağrıya global blok, ilgili scene block ve aşağıdaki tek suffix eklenir.

1. `P001 / E / wide 3:2` — Under the old stone inn arch, Selin protects her worn leather portfolio from rain while Mert enters holding his dark forest-green umbrella. Wide establishing composition, both full figures small enough to read the arch and narrow street. Keep an open pale area at upper left.
2. `P002 / N / portrait 2:3` — Over Selin's shoulder, Mert shows a second small antique brass key on his open palm. Waist-up acting; only the arch curve, one warm wall lamp and a broad pale wall shape remain behind them. Open space at upper right.
3. `P003 / N / square` — Extreme object insert: Selin's and Mert's separate hands hold two antique brass keys with matching teeth side by side, hands not touching. Background is only two matte pale gray-beige shapes.
4. `P004 / B / portrait 2:3` — Close portrait of Selin lifting her gaze from the key toward Mert, suspicion turning into reluctant curiosity. Preserve her sage hair clip, mole and exact face. Only a faint arch-line motif and a localized soft rim light near her cheek; no full-frame glow. Open space at upper right.
5. `P005 / C / square` — Recognizable chibi Selin crouches under three oversized blank doodle boxes symbolizing old-building details. Keep her hair shape, sage clip and outfit colors recognizable. Flat cream background, simple thick doodle lines, no text.
6. `P006 / E / wide 3:2` — High-angle establishing view inside the narrow inn stairwell. Selin and Mert look upward from the lower flight toward an arched frosted window and upper landing. Correct simplified stair perspective, dark wood railing, cream plaster and one warm lamp; sparse line texture only.
7. `P007 / N / portrait 2:3` — Back three-quarter waist view as Selin climbs one step ahead and Mert pauses one step below. Keep only three stair edges, one railing line and the pale arched-window shape. Open area at upper left.
8. `P008 / N / square` — Insert of Selin's loafer and Mert's black boot on adjacent old steps while Selin's brass key hangs safely from her hand above them. Three matte value groups define the stairs; no detailed stone texture.
9. `P009 / B / portrait 2:3` — Intimate two-shot: Mert lightly stops Selin before a loose stair, one hand near her forearm without grabbing; they meet eyes in surprise. Exact faces and outfits from references. Background reduced to cream gradient and one thin railing diagonal; very faint localized rim light only.
10. `P010 / E / wide 3:2` — Outside in a narrow back street, Selin and Mert stand beneath the dark green umbrella and notice a sage-green door at the far end. Two simple facades, three-window rhythm and one fire-escape silhouette. Drawn rain and a few short matte reflections, never glossy pavement.
11. `P011 / N / portrait 2:3` — Side walking two-shot under the same umbrella as they approach the green door, shoulders almost touching. Keep exact faces, hair and outfits. Background uses only three window rectangles, one green door shape and a few rain lines. Open area above them.
12. `P012 / B / portrait 2:3` — Close two-shot seen just above the brass keyhole as Selin guides the antique key toward the lock and both glance at each other. Sage-green door is a broad flat color field; brass lock and faces are sharp. Only a faint localized glow at the key, no bloom elsewhere.
```

## Tekrarlanan invariant

Her iterasyonda şu cümle son kez tekrarlanır:

```text
Change only the requested panel composition and illustrated environment. Keep the accepted character identity, face, hair, outfit and accessories unchanged from the supplied sheets.
```
