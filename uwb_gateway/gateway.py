import asyncio
import threading
import json
import math
import socket
import time
import random
from flask import Flask, render_template_string, jsonify, request

from bleak import BleakClient, BleakScanner

# ═══════════════════════════════════════════════════════════════════════════════
# SETTINGS  — change these to match your setup
# ═══════════════════════════════════════════════════════════════════════════════

DEVICE_NAME      = "UWB-Wearable"  # Update if your ESP32 uses different BLE name
NUS_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
NUS_TX_UUID      = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"   # ESP32 → PC
NUS_RX_UUID      = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"   # PC → ESP32

def norm_addr(addr):
    return str(addr).strip().upper().replace("0X", "")

# Short addresses from your anchors - UPDATE THESE TO MATCH YOUR SETUP
ADDR_A1 = norm_addr("1782")
ADDR_A2 = norm_addr("1783")
ADDR_A3 = norm_addr("1784")

# Real measured anchor coordinates in metres - MEASURE AND UPDATE THESE
# A1 and A2 are on the bottom line, A3 is above them.
ANCHORS = {
    ADDR_A1: ("A1", 0.0, 0.0),  # Bottom left (0, 0)
    ADDR_A2: ("A2", 5.0, 0.0),  # Bottom right (5, 0)
    ADDR_A3: ("A3", 5.0, 10.0),  # Top right (5, 10)
}

# NAVIGATION SETTINGS
TARGET_POSITION = {"x": 2.5, "y": 5.0}  # Target position in meters (center of room)
NAVIGATION_THRESHOLD = 0.5  # Stop navigation when within this distance of target
NAVIGATION_UPDATE_INTERVAL = 0.5  # Seconds between navigation updates
MAX_SPEED = 0.8  # Maximum movement speed (m/s)

range_offset = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# SHARED STATE
# ═══════════════════════════════════════════════════════════════════════════════

latest_links   = []
data_lock      = threading.Lock()
ble_client_ref = None
ble_loop_ref   = None
ble_connected  = False
current_position = {"x": 0.0, "y": 0.0, "anchors": {}}

# NAVIGATION STATE
navigation_enabled = False
last_navigation_time = 0
current_direction = None

# ═══════════════════════════════════════════════════════════════════════════════
# POSITIONING MATH
# ═══════════════════════════════════════════════════════════════════════════════

def uwb_range_offset(uwb_range):
    return uwb_range - range_offset

def tag_pos_2anchor(r_to_a2, r_to_a1, baseline):
    cos_a = (r_to_a1 * r_to_a1 + baseline * baseline - r_to_a2 * r_to_a2) / (2 * r_to_a1 * baseline)
    cos_a = max(-1.0, min(1.0, cos_a))
    x = r_to_a1 * cos_a
    y = r_to_a1 * math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
    return round(x, 2), round(y, 2)

def trilaterate_2d(p1, r1, p2, r2, p3, r3):
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3

    a = 2.0 * (x2 - x1)
    b = 2.0 * (y2 - y1)
    c = r1 * r1 - r2 * r2 - x1 * x1 + x2 * x2 - y1 * y1 + y2 * y2

    d = 2.0 * (x3 - x1)
    e = 2.0 * (y3 - y1)
    f = r1 * r1 - r3 * r3 - x1 * x1 + x3 * x3 - y1 * y1 + y3 * y3

    det = a * e - b * d
    if abs(det) < 1e-9:
        raise ValueError("Anchor geometry is singular")

    x = (c * e - b * f) / det
    y = (a * f - c * d) / det
    return round(x, 2), round(y, 2)

# ═══════════════════════════════════════════════════════════════════════════════
# NAVIGATION LOGIC
# ═══════════════════════════════════════════════════════════════════════════════

