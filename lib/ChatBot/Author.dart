import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class JournalService {
  final String crossRefApi = "https://api.crossref.org/journals/";
  final String doajApi = "https://doaj.org/api/v2/search/journals/";
  final String webOfScienceApi = "https://api.webofscience.com/journals/";
  final String uecApi = "https://api.uec.org/journals/";
  final String semanticScholarApi =
      "https://api.semanticscholar.org/graph/v1/author/search?query=";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isValidIssn(String input) {
    final RegExp issnPattern = RegExp(r'^\d{4}-\d{3}[\dX]$');
    return issnPattern.hasMatch(input);
  }

  Future<Map<String, dynamic>?> fetchJournalDetails(String issn) async {
    if (!isValidIssn(issn)) return null;

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

      String? journalUrl = crossRefData?['URL'] ?? doajData?['link']?[0]['url'];
      String? publishedArticles =
          crossRefData?['counts']?['total-dois']?.toString() ?? "Not Available";
      String? status =
          doajData?['open_access'] != null ? "Open Access" : "Unknown";

      Map<String, dynamic> journalDetails = {
        "name": crossRefData?["title"] ?? doajData?["title"] ?? "Not Found",
        "publisher": crossRefData?["publisher"] ?? "Not Found",
        "issn": issn,
        "status": status,
        "published_articles": publishedArticles,
        "journal_link": journalUrl ?? "No link available"
      };

      if (journalDetails["name"] == "Not Found") {
        await _firestore
            .collection("unknown_author")
            .doc(issn)
            .set({"query": issn, "timestamp": FieldValue.serverTimestamp()});
      }

      return journalDetails;
    } catch (e) {
      print("Error fetching journal details: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAuthorPublications(
      String author) async {
    try {
      var response = await http.get(Uri.parse('$semanticScholarApi$author'));

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        List<dynamic> authors = jsonData['data'] ?? [];

        if (authors.isNotEmpty) {
          String authorId = authors.first['authorId'];
          var papersResponse = await http.get(Uri.parse(
              'https://api.semanticscholar.org/graph/v1/author/$authorId/papers?fields=title,url'));

          if (papersResponse.statusCode == 200) {
            var papersData = jsonDecode(papersResponse.body);
            List<dynamic> papers = papersData['data'] ?? [];

            return papers
                .map((paper) => {
                      "title": paper["title"] ?? "No title available",
                      "link": paper["url"] ?? "#"
                    })
                .toList();
          }
        }
      }
    } catch (e) {
      print("Error fetching author publications: $e");
    }
    return [];
  }
}

class Author extends StatefulWidget {
  const Author({super.key});

  @override
  State<Author> createState() => _AuthorState();
}

class _AuthorState extends State<Author> {
  final TextEditingController _controller = TextEditingController();
  final JournalService _journalService = JournalService();
  final GoogleTranslator translator = GoogleTranslator();
  final FlutterTts _flutterTts = FlutterTts();
  List<Map<String, String>> messages = [];
  String selectedLanguage = 'en';
  bool _isLoading = false;

  void _sendMessage() async {
    String query = _controller.text.trim();
    if (query.isEmpty) return;

    messages.clear();

    String translatedQuery = (await translator.translate(query, to: 'en')).text;

    setState(() {
      messages.add({"user": query});
      _isLoading = true;
    });

    bool isIssn = _journalService.isValidIssn(translatedQuery);

    if (isIssn) {
      var response = await _journalService.fetchJournalDetails(translatedQuery);
      if (response != null) {
        String botMessage =
            "📖 **Name**: ${response["name"]}\n🔗 **Journal Link**: ";
        botMessage =
            (await translator.translate(botMessage, to: selectedLanguage)).text;

        messages.add({"bot": botMessage, "link": response["journal_link"]});
      } else {
        String errorMessage = "⚠️ Invalid ISSN or no journal found.";
        messages.add({
          "bot":
              (await translator.translate(errorMessage, to: selectedLanguage))
                  .text
        });
      }
    } else {
      var publications =
          await _journalService.fetchAuthorPublications(translatedQuery);
      if (publications.isNotEmpty) {
        for (var pub in publications) {
          String botMessage = "📌 ${pub['title']}";
          messages.add({
            "bot":
                (await translator.translate(botMessage, to: selectedLanguage))
                    .text,
            "link": pub['link'] ?? "#"
          });
        }
      } else {
        messages.add({
          "bot": (await translator.translate(
                  "❌ No publications found for this author.",
                  to: selectedLanguage))
              .text
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
    _controller.clear();
  }

  Future<void> _translateScreen() async {
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].containsKey("bot")) {
        String originalMessage = messages[i]["bot"]!;
        messages[i]["bot"] =
            (await translator.translate(originalMessage, to: selectedLanguage))
                .text;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Author Published Journals"),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.translate, color: Colors.blue),
            onPressed: () => _showLanguageDialog(),
          ),
        ],
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total Journals Found: ${messages.length}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  children: messages.map((msg) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(msg["user"] ?? msg["bot"]!,
                            style: TextStyle(fontSize: 16)),
                        subtitle: msg["link"] != null
                            ? InkWell(
                                onTap: () => launchUrl(Uri.parse(msg["link"]!)),
                                child: Text("🔗 Open",
                                    style: TextStyle(color: Colors.blue)),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
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
                  setState(() {
                    selectedLanguage = 'en';
                  });
                  Navigator.pop(context);
                  _translateScreen();
                },
              ),
              ListTile(
                title: Text("Hindi"),
                onTap: () {
                  setState(() {
                    selectedLanguage = 'hi';
                  });
                  Navigator.pop(context);
                  _translateScreen();
                },
              ),
              ListTile(
                title: Text("Spanish"),
                onTap: () {
                  setState(() {
                    selectedLanguage = 'es';
                  });
                  Navigator.pop(context);
                  _translateScreen();
                },
              ),
              ListTile(
                title: Text("French"),
                onTap: () {
                  setState(() {
                    selectedLanguage = 'fr';
                  });
                  Navigator.pop(context);
                  _translateScreen();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: "Enter the Authore Name to see the Published Journal",
                filled: true,
                fillColor: Colors.blueGrey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                      BorderSide(color: Colors.deepPurpleAccent, width: 2),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    _controller.clear();
                  },
                ),
              ),
              style: TextStyle(color: Colors.white),
              cursorColor: Colors.white,
            ),
          ),
          SizedBox(width: 10),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
