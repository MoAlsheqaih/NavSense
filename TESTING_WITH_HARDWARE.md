# Testing with ESP32 UWB Hardware

## Prerequisites
1. **ESP32 Firmware**: Ensure your ESP32 sends JSON data via BLE NUS TX characteristic in format:
   ```json
   {"links": [{"A": "1782", "R": 1.234}, {"A": "1783", "R": 2.345}, {"A": "1784", "R": 3.456}]}
   ```
   If different, update the parsing in `gateway.py`.

2. **ESP32 BLE Name**: Update `DEVICE_NAME` in `gateway.py` if your device uses a different BLE name.

3. **Anchor Configuration**: 
   - Update `ADDR_A1`, `ADDR_A2`, `ADDR_A3` with your anchor short addresses
   - Measure and update `ANCHORS` coordinates in meters

## Testing Steps

### 1. Start Python Gateway
```bash
cd uwb_gateway
python gateway.py
```
- Should show "[BLE] Scanning for 'UWB-Wearable'..."
- When ESP32 is powered on, should connect: "[BLE] Connected"

### 2. Start Flutter App
```bash
cd navsense
flutter run  # On device/simulator
```
Or for web testing:
```bash
flutter run -d web-server
# Open http://localhost:55027 in browser
```

### 3. Verify Position Data Flow
- Gateway should receive BLE data from ESP32
- Calculate position and send to Flutter via UDP port 8081
- Flutter console should show: "Received UWB data: {...}"
- Position should update in the app

### 4. Test Haptic Commands
- Start navigation in Flutter app
- When direction changes (left/right/straight), gateway should receive UDP commands on port 8082
- Gateway forwards to ESP32 via BLE RX
- ESP32 should receive "F", "B", "L", "R" commands

### 5. Monitor Gateway Web Dashboard
- Open http://localhost:5001 in browser
- Shows current position and anchor distances
- Can manually send haptic commands via buttons

### 6. Troubleshooting
- **No BLE connection**: Check ESP32 is powered and advertising
- **No position data**: Verify ESP32 JSON format matches expected
- **No haptic feedback**: Check ESP32 receives BLE commands on RX characteristic
- **UDP issues**: Ensure no firewall blocking ports 8081-8082

## For Development Testing (Without Hardware)
Uncomment the simulation thread in `gateway.py`:
```python
sim_thread = threading.Thread(target=simulate_position, daemon=True)
sim_thread.start()
```
This sends fake position data every second.