import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _results = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    setState(() {
      _results = []; // Clear results for UI demonstration
    });

    if (query.isNotEmpty) {
      try {
        // Use the query directly with '@' for matching
        final usernameWithAt = query.startsWith('@') ? query : '@$query';
        print("Searching for username: $usernameWithAt"); // Debugging output

        final userDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: usernameWithAt)
            .get();

        print(
            "Documents retrieved: ${userDocs.docs.length}"); // Debugging output

        if (userDocs.docs.isNotEmpty) {
          setState(() {
            _results =
                userDocs.docs.map((doc) => doc['username'] as String).toList();
          });
        } else {
          print("No matching usernames found."); // Debugging output
        }
      } catch (e) {
        print("Error searching for user: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  _onSearchChanged(value); // Trigger search on Enter
                },
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _results.length, // Number of results to display
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(_results[index]), // Display the username
            );
          },
        ),
      ),
    );
  }
}
