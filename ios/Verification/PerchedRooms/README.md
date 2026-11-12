# Reused ledge composition review

The four PNG contact sheets show window/Mochi, study/Pip, river/Pebble, café/Jun, academy/Luna and orbit/Nova, in that order. They reuse the six bundled Duo room paintings, existing paper texture, and registered idle sprites. No generated or modified source artwork was needed.

These are offline AppKit composition checks using the production geometry at 393×852, 852×393, 1024×1366 and 1366×1024 points. They intentionally omit UI controls and use representative header/safe-area allowances; they are **not screenshots of the running app**. The paper blend approximates SwiftUI compositing. The separate geometry tests cover all twelve companions and both expressions.

Recreate from the repository root without starting an app or server:

```sh
swiftc -module-cache-path /tmp/whale-module-cache ios/Banke/Core/*.swift ios/Scripts/render_perched_rooms.swift -o /tmp/perch-review
/tmp/perch-review
```

Validation: 32 Swift core tests passed, including seat registration, expression bounds and undistorted room coverage. Release resource validation passed. The simulator-target app build passed without launching the app.

Live spot check: Run the Banke scheme on phone and iPad, rotate both ways, switch companions and tap for their second expression. Check that bodies sit on the horizontal edge, feet hang below it, and header/timer controls remain legible. In portrait, scroll the timer and confirm the artwork stays seated. Include large text and a narrow iPad window. Existing DeviceRooms screenshots document the superseded floor composition.