def calculate_direction(current_x, current_y, target_x, target_y):
    """
    Calculate the primary direction needed to reach target.
    Returns: 'F' (forward), 'B' (backward), 'L' (left), 'R' (right), or None if at target
    """
    dx = target_x - current_x
    dy = target_y - current_y

    distance = math.sqrt(dx*dx + dy*dy)

    if distance < NAVIGATION_THRESHOLD:
        return None  # At target

    # Calculate angle to target (0 = positive X axis, 90 = positive Y axis)
    angle_rad = math.atan2(dy, dx)
    angle_deg = math.degrees(angle_rad)

    # Normalize to 0-360
    if angle_deg < 0:
        angle_deg += 360

    # Determine primary direction based on angle
    # Assuming user faces positive Y direction (forward)
    if 315 <= angle_deg or angle_deg < 45:
        return 'R'  # Right (positive X)
    elif 45 <= angle_deg < 135:
        return 'F'  # Forward (positive Y)
    elif 135 <= angle_deg < 225:
        return 'L'  # Left (negative X)
    else:
        return 'B'  # Backward (negative Y)

def update_navigation():
    """Update navigation and send direction commands to motors."""
    global last_navigation_time, current_direction

    current_time = time.time()
    if current_time - last_navigation_time < NAVIGATION_UPDATE_INTERVAL:
        return

    if not navigation_enabled:
        return

    current_x = current_position.get("x", 0.0)
    current_y = current_position.get("y", 0.0)

    new_direction = calculate_direction(current_x, current_y, TARGET_POSITION["x"], TARGET_POSITION["y"])

    if new_direction != current_direction:
        if new_direction is None:
            print("[NAV] Target reached!")
            navigation_enabled = False
        else:
            print(f"[NAV] Direction: {new_direction} (pos: {current_x:.2f}, {current_y:.2f})")
            send_command(new_direction)

        current_direction = new_direction

    last_navigation_time = current_time

# ═══════════════════════════════════════════════════════════════════════════════
# UDP COMMUNICATION
# ═══════════════════════════════════════════════════════════════════════════════

def send_position_to_flutter(x, y, anchors):
    """Send position data to Flutter via UDP."""
    data = {
        "tagId": "uwb_tag_001",
        "x": x,
        "y": y,
        "z": 0.0,
        "accuracy": 0.15,
        "anchors": [{"id": addr, "distance": dist} for addr, dist in anchors.items()]
    }
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(json.dumps(data).encode('utf-8'), ("127.0.0.1", 8081))
        sock.close()
    except Exception as e:
        print(f"[UDP] Error sending position: {e}")

