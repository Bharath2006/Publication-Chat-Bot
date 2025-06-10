import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:open_file/open_file.dart';

import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

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
      home: EditablePDFScreen(),
    );
  }
}

class EditablePDFScreen extends StatefulWidget {
  @override
  _EditablePDFScreenState createState() => _EditablePDFScreenState();
}

class _EditablePDFScreenState extends State<EditablePDFScreen> {
  File? _savedFile;

  Future<void> _pickAndConvertPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File pdfFile = File(result.files.single.path!);

      // Load the scanned PDF
      final PdfDocument document =
          PdfDocument(inputBytes: pdfFile.readAsBytesSync());

      // Get the Downloads directory (no permission needed)
      Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to access downloads folder")),
        );
        return;
      }

      String outputPath = '${downloadsDir.path}/edite_output.pdf';

      // Save the converted PDF
      File savedFile = File(outputPath);
      await savedFile.writeAsBytes(document.saveSync());
      document.dispose();

      // Update state
      setState(() {
        _savedFile = savedFile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File saved in Downloads folder")),
      );
    }
  }

  void _openFile() {
    if (_savedFile != null) {
      OpenFile.open(_savedFile!.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scanned PDF to Editable PDF")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickAndConvertPDF,
              child: Text("Upload and Convert PDF"),
            ),
            if (_savedFile != null) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("File saved at: ${_savedFile!.path}"),
              ),
              ElevatedButton(
                onPressed: _openFile,
                child: Text("Open Converted PDF"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
