import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class JournalService {
  final String crossRefApi = "https://api.crossref.org/journals/";
  final String doajApi = "https://doaj.org/api/v2/search/journals/";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> fetchJournalDetails(String issn) async {
    try {
      var crossRefResponse = await http.get(Uri.parse('$crossRefApi$issn'));
      var doajResponse = await http.get(Uri.parse('${doajApi}issn:$issn'));

      Map<String, dynamic>? crossRefData;
      Map<String, dynamic>? doajData;

      if (crossRefResponse.statusCode == 200) {
        var jsonData = jsonDecode(crossRefResponse.body);
        if (jsonData.containsKey("message")) {
          crossRefData = jsonData["message"];
        }
      }

      if (doajResponse.statusCode == 200) {
        var jsonData = jsonDecode(doajResponse.body);
        if (jsonData.containsKey("results") && jsonData["results"].isNotEmpty) {
          doajData = jsonData["results"][0]["bibjson"];
        }
      }

      String? publishedArticles =
          crossRefData?['counts']?['total-dois']?.toString() ?? "Not Available";

      Map<String, dynamic> journalDetails = {
        "name": crossRefData?["title"] ?? doajData?["title"] ?? "Not Found",
        "publisher": crossRefData?["publisher"] ?? "Not Found",
        "issn": issn,
        "published_articles": publishedArticles,
      };

      if (journalDetails["name"] == "Not Found") {
        await _firestore
            .collection("unknown_issn")
            .doc(issn)
            .set({"issn": issn, "timestamp": FieldValue.serverTimestamp()});
      }
      return journalDetails;
    } catch (e) {
      print("Error fetching journal details: $e");
      return null;
    }
  }
}

class ISSNChecker extends StatefulWidget {
  const ISSNChecker({super.key});

  @override
  State<ISSNChecker> createState() => _ISSNCheckerState();
}

class _ISSNCheckerState extends State<ISSNChecker> {
  final TextEditingController _controller = TextEditingController();
  final JournalService _journalService = JournalService();
  List<Map<String, String>> messages = [];

  void _sendMessage() async {
    String query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      messages.add({"user": query});
    });

    var response = await _journalService.fetchJournalDetails(query);
    String reply = response != null
        ? "📖 Name: ${response["name"]}\n🏢 Publisher: ${response["publisher"]}\n🔢 ISSN: ${response["issn"]}\n📄 Published Articles: ${response["published_articles"]}"
        : "⚠️ Journal details not found. Please check ISSN or try again.";

    setState(() {
      messages.add({"bot": reply});
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text("ISSN Checker", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  var entry = messages[index].entries.first;
                  bool isUser = entry.key == "user";
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blueAccent : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "Enter ISSN or journal name...",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  FloatingActionButton(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }
}
