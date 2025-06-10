import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PdfToTextExtractor extends StatefulWidget {
  @override
  _PdfToTextExtractorState createState() => _PdfToTextExtractorState();
}

class _PdfToTextExtractorState extends State<PdfToTextExtractor> {
  String extractedText = "";
  bool isLoading = false;

  Future<void> pickAndExtractTextFromPdf() async {
    setState(() {
      isLoading = true;
      extractedText = "";
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File pdfFile = File(result.files.single.path!);
      await extractTextFromPdf(pdfFile);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> extractTextFromPdf(File pdfFile) async {
    final document = await PdfDocument.openFile(pdfFile.path);
    final textRecognizer = TextRecognizer();
    StringBuffer allText = StringBuffer();

    for (int i = 0; i < document.pagesCount; i++) {
      final page = await document.getPage(i + 1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
      );

      await page.close();

      if (pageImage != null) {
        Uint8List imageBytes = pageImage.bytes;
        img.Image? image = img.decodeImage(imageBytes);
        if (image != null) {
          final tempDir = await getTemporaryDirectory();
          final imageFile = File('${tempDir.path}/page_$i.jpg');
          await imageFile.writeAsBytes(img.encodeJpg(image));

          final inputImage = InputImage.fromFile(imageFile);
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          allText.writeln("📄 Page ${i + 1}:");
          allText.writeln(recognizedText.text);
          allText.writeln("\n------------------\n");
        }
      }
    }

    setState(() {
      extractedText = allText.toString();
    });

    textRecognizer.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("📄 PDF to Text Extractor"),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              children: [
                // If Loading, show progress indicator
                if (isLoading)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Extracting text, please wait...",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: extractedText.isEmpty
                        ? Center(
                            child: Text(
                              "📄 No text extracted yet.\nTap the button below to select a PDF.",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  extractedText,
                                  style: TextStyle(fontSize: 16, height: 1.5),
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),

          // Floating button at the bottom
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: pickAndExtractTextFromPdf,
              backgroundColor: Colors.deepPurple,
              icon: Icon(Icons.upload_file, color: Colors.white),
              label: Text("Pick PDF", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
