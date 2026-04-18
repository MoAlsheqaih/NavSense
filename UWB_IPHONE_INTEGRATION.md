# Complete UWB-iPhone App Integration Architecture

## 🎯 **Data Flow Architecture**

### **UWB Position Data → iPhone App**
```
ESP32 UWB Module → BLE TX → Python Gateway (port 8081) → UDP → Flutter App (port 8081)
     ↓                     ↓              ↓                      ↓            ↓
Real-time ranges    JSON data      Trilateration        Position data    Map display
```

### **Navigation Commands → ESP32 Motors**
```
Flutter Navigation → UDP → Python Gateway (port 8082) → BLE RX → ESP32 → Haptic Motors
     ↓                  ↓          ↓                      ↓          ↓        ↓
Direction calc      'F/B/L/R'   Command forward       BLE write   PWM control Vibration
```

---

## 🔄 **Dual Navigation Systems**

### **1. Flutter App Navigation (Route-based)**
- **Purpose**: Turn-by-turn navigation along planned routes
- **Trigger**: User selects destination, app computes route
- **Commands**: Sends F/B/L/R when approaching waypoints
- **Example**: "Turn left in 50 meters" → sends 'L' command

### **2. Python Gateway Navigation (Continuous Auto-navigation)**
- **Purpose**: Autonomous guidance to fixed target
- **Trigger**: Start navigation button in gateway dashboard
- **Commands**: Continuous F/B/L/R based on live position
- **Example**: Position (1.2, 0.8) → target (1.5, 1.3) → sends 'R' command

---

## 📱 **iPhone App Features**

### **UWB Integration**
- **Real-time positioning**: Updates at 10Hz from ESP32
- **Anchor visualization**: Shows distances to all anchors
- **Accuracy display**: Position uncertainty in meters
- **Connection status**: BLE and UWB connectivity indicators

### **Navigation Features**
- **Route planning**: Computes paths between waypoints
- **Haptic feedback**: Sends commands to ESP32 motors
- **Session logging**: Records navigation events
- **Simulation mode**: Test without hardware

---

## 🌐 **Network Ports Used**

| Port | Direction | Purpose | Protocol |
|------|-----------|---------|----------|
| 8081 | Gateway → Flutter | UWB position data | UDP |
| 8082 | Flutter → Gateway | Navigation commands | UDP |
| N/A  | Gateway ↔ ESP32 | UWB ranges + haptic commands | BLE |

---

## 🔧 **Testing the Integration**

### **Full System Test:**
1. **Start ESP32** with UWB + BLE
2. **Start Gateway**: `python gateway.py`
3. **Start Flutter App**: `flutter run`
4. **Enable Navigation**: 
   - Option A: Gateway dashboard "Start Navigation"
   - Option B: Flutter app route navigation

### **Expected Behavior:**
- UWB positions update in real-time on both gateway dashboard and Flutter map
- Navigation commands trigger ESP32 motor patterns
- Seamless coordination between all components

---

## 🎉 **Integration Status**

✅ **UWB ↔ iPhone App**: Fully connected via UDP  
✅ **Gateway ↔ ESP32**: BLE positioning + commands  
✅ **Navigation → Motors**: Both manual and automatic modes  
✅ **Real-time Updates**: 10Hz position, sub-second commands  

**The system provides a complete end-to-end navigation experience from UWB positioning through haptic motor feedback!**</content>
<parameter name="filePath">/Users/nawaf/Desktop/Senior Project Files/Senior Report/NavSense/UWB_IPHONE_INTEGRATION.md