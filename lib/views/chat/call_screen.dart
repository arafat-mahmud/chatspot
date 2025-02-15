import 'package:flutter/material.dart';

// Define a CallRecord class to hold call details
class CallRecord {
  final String caller;
  final String time;
  // Add more fields as necessary

  CallRecord(this.caller, this.time);
}

class CallScreen extends StatefulWidget {
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  List<CallRecord> callHistory = []; // List to store call records

  // Function to add a call record
  void addCallRecord(String caller) {
    String time = DateTime.now().toString(); // Get current time
    setState(() {
      callHistory.add(CallRecord(caller, time)); // Add new record
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recent'),
      ),
      body: ListView.builder(
        itemCount: callHistory.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(callHistory[index].caller),
            subtitle: Text(callHistory[index].time),
          );
        },
      ),
      // Call this function when a call ends
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          addCallRecord('John Doe'); // Example caller
        },
        child: Icon(Icons.add_call),
      ),
    );
  }
}
