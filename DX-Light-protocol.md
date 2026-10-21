# DX Light (Robobloq QuikLight) LED controller protocol

Recovered statically from `C:\Program Files\DX Light\resources\app.asar`
(app "quiklight-desktop" v3.11.0, Robobloq), the Electron app's bundled main process
(`.webpack/main/index.js`). The core of it was then confirmed on real hardware (see
"Verified on the device" at the end).

## Transport

| Item | Value |
|---|---|
| USB device | `1A86:FE0C` (WCH chip, USB CDC serial), appears as a COM port (COM5 on the dev PC) |
| App constant | `CDC_VID = 6790 (0x1A86)`, `CDC_PID = 65036 (0xFE0C)` |
| Serial settings | 115200 baud, 8 data bits (defaults: no parity, 1 stop bit) |
| Other variants in the app | HID `1A86:FE07` (manufacturer "ROBOBLOQ"), BLE, wireless dongle `5656:FFAA` |

Replies come back on the same port, start with ASCII `RB`, and echo the request's
sequence byte at offset 3. The app waits 200 ms for a reply after `write`, 2 ms after
`writeWithoutResponse` (used for color frames).

## "RB" command frame

```
offset 0-1  'R' 'B'            (0x52 0x42)
offset 2    total frame length (bytes, including checksum)
offset 3    sequence id        (2..254, increments, wraps to 1)
offset 4    action
offset 5..  payload
last byte   checksum = (sum of all previous bytes) & 0xFF
```

### Actions

| Action | Code | Payload |
|---|---|---|
| setSyncScreen | 0x80 | (uses the "SC" frame below) |
| writeDeviceInfo | 0x81 | u16BE, u8, u8, 0x01, u16BE (LED count config) |
| readDeviceInfo | 0x82 | none, see reply layout below |
| readDeviceUUID | 0x83 | none, reply bytes 5..12 = UUID |
| setLedEffect | 0x85 | effectIndex, param (built-in animations) |
| **setSectionLED** | **0x86** | N x 5-byte groups (see below) |
| setBrightness | 0x87 | brightness |
| setAutoOff | 0x89 | a, b |
| setDynamicSpeed | 0x8A | speed |
| setSoundSensitivity | 0x8B | sensitivity |
| setExternalAudio | 0x91 | u16BE |
| setOpenUrl | 0x93 | u8 |
| setLampsAmount | 0x95 | LED count |
| setWhiteBright | 0x96 | a, b |
| turnOffLight | 0x97 | none |
| setComputerRhythm | 0x98 | a, b (music mode) |
| (reply) sync-screen status report | 0xF1 | byte 6 = on/off |

### readDeviceInfo reply (0x82)

| Bytes | Meaning |
|---|---|
| 5..7 | device id (hex string, used for per-model tweaks) |
| 8 | display size |
| 11 | **LED count (lampsAmount)** |
| 12..19 | UUID |
| 21..23 | firmware version (major.minor.patch) |

## Color data: 5-byte range groups

Both `setSectionLED` and the screen-sync frame carry groups of:

```
[startLed, R, G, B, endLed]     LEDs are 1-based, range inclusive
```

- `endLed = 254` means "to the end of the strip". Solid color = `[1, R, G, B, 254]`.
- One group per LED (`[i, R, G, B, i]`) gives full per-LED control.
- Byte order follows the user's `wireMap` setting (default "RGB"); some strips need GRB etc.

### Real-time streaming (how screen sync works)

- **Firmware > 1.0.2**: one "SC" frame per update:
  ```
  'S' 'C' (0x53 0x43), u16BE total length, sequence id, 0x80, groups..., checksum
  ```
- **Older firmware**: the groups are split into chunks of 55 bytes (11 groups), each sent as an
  `RB 0x86 setSectionLED` frame, with 20 ms between chunks.

Before sending, the app only applies cosmetic tweaks (optional saturation boost, dimming of
near-black colors), so they are not needed for a driver.

## Built-in effects and music

- `setLedEffect (0x85)` takes `[effectType, effectIndex]`. `effectType 3` is music ("rhythm").
- DX Light's music has two sources (`rhythmType`): `2` = the controller's own microphone,
  `1` = computer audio. DX Light only uses computer audio for the **HID** variant (`1A86:FE07`)
  on firmware >= 1.8.2. On this USB-serial controller its music mode is mic-only.
- `setComputerRhythm (0x98)` = `[effectIndex, level 0..100]`. This is how PC audio levels would be
  fed to the controller's own music effects. Untested on this device (see the app's
  "PC audio -> controller effects" option).

## Verified on the device

Tested against the real controller (firmware 1.1.2, device id `000603`, display size 27, 63 LEDs):

- `readDeviceInfo` request `52 42 06 02 82 1e` gets a valid reply; the field layout above is correct.
- Solid color via `RB 0x86 [1,R,G,B,254]` works.
- Per-LED frames work over both transports: `SC` frames and chunked `RB 0x86`.
- Range compression (merging neighbouring LEDs with the same color into one group) is accepted.
- The 3 buttons on the controller (power, mode, music) send **nothing** over USB. They only act
  inside the controller, so the PC can't react to them.
- The controller has no Wi-Fi or Bluetooth. Without a PC it only runs its built-in effects
  (last mode is kept by the controller itself).

## Open questions

- Update rate: frames sent every ~50 ms made an animated rainbow "freeze" on a fixed pattern,
  while 1 frame/s always updated. The real ceiling is still unknown. The app has an FPS slider
  and skips identical frames; find the highest FPS where effects still move.
- Full list of `setLedEffect` indexes per effect type.
- Whether `setComputerRhythm (0x98)` does anything on this (serial, fw 1.1.2) controller.
