import 'package:flutter/material.dart';

class EmailVerificationPage extends StatelessWidget {
  final TextEditingController _emailController =
      TextEditingController(text: 'arafat.mahmud.2001@gmail.com');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Address'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.email,
              size: 100,
              color: Colors.green,
            ),
            SizedBox(height: 20),
            Text(
              'Email helps you access your account. It isn\'t visible to others.',
              style: TextStyle(
                  fontSize: 14.0, color: const Color.fromARGB(179, 0, 0, 0)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style: TextStyle(
                      fontSize: 18.0,
                      color: const Color.fromARGB(255, 0, 0, 0)),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _emailController.text,
                        style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 0, 0, 0)),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: const Color.fromARGB(179, 0, 0, 0),
                      ),
                      onPressed: () {
                        _showEditDialog(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: const Color.fromARGB(153, 26, 169, 31),
                ),
                SizedBox(width: 5),
                Text(
                  'Verified',
                  style: TextStyle(fontSize: 16.0, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Email Address'),
          content: TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'New Email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Save the new email address
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Email updated'),
                  ),
                );
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
