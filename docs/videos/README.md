# Test Case Video Demonstrations

This folder contains short video demonstrations of the executed test cases
for the MQTT Mobile Application project.  
Each video provides visual evidence of the application behavior for the
corresponding test case.

Not all test cases require video demonstrations.  
Core functional and security-related test cases are demonstrated using videos,
while simpler or conceptual test cases are validated through execution and documentation.

## Test Case Videos

- **TC-01: MQTT Broker Connection Using TCP Protocol**  
  Demonstrates successful connection to a public MQTT broker using the TCP protocol.

- **TC-02: MQTT Broker Connection Failure Handling**  
  Demonstrates proper error handling when an invalid or unreachable broker address is used.

- **TC-03: MQTT Connection with Authentication Enabled**  
  Demonstrates successful MQTT broker connection using username and password authentication.

- **TC-05: Subscribe to MQTT Topic**  
  Demonstrates subscribing to an MQTT topic and receiving messages.

- **TC-06: Publish MQTT Message**  
  Demonstrates publishing a message to an MQTT topic and logging the outgoing message.

- **TC-07: Subscribe Using Wildcard Topic**  
  Demonstrates wildcard topic subscriptions using `+` and `#`.

- **TC-08: Retained Message Reception**  
  Demonstrates reception of a retained message immediately after subscription.

- **TC-09: Auto-Reconnect After Network Loss**  
  Demonstrates automatic reconnection to the MQTT broker after temporary network interruption.

- **TC-10: Preservation of Subscriptions After Reconnect**  
  Demonstrates automatic restoration of subscribed topics after reconnection.

- **TC-11: Profile Creation and Persistence**  
  Demonstrates saving connection profiles and restoring them after application restart.

- **TC-12: Import / Export Functionality**  
  Demonstrates exporting application data to a backup file and restoring it through import.

- **TC-13: Standard SSL/TLS**  
  Demonstrates secure MQTT communication using standard SSL/TLS with the system trust store.

- **TC-14: TLS Connection Using CA Certificate Only**  
  Demonstrates TLS verification using a manually configured CA certificate (`mosquitto.org.crt`).

## Conceptual / Non-Demonstrated Test Cases

- **TC-15: Self-Signed Certificate Support (Conceptual)**  
  This test case validates application support for self-signed certificates in private or development environments.  
  A video demonstration is not included because a public CA-signed broker was used for testing.

## Notes

- All demonstrated videos directly correspond to the documented test cases in the project report.
- Video demonstrations focus on observable application behavior and successful execution.
- Conceptual test cases are justified and documented but not demonstrated using video.

