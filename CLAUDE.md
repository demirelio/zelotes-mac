# ZelotesMac

## Zelotes C-18 configuration protocol

- USB `12c9:2003`, three HID interfaces. Configuration is on the third (usage page `0xFF00`): 8-byte feature reports carry commands, 64-byte output reports carry tables. macOS delivers output reports to its interrupt OUT endpoint, which the mouse requires. It opens without root or a driver.
- Two profiles. There is no readback: a button write replaces all 11 buttons of a profile, a DPI write its five stages and its lighting, and the old contents cannot be recovered.
- A command is opcode, profile, argument, four zero bytes and a checksum that makes all eight bytes add up to `0xFF`.
- A write is one transaction: begin (`01 88 00`); the DPI part (select profile `02 p`, polling rate `03 p ms`, active stage `04 p n`, prepare `0c p 80`, primer, table); the button part (prepare `0d p 80`, table, 64 zero bytes); commit (`02 p`), which also makes that profile the active one. Either part may be left out. A stage switch on its own is begin, `02 p`, `04 p n`, commit; making a profile active is begin, commit.
- The third byte of a prepare command, `0x80`, is the length of the data phase: 128 bytes in two output reports. Until all of it arrives the mouse sends no movement or button reports and ignores the commit; only a replug recovers it, and nothing is stored.
- Reading the feature report returns the transaction status: byte 0 the last accepted opcode, byte 1 its profile, byte 2 the data bytes still expected.
- The `0x0C` data phase is the primer (`ff ff` and 62 zeros) and then the table; the button data phase is the table and then the zeros.
- `0x0C` table: a fixed header; bytes 7 to 9 the lighting effect, its speed or brightness tier, and a parameter; stage n's sensor code at bytes 19+n (X) and 27+n (Y), always equal; bytes 40 to 63 eight RGB triplets. Profile 2's factory table differs from Profile 1's only in the lighting.
- Sensor codes are not DPI/50. Measured: 200 `04`, 300 `06`, 400 `08`, 600 `0D`, 800 `12`, 1000 `16`, 1200 `1B`, 1600 `24`, 2000 `2E`, 2300 `34`, 2400 `37`, 2600 `3B`, 3000 `45`, 3200 `49`, 4800 `6F`, 5000 `73`; 6600 and 7000 DPI are `CC` and `D0`. Above 5000 DPI bit 7 is set and the low bits are the code of half the DPI.
- Lighting: off `00 00 00`; steady `01 <tier> 03`, tier 1 high, 2 medium, 3 low, every triplet the colour with each lit channel at `31`, `20` or `10`; breathing `02 <speed> 0A` and neon `03 <speed> 00` with fast `04`, medium `08`, slow `0C`; wave `04 <speed> 10` with `03`, `06`, `09`; flowing `06 <speed> 0A` with `3C`, `5F`, `78`. Every effect but steady comes with the palette red, green, blue, yellow, magenta, cyan, white, white at `31`. Factory: Profile 1 wave at medium speed, Profile 2 steady blue at high.
- Polling rate is the interval in ms: 1, 2, 4 or 8. It applies at commit, without a replug. macOS polls the mouse interface every 1 ms whatever the rate.
- Button table: 4 bytes per button, type then value, both 16-bit little-endian. Types: `0000` key (USB keyboard usage; modifiers in the type's high byte, Control, Shift, Option, Command as bits 0 to 3), `0001` mouse click (`F0` left, `F1` right, `F2` middle, `F3` back, `F4` forward), `0003` media (USB Consumer usage), `0007` DPI stage and `0008` profile (1 next, 2 previous, 3 cycle), `F00A` multi-click (its delay a signed byte). Bytes 56 to 63 are always `04 00 01 00 04 00 02 00`.
- Button numbers follow the vendor's diagram: joystick up (7) toward the cable, down (8) toward the palm, left (9) toward the thumb side, right (10) toward the fingers, 11 the press. Thumb button 4 is the one nearer the cable.
- The mouse's own profile and DPI Stage buttons change its state without telling the host.
- The movement report is 7 bytes without a report ID: buttons, X and Y as signed 16-bit little-endian, wheel, horizontal scroll. Reading it needs Input Monitoring. At 1000 Hz, input value callbacks lose most reports; raw reports with timestamps (`IOHIDManagerRegisterInputReportWithTimeStampCallback`) do not.
- Not confirmed on hardware: a stage switch on its own; lighting values other than the two factory ones; whether channel levels other than `10`, `20` and `31` mix colours; whether the animated effects take another palette; whether selecting the profile before `03` and `04` is needed. The factory DPI of stages 1 to 3 (1500, 2500, 4000) is read back from their codes.

## macOS pointer acceleration

- Acceleration is applied by the HID event system's pointer filter (`IOHIDPointerScrollFilter`, open source in Apple's IOHIDFamily), configured per service through properties. Settings on one service leave other mice and the trackpad alone, and vanish with the service when the device is unplugged. `hidutil dump services` shows each service's accelerator and its curve segments.
- The public simple client (`IOHIDEventSystemClientCreateSimpleClient`) may set the acceleration type but is refused the table and curves. A passive client (`IOHIDEventSystemClientCreateWithType`, type 2, exported by IOKit but not declared) may set them without an entitlement. The user curve key is literally `UserPointerAccelCurvesKey`.
- After the device is unplugged and plugged in again, a client made before that is refused the table; a new client is accepted.
- With Pointer Acceleration off in System Settings the filter scales movement linearly and ignores tables, but only when `HIDPointerAccelerationType` is `HIDMouseAcceleration`. Setting it to `HIDPointerAcceleration`, whose value is never negative, keeps an accelerator. Setting a property in the filter's cached list rebuilds the accelerator; setting the table alone does not.
- `HIDPointerAccelerationAlgorithm` 0 forces the table, 1 the parametric curves, 2 the default order (curves first).
- Table layout, big-endian, 16.16 fixed point unless noted: scale, signature `@200` (4 bytes), curve count (16 bits), then per curve its acceleration index, point count (16 bits) and x, y pairs, joined by straight lines from the origin. The filter picks or blends curves by the acceleration value, so the same curve at the lowest and highest index makes the tracking speed irrelevant. It scales x by resolution / 67 and y by 96 / 67; resolution is `HIDPointerResolution`, 400 counts per inch when unset.
- With `HIDPointerReportRate` set to R, the filter divides each report's movement by the time since the previous report, never by less than 1000/R ms. Without it the curve sees counts per report, so the polling rate changes the acceleration.
- A table set on a service cannot be removed, only replaced. Without one the filter uses a default table compiled into it, found in the installed filter (`/System/Library/HIDPlugins/IOHIDPointerScrollFilter.plugin`) by its signature.
- Windows' Enhance Pointer Precision uses the default `SmoothMouseXCurve` 0.43, 1.25, 3.86, 40 and `SmoothMouseYCurve` 1.37, 5.30, 24.30, 568: mouse speed against pointer speed in inches per second, straight lines from the origin. Windows 7 and later multiply the pointer speeds by 25/32, which leaves the shape of the gain unchanged.

