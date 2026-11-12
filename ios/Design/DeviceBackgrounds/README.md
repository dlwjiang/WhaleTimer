# Phone and iPad rooms

## Current composition: reuse the Duo ledges

Phone and iPad now reuse the six existing `duo-room-*` paintings and all twelve `duo-sprite-*` sheets. No new images were generated. `DeviceRoomFormat` chooses portrait or landscape framing, uniformly scales the architecture, and registers each room's measured front seat edge (`DuoRoom.perchFraction`) to the shared screen ledge. Portrait centers the character; landscape positions it left of the timer. The room's lower paper fades into the existing `paper-texture` with a matching warm tint.

`CompanionArtworkLayout.perched` aligns each sprite's **seat**, rather than the bottom of its dangling feet, to that edge. Both expressions share a frame sized to contain their combined alpha bounds. The timer scrolls independently in portrait so the character cannot drift away from the painted ledge. The Duo's existing hinge calibration stays separate.

See [composition review](../../Verification/PerchedRooms/README.md). Core tests cover every companion and both expressions; the native resource test checks the reused room assets. A live phone/iPad spot check is still required.

## Earlier floor compositions (retained)

The 24 images below and their catalog entries are retained as source history, but the current phone/iPad view no longer selects them. Their original prompts and manifest still describe their generation, not the current ledge composition.

24 backgrounds cover all six companion rooms in four independently generated compositions:

- `phone`: 9:19.5 portrait, centered companion above the timer.
- `phone-landscape`: 19.5:9, companion on the left and timer on the right.
- `pad-portrait`: 3:4, spacious centered stage and quiet lower floor.
- `pad-landscape`: 4:3, companion on the left and timer on the right.

The window, woodland study and river rooms belong to Mochi, Pip and Pebble. Café, academy and orbital rooms cover all companions in their respective premium packs. The existing Duo art and framing are separate.

Created with built-in imagegen, using the corresponding Duo landscape images as style references. Each deliverable was generated individually. `plan.json` preserves the exact prompts. `manifest.json` records selected files, dimensions, hashes, catalog asset names and measured floor landmarks. The phone river image uses `phone-river-v2.png`; `river-repair.json` records its seam repair. The first river take is retained for provenance and is not bundled.

Runtime assets are copied into `Banke/Assets.xcassets/device-<format>-<room>.imageset`. `DeviceRoomFormat` chooses a composition by window shape, including narrow iPad multitasking windows. Uniform scaling fills the window while aligning the painted floor; the image is never stretched independently along its axes. `DeviceRoomSprite` places the shared idle/poked sprite sheet on that floor using the union of both frames’ measured alpha bounds. `CompanionArtwork` is the single renderer for phone, iPad and Duo; only frame geometry changes by display. The character carousel and speech remain interactive layers.

Validation:

```sh
python3 ios/Scripts/verify_release_resources.py
```

`ReleaseExperienceTests` checks all bundled formats, floor registration, window coverage and all 12 characters across both registered expressions. `ReleaseExperienceTests/testDeviceRoomVisualReview` captures all six rooms with verified local StoreKit test purchases. Phone captures use actual simulator rotation. iPad captures render the production view in a native hosting controller at explicit 1024×1366 and 1366×1024 point sizes because its simulator window mode can reject programmatic rotation. Native review images are saved under the test app's temporary `DeviceRoomReview` folder; they require no preview server.
