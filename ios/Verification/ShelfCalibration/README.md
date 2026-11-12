# Automatic shelf calibration review

The twelve comparison sheets use the production `ShelfComposition` geometry and bundled room/sprite assets. Orange dashed boxes show the comparison’s visible idle bounds (confirmed only for Duo/iPad); teal lines show the painted sitting surface. Labels give the new sprite-size difference. The images omit live UI and use a plain lower canvas; they are offline composition checks, not screenshots of every simulator posture. Open `index.html` to browse them together.

Reference provenance:

- `miniP/L`: confirmed `ios/valspadmini.md` iPad-mini entries, at 744×1133 points and its rotation.
- `proP/L`: confirmed `ios/valspro11.md` iPad entries, at 834×1210 points and its rotation. Untouched identities within these confirmed families are kept; unrelated phone entries are excluded.
- `duoP/L/Open`: the 36 previously approved production adjustments from the original `vals.md` import. The source file is no longer present; the resulting approved frames were frozen before replacing the implementation.
- `duoHinge`: earlier confirmed seated transforms, reconstructed with the existing painted-ledge/hinge relationship.
- `phoneP/L` and `maxP/L`: **unverified old baselines**, at 393×852 and 440×956 points and their rotations. No phone export contains tuned values. These 48 cases are excluded from approval/tolerance statistics and retained only to show how the correction differs from the old rendering.

The installed simulator device profiles supplied the screen dimensions. The manual exports did not record safe areas, measured header height, windowing, or exact fold positions. Reference geometry therefore uses representative header/safe-area allowances. The comparison is a proportional litmus test within the user's ±10% guidance, not a claim of pixel-exact reconstruction.

Shared model: twelve character records (seat coordinate, optical weight, comfortable height), six painted shelf landmarks, and one solver for stacked/side-by-side composition. Hinge scenes use the same solver with a shelf coordinate derived from the room's hinge registration. Aspect ratio blends head/leg-room budgets only. The character’s optical weight and comfortable size limit remain active on every screen. The previous formula disabled them on tall phones; that was the cause of oversized Mochi. Dimensions, not model names, drive the fit. Safety constraints use the union of both expression bounds.

Validation:

- 96 confirmed cases: mean absolute size difference 3.03%, maximum 9.48%; maximum vertical visual-center difference 4.33% of reference sprite height. The 48 unverified phone cases do not count toward this claim.
- Sitting-coordinate mismatch below 0.001 points, including hinge paintings.
- 37 core tests pass, including intermediate-size sweeps, expression bounds and exact shelf registration.
- Simulator build and four native render/resource tests pass: 96 idle/poked captures across the shared renderer's display layouts, six pack-preview captures, shelf bounds, and room coverage.

The reference JSON is validation-only. Runtime does not read it, the tuning exports, or old saved overrides. Recreate the PNG sheets and `comparison.json` with `ios/Scripts/review_shelf_layout.swift` (command in `ios/README.md`).

Audit correction: the initial report incorrectly described all 144 cases as confirmed. Its Pro Max baseline was an assumption, and the earlier “within 10%” statement did not validate the intended Pro Max sizing. The corrected report separates these categories explicitly.

Phone-scale correction verification: `testFreeCompanionPhoneVisualReview` passed on an isolated iPhone 18 Pro Max simulator. `NativeMax/portrait.png` and `NativeMax/landscape.png` show the actual production `StudyView` hosted in the native phone window, including its measured safe areas and header. Columns are Mochi, Pip, and Pebble. `NativeMax/mochi-portrait.png` is the full-resolution single capture. The broader paid-theme capture could not run because local StoreKit failed to deliver the collection entitlement; the free-companion capture intentionally has no purchase dependency.
