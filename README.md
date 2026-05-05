# Traffic Control and Emergency Vehicle Detection Using RFID Sensor

> RFID-based smart traffic signal controller with emergency vehicle detection — Arduino UNO R3 + RFID-RC522 → UART → DE1-SoC FPGA (Verilog HDL)

---

## Overview

This project implements an intelligent traffic signal control system that detects RFID-tagged emergency vehicles (ambulances, fire trucks, police) and overrides the normal traffic cycle to clear a path — all in real time.

An **RFID-RC522** module reads the UID of an approaching emergency vehicle via an **Arduino UNO R3**, which transmits the UID over **UART** to a **DE1-SoC FPGA**. On the FPGA, a complete **Verilog HDL** design processes the data and controls four intersections simultaneously. When a registered emergency UID is detected, the system immediately forces the emergency lane to green and holds all other lanes at red. Normal round-robin operation resumes automatically after a timer expires.

---

## System Architecture

```
RFID Tag (Emergency Vehicle)
        │
        ▼
  RFID-RC522 Module (SPI)
        │
        ▼
  Arduino UNO R3
  [reads UID, formats as <XXXXXXXX>, sends over UART @ 9600 baud]
        │  UART TX ──────────────────────────────────────────────►  GPIO RX
        ▼
  DE1-SoC FPGA (Intel Cyclone V, 50 MHz clock)
  ┌─────────────────────────────────────────────┐
  │  uart_rx       → deserializes UART bytes    │
  │  rfid_parser   → decodes ASCII UID to 32-bit│
  │  four_int      → emergency detection + top  │
  │  lane_int      → per-intersection FSM       │
  │  signal        → green/yellow/red timing    │
  └─────────────────────────────────────────────┘
        │
        ▼
  Traffic Signal Outputs (l0_dir, l1_dir, l2_dir, l3_dir)
  + emg_active flag
```

---

## Hardware

| Component | Description |
|---|---|
| Arduino UNO R3 | ATmega328P — reads RFID via SPI, transmits UID over UART |
| RFID-RC522 | 13.56 MHz RFID reader/writer, SPI interface |
| DE1-SoC FPGA | Intel/Altera Cyclone V, 50 MHz clock — runs all Verilog logic |
| RFID Tags/Cards | Pre-programmed with UIDs for registered emergency vehicles |
| Jumper Wires | SPI (pins 10–13, 9) + UART TX → FPGA GPIO RX |

### Pin Connections — RFID-RC522 to Arduino UNO R3

| RFID-RC522 Pin | Arduino UNO R3 Pin | Function |
|---|---|---|
| SDA (SS) | Pin 10 | SPI Slave Select |
| SCK | Pin 13 | SPI Clock |
| MOSI | Pin 11 | SPI Master Out |
| MISO | Pin 12 | SPI Master In |
| IRQ | Not connected | — |
| GND | GND | Ground |
| RST | Pin 9 | RFID Reset |
| 3.3V | 3.3V | Power |
| Arduino TX | FPGA GPIO RX | UART to FPGA |

---

## Verilog Modules

| Module | File | Description |
|---|---|---|
| `uart_rx` | `uart_rx.v` | UART receiver — 50 MHz clock, BAUD_DIV=5208 for 9600 baud |
| `rfid_parser` | `rfid_parser.v` | ASCII `<XXXXXXXX>` → 32-bit UID decoder, 2-state FSM |
| `lane_int` | `lane_int.v` | Per-intersection direction FSM (N→E→S→W, 10-cycle period) |
| `signal` | `signal.v` | Green/Yellow/Red timing FSM (7 green + 2 yellow cycles) |
| `four_int` | `four_int.v` | Top-level: integrates all modules, emergency override logic |
| `four_int_tb` | `four_int_tb.v` | Testbench: simulates UART UID transmission and verifies outputs |

### Emergency Override Logic

