import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PdfToTextConverter extends StatefulWidget {
  @override
  _PdfToTextConverterState createState() => _PdfToTextConverterState();
}

class _PdfToTextConverterState extends State<PdfToTextConverter> {
  List<String> extractedTexts = [];
  bool isLoading = false;
  late TextRecognizer textRecognizer;

  @override
  void initState() {
    super.initState();
    textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin); // Supports Tamil, Hindi, English
  }

  Future<void> pickAndConvertPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File pdfFile = File(result.files.single.path!);
      await convertPdfToText(pdfFile);
    }
  }

  Future<void> convertPdfToText(File pdfFile) async {
    setState(() => isLoading = true);

    final document = await PdfDocument.openFile(pdfFile.path);
    final tempDir = await getTemporaryDirectory();

    List<String> texts = [];

    for (int i = 0; i < document.pagesCount; i++) {
      String text = await renderPageAndExtractText(document, i + 1, tempDir);
      texts.add(text);
    }

    setState(() {
      extractedTexts = texts;
      isLoading = false;
    });

    document.close();
  }

  Future<String> renderPageAndExtractText(
      PdfDocument document, int pageNumber, Directory tempDir) async {
    final page = await document.getPage(pageNumber);
    final PdfPageImage? pageImage = await page.render(
      width: page.width,
      height: page.height,
    );
    await page.close();

    if (pageImage != null) {
      Uint8List processedBytes = pageImage.bytes;
      File imageFile = File('${tempDir.path}/page_$pageNumber.png');
      await imageFile.writeAsBytes(processedBytes);
      return await extractTextFromImage(imageFile);
    }
    return "";
  }

  Future<String> extractTextFromImage(File imageFile) async {
    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      return recognizedText.text; // Extracted text
    } catch (e) {
      return "Error in OCR: $e";
    }
  }

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("PDF to Tamil, Hindi & English Text")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: pickAndConvertPdf,
            child: Text("Pick PDF & Extract Text"),
          ),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
                  child: extractedTexts.isNotEmpty
                      ? ListView.builder(
                          itemCount: extractedTexts.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Page ${index + 1}:\n${extractedTexts[index]}\n",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            );
                          },
                        )
                      : Center(child: Text("No text extracted yet")),
                ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: PdfToTextConverter(),
  ));
}
