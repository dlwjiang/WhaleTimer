# Shared companion rendering — November 11, 2026

Every image places the idle cell on the left and the poked cell on the right. These are native SwiftUI renders of `CompanionArtwork`, the single production renderer for phone, iPad, Duo seated and Duo landscape. Each layout uses the exact same two-frame sprite sheet, expression selection, speech placement and carousel implementation; only geometry differs.

`testSharedCompanionPokeArtworkAcrossDisplays` passed on the isolated iPhone and iPad simulators. It renders all 12 companions in four layouts and checks that each poke changes the rendered pixels. Geometry tests check floor placement for both cells, and calibrated platform bounds keep ears and feet within the pane. Native full-room phone and iPad captures were refreshed in `../DeviceRooms`.

The poke lasts two seconds through the shared `CompanionScene.greet()` action. Timer completion and audio playback no longer substitute the old happy artwork. The scene does not use the older four-pose sprite pipeline or its jiggle/breathing transforms. Those original assets remain available for storefront previews.