- Registered emergency UID: `32'h0100A354`
- On UID match: `emg_active` asserted, `sensor[0]` set, affected lane forced to **West**
- All other lanes held at **Red** for the duration of the emergency
- Auto-clears after countdown timer (`4 × 9` clock cycles) expires

### Signal Encoding

```verilog
RED    = 3'b100
YELLOW = 3'b010
GREEN  = 3'b001

// 12-bit flat output: {l3[2:0], l2[2:0], l1[2:0], l0[2:0]}
```

---

## Arduino Sketch

The Arduino sketch (`Arduino.ino`) uses the [MFRC522 library](https://github.com/miguelbalboa/rfid).

```cpp
// Reads UID and sends over UART as <XXXXXXXX>
Serial.begin(9600);   // UART to FPGA
SPI.begin();
rfid.PCD_Init();
```

Install the library via Arduino IDE: **Tools → Manage Libraries → search "MFRC522"**

---

## Simulation

The testbench `four_int_tb.v` can be run with [Icarus Verilog](http://iverilog.icarus.com/):

```bash
# Compile
iverilog -o sim four_int_tb.v four_int.v uart_rx.v rfid_parser.v lane_int.v signal.v

# Run
vvp sim

# View waveforms
gtkwave wave.vcd
```

The testbench:
1. Resets the system
2. Runs normal N→E→S→W cycling
3. Sends emergency UID `<0100A354>` byte-by-byte over simulated UART
4. Verifies `emg_active` is asserted and lane is forced to West
5. Verifies automatic return to normal cycling after timer expiry

---

## FPGA Synthesis

1. Open **Intel Quartus Prime**
2. Create a new project targeting the **DE1-SoC (Cyclone V 5CSEMA5F31C6)**
3. Add all `.v` files, set `four_int` as the top-level module
4. Assign GPIO pins for `rx`, `l0_dir`–`l3_dir`, `emg_active` in the Pin Planner
5. Compile and program via **USB Blaster**

---

## Repository Structure

```
├── Arduino.ino          # Arduino sketch — RFID UID reader + UART sender
├── uart_rx.v            # UART receiver module (Verilog)
├── rfid_parser.v        # RFID UID ASCII parser (Verilog)
├── lane_int.v           # Per-intersection direction FSM (Verilog)
├── signal.v             # Traffic signal timing FSM (Verilog)
├── four_int.v           # Top-level integration module (Verilog)
├── four_int_tb.v        # Simulation testbench (Verilog)
└── README.md
```

---

## Results

- RFID-RC522 reliably detected both emergency (`<0100A354>`) and non-emergency (`<404E2B61>`) tags
- UART transmission at 9600 baud between Arduino UNO R3 and DE1-SoC FPGA was stable with no data loss
- Emergency override activated correctly in both simulation (GTKWave) and hardware testing
- Normal traffic cycling resumed automatically after the emergency timer expired
- Synthesis and timing closure achieved successfully in Intel Quartus Prime

---

## Future Work

- Multi-lane RFID detection (one reader per approach direction)
- Wireless V2I communication (Zigbee / 433 MHz RF) to remove the UART wire
- Priority queue for simultaneous multi-intersection emergency requests
- Real-time signal state display on DE1-SoC on-board 7-segment displays and LEDs
- UHF long-range RFID for earlier vehicle detection and longer pre-emption lead time

---

## References

1. MFRC522 Arduino Library — https://github.com/miguelbalboa/rfid
2. NXP MFRC522 Datasheet, Rev. 3.9, 2016
3. Intel DE1-SoC Reference Manual — Terasic Technologies
4. Intel Quartus Prime Documentation — https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/overview.html
5. Icarus Verilog Simulator — http://iverilog.icarus.com/
6. IEEE Std 1364-2001 — Verilog Hardware Description Language

---

## License

This project was developed as a Mini Project (EC280) at the **Department of Electronics and Communication Engineering, NIT Karnataka, Surathkal**.
