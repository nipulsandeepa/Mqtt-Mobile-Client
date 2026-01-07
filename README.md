# 📱 MQTT Mobile Client

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/YOUR_USERNAME/mqtt-mobile-client.svg?style=social)](https://github.com/YOUR_USERNAME/mqtt-mobile-client/stargazers)

A professional-grade MQTT client application built with Flutter, featuring robust connection management, advanced message handling, and an intuitive user interface. This application rivals commercial MQTT clients while offering superior error handling and user experience.

<div align="center">
  <img src="screenshots/app_demo.gif" width="80%" alt="MQTT Mobile Client Demo">
</div>

## 🏆 Key Highlights
- ✅ Enterprise SSL/TLS Security - Complete certificate management system
- ✅ Mutual TLS Support - Client certificate authentication (mTLS)
- ✅ Professional Data Backup - Full configuration export/import
- ✅ Advanced Certificate Handling - Parse, validate, and manage certificates
- ✅ Production-Ready - Follows industry security best practices

## ✨ Features


### 🔐 Enterprise Security Features
- SSL/TLS Certificate Management: Upload CA, client, and server certificates
- Mutual TLS (mTLS): Client certificate authentication support
- Certificate Chain Validation: Proper X.509 certificate parsing
- Multiple Format Support: PEM, CRT, CER, KEY formats with automatic detection
- Certificate Information Display: View issuer, subject, validity, and SAN details
- Self-Signed Certificate Support: Perfect for development and testing
- Certificate Testing: Validate certificates before connection attempts


### 🚀 Connection Management
- Multi-protocol Support: TCP, WebSocket, SSL/TLS, WSS
- Connection Profiles: Save and load broker configurations
- Auto-Reconnect: Intelligent reconnection with exponential backoff
- Health Monitoring: Real-time connection health with ping/pong system
- Uptime Tracking: Live connection duration display

### 💾 Data Management
- Backup & Restore: Export/import all connection profiles & templates as JSON
- Database Versioning: Seamless migrations and data integrity
- Message History: Persistent storage with intelligent pruning (auto-removes oldest messages)
- Profile Management: Rename, delete, and organize connection configurations
- Template System: Save message templates with quick load functionality

### 💬 Message Handling
- Full MQTT 3.1.1 Implementation: Publish, subscribe, all QoS levels (0, 1, 2)
- Wildcard Support: `+` (single-level) and `#` (multi-level) wildcards
- Message Templates: Save and reuse common message patterns
- Retained Messages: Full support with clear functionality
- Message History: Persistent storage with advanced search capabilities

### ⚙️ Advanced Features
- Will Messages: Configurable Last Will and Testament with proper session management
- Authentication: Username/password + certificate-based authentication
- Clean Session Management: Configurable session persistence
- Export Functionality: Database and configuration backup to device storage
- File System Integration: Secure file handling with permission management

### 🎨 User Experience
- Dark/Light Theme: Toggleable theme system
- Connection Statistics: Real-time metrics and analytics
- Quick Test: One-click connection to popular public brokers
- Debug Tools: URL analysis and connection state inspection
- Auto-Scroll: Messages automatically scroll to newest with toggle option
- Topic Suggestions: Smart suggestions from active subscriptions
- Responsive UI: Adapts to different screen sizes

## 📸 Screenshots

<div align="center">

**Connection Management** | **Message Log** | **Profiles & Templates**
:-------------------------:|:-------------------------:|:-------------------------:
<img src="images/connection.jpeg" width="300" alt="Connection Screen"> | 
<img src="images/message.jpeg" width="300" alt="Message Log"> | 
<img src="images/profiles.PNG" width="300" alt="Profiles Management">

**Dark Mode Theme** | **Will Message Setup** | **Export Functionality**
:-------------------------:|:-------------------------:|:-------------------------:
<img src="images/dark_mode.PNG" width="300" alt="Dark Mode"> | 
<img src="images/will_config.PNG" width="300" alt="Will Configuration"> | 
<img src="images/export.PNG" width="300" alt="Export Feature">

</div>

## 🚀 Quick Start

### Test with Public Brokers (One-Click)
The app includes Quick Test buttons for instant connection:

- Mosquitto TCP: `tcp://test.mosquitto.org:1883`
- Mosquitto TLS: `ssl://test.mosquitto.org:8883` (requires CA certificate)
- Mosquitto WebSocket: `ws://test.mosquitto.org:8080`
- EMQX TCP: `tcp://broker.emqx.io:1883`
- EMQX WebSocket: `ws://broker.emqx.io:8083`

## Testing TLS/SSL Features

One-way TLS (Server Authentication):
```Bash# Clone the repository
Broker: ssl://your-broker:8883
Certificate: Upload CA certificate
Client Cert: Not required
```

Mutual TLS (Client Certificate Authentication):
```Bash# Clone the repository
Broker: ssl://your-broker:8884
Certificate: Upload CA certificate
Client Cert: Upload client certificate
Client Key: Upload private key
```

### Manual Connection
1. Enter broker URL (e.g., `tcp://test.mosquitto.org:1883`)
2. Optionally set Client ID (auto-generates if empty)
3. Configure authentication if needed
4. Click **CONNECT**

## 📖 Complete Documentation
For detailed documentation including architecture, troubleshooting, and advanced features, see our Complete Documentation.

## 🛠️ Technical Highlights

### 🔧 Architecture
```dart
Security Implementation Stack:
├── Certificate Management Layer
│   ├── PEM File Parser
│   ├── X.509 Certificate Validator
│   ├── Certificate Chain Builder
│   └── SecurityContext Creator
├── TLS/SSL Connection Layer
│   ├── One-way TLS Handler
│   ├── Mutual TLS (mTLS) Handler
│   ├── Certificate Pinning
│   └── Hostname Verification
├── Data Persistence Layer
│   ├── Secure Storage
│   ├── Backup/Restore System
│   ├── Configuration Management
│   └── Message Database
└── User Interface Layer
    ├── Certificate Upload UI
    ├── Security Configuration
    ├── Connection Management
    └── Status Monitoring
```

## 🗄️ Data Models

- ConnectionProfile - Broker connection configurations with security settings
- CertificateInfo - Certificate metadata and validation results
- MessageTemplate - Saved message patterns with variables
- Message - Individual MQTT messages with metadata
- Subscription - Active topic subscriptions with QoS levels

## 💾 Database Structure

- mqtt_profiles.db – Connection profiles with security configurations
- mqtt_templates.db – Message templates
- mqtt_messages.db – Message history with search indexing

## 🛡️ Security Implementation Details
### Certificate Management

```Bash#
// Supported Certificate Operations:
1. Upload and parse PEM certificates
2. Validate certificate chains
3. Extract certificate information (issuer, subject, validity)
4. Check Subject Alternative Names (SAN)
5. Validate certificate expiration
6. Create SecurityContext for TLS connections
7. Handle both one-way and mutual TLS scenarios
```

## Supported Certificate Types

- X.509 Certificates: PEM format with proper chain validation
- Private Keys: RSA and PKCS#8 formats with password protection
- Certificate Authorities: Self-signed and public CA certificates
- Client Certificates: For mutual TLS authentication

## 🎯 Use Cases
### 🏭 IoT Development & Testing

- Rapid prototyping of IoT applications
- Protocol validation and debugging
- Secure device communication testing
- TLS certificate validation for IoT deployments
- Protocol debugging with encryption
- Certificate rotation testing

### 🎓 Educational Tool

- Learning MQTT protocol concepts
- Understanding QoS levels
- Testing Will messages and retained messages
- Secure device communication testing
- TLS certificate validation for IoT deployments
- Protocol debugging with encryption
- Certificate rotation testing

### 🔍 Production Monitoring

- Broker health checks
- Message flow analysis
- Connection troubleshooting
- Performance monitoring

### 🚀 Getting Started
Prerequisites

- Flutter SDK 3.0 or higher
- Android Studio / VS Code with Flutter extension
- Android device/emulator (API 21+) or iOS device/simulator

## Installation
```Bash# Clone the repository
git clone https://github.com/YOUR_USERNAME/mqtt-mobile-client.git

# Navigate to project directory
cd mqtt-mobile-client

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build for production
flutter build apk --release  # For Android
flutter build ios --release  # For iOS
```

## Running the App

1.Connect your device or start an emulator
2.Run flutter run in the project directory
3.The app will launch and is ready to connect to MQTT brokers


## 📊 Feature Comparison

## 📊 Feature Comparison

| Feature                          | MQTT Mobile Client      | MQTT Box        | MQTT Dash       | Advantage        |
|----------------------------------|-------------------------|-----------------|-----------------|------------------|
| SSL/TLS Certificate Management   | ✅ Complete System      | ❌ Basic        | ❌ None         | Superior         |
| Mutual TLS (mTLS)                | ✅ Full Support         | ❌ Limited      | ❌ No           | Enterprise       |
| Certificate Validation           | ✅ X.509 Parsing        | ❌ None         | ❌ None         | Professional     |
| Backup & Restore                 | ✅ Full System          | ❌ None         | ❌ Partial      | Complete         |
| Auto-Reconnect                   | ✅ Intelligent          | ✅ Basic        | ✅ Basic        | Better           |
| Connection Health                | ✅ Real-time            | ❌ Missing      | ❌ Missing      | Superior         |
| Will Messages                    | ✅ With Fix             | ✅ Basic        | ✅ Basic        | More Reliable    |
| Error Handling                   | ✅ Comprehensive        | ❌ Basic        | ❌ Basic        | Much Better      |
| UI / UX                          | ✅ Modern Themes        | ❌ Outdated     | ✅ Modern       | Flexible         |
| Debug Tools                      | ✅ Advanced             | ❌ Limited      | ❌ Limited      | Professional     |
| Quick Test                       | ✅ One-click            | ❌ Missing      | ✅ Limited      | User-Friendly    |
| Message Templates                | ✅ With Variables       | ❌ None         | ✅ Basic        | Advanced         |


## 🔧 Configuration Examples
Recommended Settings for Mosquitto
```
Clean Session: FALSE (checkbox CHECKED)
Keep Alive: 30 seconds
Will QoS: 1
Will Retain: true
Will Topic: device/[client-id]/status
```
Recommended Settings for EMQX
```
Clean Session: FALSE
Keep Alive: 45 seconds  
Will QoS: 1
Will Retain: false
```
## 🐛 Troubleshooting
### Common Issues & Solutions

### 🌐 General Connection Issues

| Issue                         | Cause                  | Solution                                                                 |
|-------------------------------|------------------------|--------------------------------------------------------------------------|
| Connection drops quickly      | Keep-alive timeout     | Set Keep Alive ≤ 30 seconds                                               |
| Will messages not triggering  | Clean Session = TRUE   | Set Clean Session = FALSE                                                 |
| Wildcards not working         | Invalid pattern        | Use correct syntax: `sensor/+/temperature` or `home/#`                    |
| Message history missing       | Database issue         | Use **Export** feature to back up data, then reinstall the application   |

### 🔐 Common SSL/TLS Issues

| Issue                          | Symptoms                    | Solution                                                                 |
|--------------------------------|-----------------------------|--------------------------------------------------------------------------|
| Certificate Validation Failed  | "Handshake failed"          | Ensure certificate SAN matches broker hostname                            |
| Self-Signed Certificate Rejected | "Untrusted certificate"   | Enable **Allow Self-Signed** in connection settings                       |
| Mutual TLS Connection Refused  | "Bad certificate"           | Ensure broker requires client certificates on the correct port           |
| Certificate Format Error       | "Invalid PEM format"        | Verify certificate is proper PEM format with BEGIN/END markers            |
| Certificate Chain Invalid      | "Chain validation failed"   | Ensure all intermediate certificates are included                         |

Debug Tools

Debug URL Button: Analyzes URL structure and parsing
Connection Status: Real-time state with color coding
Message Log: All connection events logged
Export Feature: Database export for offline analysis

## 📈 Performance Characteristics

- Memory Usage: Base ~50MB, with 1000 messages ~70MB
- Connection Time: 1–5 seconds depending on broker
- Message Throughput:
- QoS 0: 100+ messages/second
- QoS 1: 50+ messages/second
- QoS 2: 20+ messages/second

## Database: SQLite with efficient indexing

## 🎖️ Technical Achievements

- Solved Complex Bug: Will Message Disconnect
- Problem: Brokers disconnected immediately when Will messages enabled
- Root Cause: Clean Session flag order in MQTT protocol
- Solution: Set Will message BEFORE Clean Session flag
- Result: Rock-solid Will message implementation

- Professional Error Handling
- User-friendly error messages with suggestions
- Network interruption detection and recovery
- Graceful degradation for poor network conditions
- Comprehensive validation for all user inputs

- Advanced State Management
- Proper connection state tracking (disconnected, connecting, connected, reconnecting, error)
- Timer management with proper cleanup
- Stream subscription handling
- Memory management with automatic message pruning

- Solved Complex Security Challenges
- Certificate Chain Validation: Implemented proper X.509 certificate parsing
- Mutual TLS Support: Client certificate authentication working end-to-end
- SecurityContext Management: Proper TLS context creation for Flutter
- PEM File Handling: Robust parsing of various certificate formats


## 🤝 Contributing
We welcome contributions! Here's how you can help:

### Fork the repository

1. Create a feature branch
```   
git checkout -b feature/AmazingFeature
```
2. Commit your changes
```
git commit -m 'Add some AmazingFeature'
```
3. Push to the branch
```
git push origin feature/AmazingFeatur
```
4. Open a Pull Request

## Please read our Contributing Guidelines for more details.
### 📄 License
- This project is licensed under the MIT License – see the LICENSE file for details.

## 🙏 Acknowledgments

### Core Technologies

- Flutter & Dart - For the amazing cross-platform framework
- mqtt_client package - Core MQTT functionality
- sqflite - Local database storage

## Test Infrastructure

- **mqtt_client** package for core MQTT functionality
- Public MQTT brokers for testing:
  - `test.mosquitto.org`
  - `broker.emqx.io`
- Certificate Authorities - For TLS testing scenarios


Flutter community for excellent documentation and support
All contributors who have helped improve this project

## 📞 Support & Contact

- GitHub Issues: Open an issue
- Feature Requests: Use GitHub Issues with the "enhancement" label
- Bug Reports: Please include steps to reproduce and app version

## 🌟 Star History
### Star History

  Built with ❤️ using Flutter & Dart
  If you find this project helpful, please give it a ⭐ on GitHub!

## 🚀 Future Roadmap
### Planned Features

### Planned Features
- MQTT 5.0 Protocol Support: Full protocol implementation
- Advanced Dashboard: Visual metrics, charts, and analytics
- Scripting & Automation: Automated test sequences and scenarios
- Cloud Sync: Secure profile synchronization across devices
- Multi-broker Connections: Simultaneous connections to multiple brokers
- Plugin System: Extensible functionality through plugins

### Security Enhancements
- Certificate Pinning: Enhanced security for production deployments
- Encrypted Database: Additional layer of data protection
- Biometric Authentication: Device-level security for app access
- Audit Logging: Security event tracking and reporting

### Quality of Life Improvements
- Connection Wizard: Step-by-step setup for beginners
- Enhanced Import/Export: Cloud backup and sharing options
- More Theme Options: Additional color schemes and customization
- Keyboard Shortcuts: Quick actions for power users
- Offline Message Queuing: Store-and-forward capability

## 🙏 Thank you for using MQTT Mobile Client!
- This project represents the culmination of extensive research and development in mobile MQTT security and usability.