## launchd agents and Background Items

- An agent registered with `SMAppService.agent` can be started by an IOKit matching launch event (`IOProviderClass` `IOUSBHostDevice` with `idVendor` and `idProduct`, `IOMatchLaunchStream`). It must take the event with `xpc_set_event_stream_handler("com.apple.iokit.matching", …)`, or launchd starts it again.
- Registering posts a "Background Items Added" notification that only informs. When the user turns the item off in Login Items, its status becomes `requiresApproval`, and only the user can turn it back on.
- launchd keeps a code requirement for the agent from its registration and refuses other code: `launchctl print gui/$UID/<label>` shows `spawn failed`, `needs LWCR update`, exit 78, and it retries every 10 seconds. Without a Team ID the requirement pins the exact build and launchd cannot repair it; registering again fixes it only after the unregistering has finished, or Background Task Management revives the old item.
- The job runs the program inside the bundle it was registered from; moving the bundle leaves it pointing at nothing.

## App icon tooling

- `actool` compiles an Icon Composer `.icon` into `Assets.car` plus an `AppIcon.icns`, and needs Xcode. It hands the work to a helper process with its own working directory, so its paths must be absolute.
- A fill for the dark icon style goes in `fill-specializations` with `"appearance" : "dark"`; without it the dark icon style uses a near-black fill.
- `NSWorkspace.icon(forFile:)` draws the variant for the icon style in System Settings (`AppleIconAppearanceTheme`), whatever the drawing appearance; the `AppIcon.icns` shows the light one. An app bundle without an executable gets a "prohibited" badge.
