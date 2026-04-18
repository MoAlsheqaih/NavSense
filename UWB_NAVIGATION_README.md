# UWB Navigation System Integration

## How Navigation Connects to Motors

The UWB positioning system now automatically calculates navigation directions and sends them to the ESP32 haptic motors:

```
UWB Anchors → ESP32 UWB Tag → BLE → Python Gateway → Direction Calculation → BLE Command → ESP32 → Haptic Motors
     ↓              ↓             ↓          ↓                      ↓            ↓           ↓         ↓
Positioning     Position Data   BLE TX    Trilateration        Direction       BLE RX     Command   Vibration
```

## Navigation Logic

### Direction Mapping
- **Forward (F)**: Toward positive Y direction (assuming user faces forward)
- **Backward (B)**: Toward negative Y direction
- **Left (L)**: Toward negative X direction  
- **Right (R)**: Toward positive X direction

### Target Position
Currently set to: `(1.5, 1.3)` meters (center of the room)

### Threshold
Navigation stops when within `0.3` meters of target.

## Testing the Integration

1. **Start the Gateway:**
   ```bash
   cd uwb_gateway
   python gateway.py
   ```

2. **Access Web Dashboard:**
   Open http://localhost:5001

3. **Enable Auto Navigation:**
   Click "Start Navigation" button

4. **Monitor:**
   - Position updates every ~100ms
   - Direction commands sent every 0.5 seconds
   - ESP32 receives BLE commands and triggers motor patterns

## Motor Response Patterns

Each direction command triggers the haptic sequence:
```
DOWN → CENTER → TARGET DIRECTION (3 repetitions)
```

With direction-specific intensities:
- **Forward**: 255 (full power)
- **Backward**: 180 (reduced)
- **Left/Right**: 220 (medium-high)
- **Center**: 128 (confirmation pulse)

## Configuration

Adjust navigation settings in `gateway.py`:

```python
TARGET_POSITION = {"x": 1.5, "y": 1.3}  # Target coordinates
NAVIGATION_THRESHOLD = 0.3               # Stop distance (meters)
NAVIGATION_UPDATE_INTERVAL = 0.5         # Update frequency (seconds)
```

## Testing Without Hardware

Uncomment the simulation thread in `gateway.py` for software testing:

```python
sim_thread = threading.Thread(target=simulate_position, daemon=True)
sim_thread.start()
```

This sends fake position data and will trigger navigation commands automatically.