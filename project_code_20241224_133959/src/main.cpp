#include <WiFi.h>
#include <WebSocketsServer.h>

// Replace with your network credentials
const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";

// Create a WebSocketsServer instance on port 81
WebSocketsServer webSocket = WebSocketsServer(81);

// ECG Pin
const int ecgPin = 34; // ADC1_6

void setup() {
  Serial.begin(115200);
  
  // Initialize Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while(WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" Connected");

  // Start WebSocket server
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
}

void loop() {
  webSocket.loop();

  // Read ECG data
  int rawValue = analogRead(ecgPin);
  double voltage = (rawValue / 4095.0) * 3.3; // Assuming 12-bit ADC and 3.3V reference

  // Send ECG voltage to all connected clients
  String ecgData = String(voltage, 4);
  webSocket.broadcastTXT(ecgData);

  delay(100); // Adjust the delay as needed for your sampling rate
}

// WebSocket event handler
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.printf("[%u] Disconnected!\n", num);
      break;
    case WStype_CONNECTED: {
        IPAddress ip = webSocket.remoteIP(num);
        Serial.printf("[%u] Connected from %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
      }
      break;
    case WStype_TEXT:
      Serial.printf("[%u] Text: %s\n", num, payload);
      break;
    default:
      break;
  }
} 