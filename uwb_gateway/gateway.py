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
    ADDR_A1: ("A1", 0.0, 0.0),  # Bottom left
    ADDR_A2: ("A2", 3.0, 0.0),  # Bottom right
    ADDR_A3: ("A3", 1.5, 2.6),  # Above center
}

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
        elif have_a1 and have_a2:
            baseline = math.dist((ANCHORS[ADDR_A1][1], ANCHORS[ADDR_A1][2]), (ANCHORS[ADDR_A2][1], ANCHORS[ADDR_A2][2]))
            x, y = tag_pos_2anchor(ranges[ADDR_A2], ranges[ADDR_A1], baseline)
            current_position = {"x": x, "y": y, "anchors": ranges}
            send_position_to_flutter(x, y, ranges)

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
    <script>
        function sendCmd(cmd) {
            fetch('/command', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({command: cmd})
            });
        }
    </script>
</body>
</html>
    ''', ble_connected=ble_connected, current_position=current_position)

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