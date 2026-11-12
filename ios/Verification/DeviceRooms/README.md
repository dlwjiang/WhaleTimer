# Phone and iPad room review — November 11, 2026

Each contact sheet shows the six room themes: Mochi/window, Pip/study, Pebble/river, Jun/café, Luna/academy and Nova/orbit. All are captures of the production SwiftUI view with the real bundled assets. Premium rooms were unlocked through verified local StoreKit transactions.

- Phone portrait and landscape use actual iPhone 18 Pro simulator rotation and native safe areas.
- iPad uses native hosting-controller renders at 1024×1366 and 1366×1024 points. The simulator’s window mode rejects programmatic iPad rotation, so these demonstrate the production view at both sizes rather than a device rotation animation.
- All six rooms were visually inspected in all four compositions: backgrounds cover the canvas, characters meet the floor, and timer controls remain visible.
- Geometry tests passed on both QA devices for all 24 backgrounds, narrow iPad windows, and all 12 companions’ shared idle/poked expressions.
- Resource validation confirms source/catalog hashes, format dimensions and complete asset coverage. Native builds and final visual-review tests passed; exact local result bundles are recorded in `verification.json`.

`*-contact.png` shows all six rooms; `*-mochi.png` retains one full-resolution view per format. No preview server was used.
