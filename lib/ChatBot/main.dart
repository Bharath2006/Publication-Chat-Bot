import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController _controller = TextEditingController();
  List<Map<String, String>> messages = [];
  final String apiKey = "AIzaSyALpMiX8Lquv5fl3G4FTbzf698SGbp_Qa8";
  final String apiUrl =
      "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=AIzaSyALpMiX8Lquv5fl3G4FTbzf698SGbp_Qa8";

  void sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": message});
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": message}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String botReply = responseData["candidates"]?[0]?["content"]?["parts"]
                ?[0]?["text"] ??
            "No response received";

        setState(() {
          messages.add({"role": "bot", "text": botReply});
        });
      } else {
        setState(() {
          messages.add({
            "role": "bot",
            "text": "Error: ${response.statusCode} - ${response.body}"
          });
        });
      }
    } catch (e) {
      setState(() {
        messages
            .add({"role": "bot", "text": "An error occurred: ${e.toString()}"});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chatbot")),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => sendMessage("Tell me about AI"),
                child: Text("AI Info"),
              ),
              ElevatedButton(
                onPressed: () => sendMessage("How to verify journals?"),
                child: Text("Verify Journals"),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                bool isUser = msg["role"] == "user";
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                          color: isUser ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => sendMessage(_controller.text),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: ChatScreen()));
}
