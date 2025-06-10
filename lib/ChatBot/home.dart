import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:translator/translator.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'ISSN.dart';
import 'ocr.dart';
import 'Author.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.black87,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool _isLoading = false;
  bool _isTranslating = false;
  final translator = GoogleTranslator();

  final String apiKey = "AIzaSyALpMiX8Lquv5fl3G4FTbzf698SGbp_Qa8";
  final String apiUrl =
      "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=AIzaSyALpMiX8Lquv5fl3G4FTbzf698SGbp_Qa8";

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty || _isLoading) return;

    setState(() {
      messages.add({"role": "user", "text": message});
      _isLoading = true;
    });
    _controller.clear();

    final response = await _fetchBotResponse(message);

    setState(() {
      if (response != null) {
        messages.add({"role": "bot", "text": response});
      } else {
        messages.add({"role": "bot", "text": "Error: Failed to get response"});
      }
      _isLoading = false;
    });
  }

  Future<String?> _fetchBotResponse(String message) async {
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
        return responseData["candidates"]?[0]?["content"]?["parts"]?[0]
                ?["text"] ??
            "No response received";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "An error occurred: ${e.toString()}";
    }
  }

  Future<void> translateMessages(String targetLanguage) async {
    setState(() {
      _isTranslating = true;
    });

    List<Map<String, String>> translatedMessages = [];

    for (var message in messages) {
      String text = message["text"]!;
      var translation = await translator.translate(text, to: targetLanguage);
      translatedMessages
          .add({"role": message["role"]!, "text": translation.text});
    }

    setState(() {
      messages.clear();
      messages.addAll(translatedMessages);
      _isTranslating = false;
    });
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    bool isUser = msg["role"] == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        color: isUser ? Colors.blueAccent : Colors.grey[300],
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            msg["text"]!,
            style: TextStyle(color: isUser ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Expanded(
      child: ListView.separated(
        padding: EdgeInsets.all(10),
        itemCount: messages.length,
        separatorBuilder: (_, __) => SizedBox(height: 5),
        itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                ),
                style: TextStyle(color: Colors.black),
                minLines: 1,
                maxLines: 5,
              ),
            ),
          ),
          SizedBox(width: 10),
          _isLoading
              ? CircularProgressIndicator()
              : FloatingActionButton(
                  onPressed: () => sendMessage(_controller.text),
                  backgroundColor: Colors.blueAccent,
                  mini: true,
                  child: Icon(Icons.send, color: Colors.white),
                ),
          SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.translate, color: Colors.blueAccent),
            onPressed: _isTranslating
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Select Language"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text("English"),
                                onTap: () {
                                  translateMessages("en");
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: Text("Hindi"),
                                onTap: () {
                                  translateMessages("hi");
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: Text("Spanish"),
                                onTap: () {
                                  translateMessages("es");
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: Text("French"),
                                onTap: () {
                                  translateMessages("fr");
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: Text("Chat Bot"),
        backgroundColor: Colors.blueAccent,
        elevation: 5,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildMessageList(),
          _buildInputArea(),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGradientButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ISSNChecker()),
                  );
                },
                icon: Icons.open_in_new,
                text: "Product Details",
                colors: [Colors.blueAccent, Colors.deepPurpleAccent],
              ),
              SizedBox(width: 10),
              _buildGradientButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Author()),
                  );
                },
                icon: Icons.pageview,
                text: "Price Checker",
                colors: [Colors.green, Colors.teal],
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGradientButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PdfToTextConverter()),
                  );
                },
                icon: Icons.picture_as_pdf,
                text: "Upload & Extract Image",
                colors: [Colors.redAccent, Colors.orangeAccent],
              ),
            ],
          ),
          SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onTap,
    required IconData icon,
    required String text,
    required List<Color> colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
