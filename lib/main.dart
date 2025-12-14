import 'package:flutter/material.dart';
import 'package:mqtt_box_fixed/MqttCorrect.dart';



void main() => runApp(const MqttMiniApp());

class MqttMiniApp extends StatelessWidget {
  const MqttMiniApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(
        debugShowCheckedModeBanner: false, 
        //home: MqttCorrect(),
       home: MqttCorrect(),
        );
}