def udp_command_server():
    """UDP server to receive haptic commands from Flutter."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("127.0.0.1", 8082))
    print("[UDP] Listening for commands on port 8082")
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            cmd = data.decode('utf-8').strip().upper()
            if cmd in ("F", "B", "L", "R"):
                send_command(cmd)
                print(f"[UDP] Received command: {cmd}")
        except Exception as e:
            print(f"[UDP] Error: {e}")

def simulate_position():
    """Simulate position data for testing."""
    global current_position
    while True:
        # Simulate moving around
        x = 1.0 + random.uniform(-0.5, 0.5)
        y = 1.0 + random.uniform(-0.5, 0.5)
        anchors = {
            "1782": 1.5 + random.uniform(-0.1, 0.1),
            "1783": 2.0 + random.uniform(-0.1, 0.1),
            "1784": 2.5 + random.uniform(-0.1, 0.1),
        }
        current_position = {"x": x, "y": y, "anchors": anchors}
        send_position_to_flutter(x, y, anchors)
        time.sleep(1)

# ═══════════════════════════════════════════════════════════════════════════════
# BLE — background thread
# ═══════════════════════════════════════════════════════════════════════════════

def notification_handler(sender, data: bytearray):
    global latest_links, current_position
    try:
        parsed = json.loads(data.decode("utf-8"))
        links = parsed.get("links", [])
        print(parsed)
        with data_lock:
            latest_links = links

        ranges = {}
        for one in links:
            addr = norm_addr(one.get("A", ""))
            rng = uwb_range_offset(float(one.get("R")))
            ranges[addr] = rng

        have_a1 = ADDR_A1 in ranges
        have_a2 = ADDR_A2 in ranges
        have_a3 = ADDR_A3 in ranges

        if have_a1 and have_a2 and have_a3:
            p1 = (ANCHORS[ADDR_A1][1], ANCHORS[ADDR_A1][2])
            p2 = (ANCHORS[ADDR_A2][1], ANCHORS[ADDR_A2][2])
            p3 = (ANCHORS[ADDR_A3][1], ANCHORS[ADDR_A3][2])
            x, y = trilaterate_2d(p1, ranges[ADDR_A1], p2, ranges[ADDR_A2], p3, ranges[ADDR_A3])
            current_position = {"x": x, "y": y, "anchors": ranges}
            send_position_to_flutter(x, y, ranges)
            update_navigation()  # Update navigation based on new position
        elif have_a1 and have_a2:
            baseline = math.dist((ANCHORS[ADDR_A1][1], ANCHORS[ADDR_A1][2]), (ANCHORS[ADDR_A2][1], ANCHORS[ADDR_A2][2]))
            x, y = tag_pos_2anchor(ranges[ADDR_A2], ranges[ADDR_A1], baseline)
            current_position = {"x": x, "y": y, "anchors": ranges}
            send_position_to_flutter(x, y, ranges)
            update_navigation()  # Update navigation based on new position

    except Exception as e:
        print(f"[BLE] Parse error: {e}")

async def ble_main():
    global ble_client_ref, ble_connected
    print(f"[BLE] Scanning for '{DEVICE_NAME}'...")
    device = None
    while device is None:
        device = await BleakScanner.find_device_by_name(DEVICE_NAME, timeout=5.0)
        if device is None:
            print("[BLE] Not found — retrying...")

    print(f"[BLE] Found: {device.address}")
    while True:
        try:
            async with BleakClient(device) as client:
                ble_client_ref = client
                ble_connected = True
                print("[BLE] Connected")
                await client.start_notify(NUS_TX_UUID, notification_handler)
                while client.is_connected:
                    await asyncio.sleep(0.05)
        except Exception as e:
            print(f"[BLE] Error: {e} — retrying in 2 s")
        finally:
            ble_connected = False
            ble_client_ref = None
        await asyncio.sleep(2.0)

def start_ble_thread():
    global ble_loop_ref
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    ble_loop_ref = loop
    loop.run_until_complete(ble_main())

def send_command(direction: str):
    cmd = direction.upper().strip()
    if cmd not in ("F", "B", "L", "R"):
        return
    if ble_client_ref is None or not ble_client_ref.is_connected:
        print("[CMD] Not connected")
        return

    async def _write():
        try:
            await ble_client_ref.write_gatt_char(NUS_RX_UUID, cmd.encode("utf-8"), response=False)
            print(f"[CMD] Sent: {cmd}")
        except Exception as e:
            print(f"[CMD] Error: {e}")

    if ble_loop_ref:
        asyncio.run_coroutine_threadsafe(_write(), ble_loop_ref)

# ═══════════════════════════════════════════════════════════════════════════════
# FLASK WEB SERVER
# ═══════════════════════════════════════════════════════════════════════════════

app = Flask(__name__)

@app.route('/')
def dashboard():
    return render_template_string('''
<!DOCTYPE html>
<html>
<head>
    <title>UWB Positioning Gateway</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .status { padding: 10px; border-radius: 5px; margin: 10px 0; }
        .connected { background-color: #d4edda; color: #155724; }
        .searching { background-color: #fff3cd; color: #856404; }
        .position { background-color: #f8f9fa; padding: 10px; border-radius: 5px; }
        button { margin: 5px; padding: 10px; }
    </style>
</head>
<body>
    <h1>UWB Positioning Gateway</h1>
    <div class="status {{ 'connected' if ble_connected else 'searching' }}">
        Status: {{ 'Connected' if ble_connected else 'Searching...' }}
    </div>
    <div class="position">
        <h3>Current Position</h3>
        <p>X: {{ current_position.x }} m</p>
        <p>Y: {{ current_position.y }} m</p>
        <h4>Anchor Distances</h4>
        <ul>
        {% for addr, dist in current_position.anchors.items() %}
            <li>{{ addr }}: {{ dist }} m</li>
        {% endfor %}
        </ul>
    </div>
    <h3>Haptic Commands</h3>
    <button onclick="sendCmd('F')">Forward</button>
    <button onclick="sendCmd('B')">Backward</button>
    <button onclick="sendCmd('L')">Left</button>
    <button onclick="sendCmd('R')">Right</button>

    <h3>Auto Navigation</h3>
    <div>
        <button onclick="startNav()" style="background-color: #28a745; color: white;">Start Navigation</button>
        <button onclick="stopNav()" style="background-color: #dc3545; color: white;">Stop Navigation</button>
    </div>
    <div id="nav-status" style="margin-top: 10px; padding: 10px; border-radius: 5px; background-color: #f8f9fa;">
        Navigation: <span id="nav-enabled">Disabled</span><br>
        Current Direction: <span id="nav-direction">None</span><br>
        Target: ({{ TARGET_POSITION.x }}, {{ TARGET_POSITION.y }})
    </div>
    <script>
        function sendCmd(cmd) {
            fetch('/command', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({command: cmd})
            });
        }

        function startNav() {
            fetch('/navigation/start', { method: 'POST' });
            updateNavStatus();
        }

        function stopNav() {
            fetch('/navigation/stop', { method: 'POST' });
            updateNavStatus();
        }

        function updateNavStatus() {
            fetch('/navigation/status')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('nav-enabled').textContent = data.enabled ? 'Enabled' : 'Disabled';
                    document.getElementById('nav-direction').textContent = data.current_direction || 'None';
                    document.getElementById('nav-status').style.backgroundColor = data.enabled ? '#d4edda' : '#f8f9fa';
                });
        }

        // Update navigation status every 2 seconds
        setInterval(updateNavStatus, 2000);
        // Initial load
        updateNavStatus();
    </script>
</body>
</html>
    ''', ble_connected=ble_connected, current_position=current_position, TARGET_POSITION=TARGET_POSITION)

@app.route('/position')
def get_position():
    return jsonify(current_position)

@app.route('/command', methods=['POST'])
def receive_command():
    data = request.get_json()
    cmd = data.get('command', '').upper()
    if cmd in ("F", "B", "L", "R"):
        send_command(cmd)
        return {'status': 'sent'}
    return {'status': 'invalid'}, 400

@app.route('/navigation/start', methods=['POST'])
def start_navigation():
    global navigation_enabled, current_direction
    navigation_enabled = True
    current_direction = None
    print("[NAV] Navigation started")
    return {'status': 'started'}

@app.route('/navigation/stop', methods=['POST'])
def stop_navigation():
    global navigation_enabled, current_direction
    navigation_enabled = False
    current_direction = None
    print("[NAV] Navigation stopped")
    return {'status': 'stopped'}

@app.route('/navigation/status')
def get_navigation_status():
    return jsonify({
        'enabled': navigation_enabled,
        'current_direction': current_direction,
        'target': TARGET_POSITION,
        'threshold': NAVIGATION_THRESHOLD
    })

# ═══════════════════════════════════════════════════════════════════════════════
# TEST FUNCTIONS (for development)
# ═══════════════════════════════════════════════════════════════════════════════

def test_navigation():
    """Test navigation calculations at different positions."""
    test_positions = [
        (0.0, 0.0),    # Bottom left
        (3.0, 0.0),    # Bottom right
        (1.5, 2.6),    # Top center
        (1.5, 1.3),    # Target (should return None)
        (0.5, 0.5),    # Near bottom left
        (2.5, 2.0),    # Near top right
    ]

    print("[TEST] Navigation directions from different positions:")
    for x, y in test_positions:
        direction = calculate_direction(x, y, TARGET_POSITION["x"], TARGET_POSITION["y"])
        distance = math.sqrt((x - TARGET_POSITION["x"])**2 + (y - TARGET_POSITION["y"])**2)
        print(f"  Position ({x}, {y}) -> Direction: {direction}, Distance: {distance:.2f}m")

# Uncomment to run navigation test: test_navigation()

# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    # Start BLE thread
    ble_thread = threading.Thread(target=start_ble_thread, daemon=True)
    ble_thread.start()

    # Start UDP command server
    udp_thread = threading.Thread(target=udp_command_server, daemon=True)
    udp_thread.start()

    # For hardware testing, comment out the simulation thread above
    # For software testing, uncomment the simulation thread

    # Start Flask app
    app.run(host='0.0.0.0', port=5001, debug=False)