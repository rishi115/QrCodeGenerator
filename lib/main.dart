import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

import 'firebase_options.dart';

permissionhandler(){
  Permission.storage.request();

}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );// Initialize Firebase
  permissionhandler();
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File to QR Code',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FilePickerScreen(),
    );
  }
}



class FilePickerScreen extends StatefulWidget {
  @override
  _FilePickerScreenState createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  bool loading = false;
  String? _downloadUrl;
  ScreenshotController screenshotController = ScreenshotController();
  String? _savedImagePath;

  // Pick file, upload to Firebase Storage, and generate download URL
  Future<void> _pickFile() async {
    setState(() {
      loading = true;
    });
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      File file = File(result.files.single.path!);

      try {
        String fileName = result.files.single.name;
        Reference storageReference =
        FirebaseStorage.instance.ref().child('uploads/$fileName');

        UploadTask uploadTask = storageReference.putFile(file);
        await uploadTask.whenComplete(() => null);

        String downloadUrl = await storageReference.getDownloadURL();

        setState(() {
          _downloadUrl = downloadUrl;
          loading = false;
        });
      } catch (e) {
        print('Error uploading file: $e');
        setState(() {
          _downloadUrl = null;
        });
      }
    } else {
      setState(() {
        _downloadUrl = null;

      });
    }
  }

  // Capture the QR code as an image and save it locally
  Future<bool> _requestPermissions(
      {required BuildContext context}
      ) async {
    await Permission.storage.request();
    if (await Permission.storage.request().isGranted) {
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission is required to download files')),
      );
      return false;
    }
  }

  // Capture the QR code as an image and save it to the Downloads folder
  Future<void> _downloadQRCode(
      BuildContext context, ScreenshotController screenshotController
      ) async {
    if (_downloadUrl == null) return;

    bool hasPermission = await _requestPermissions(context: context);
    if (!hasPermission) return;

    // Capture the QR code widget as an image
    screenshotController.capture().then((image) async {
      if (image != null) {
        final directory = await getExternalStorageDirectory(); // Use external directory
        final downloadsDir = Directory('/storage/emulated/0/Download');

        if (!(await downloadsDir.exists())) {
          downloadsDir.createSync(recursive: true);
        }

        String imagePath = join(downloadsDir.path, 'qr_code.png');
        File imgFile = File(imagePath);
        await imgFile.writeAsBytes(image);

        setState(() {
          _savedImagePath = imagePath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR code saved in Downloads folder at $imagePath')),
        );
      }
    }).catchError((error) {
      print(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File to QR Code'),
      ),
      body: loading ?CircularProgressIndicator():
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickFile,
              child: Text('Pick File and Upload'),
            ),
            SizedBox(height: 20),
            _downloadUrl != null
                ? Column(
              children: [
                Text('File uploaded!'),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Download URL: $_downloadUrl'),
                ),
                SizedBox(height: 20),
                // Ensure the QrImage is treated as a Widget inside Screenshot
                Screenshot(
                  controller: screenshotController,
                  child: Builder(
                    builder: (context) {
                      return QrImageView(
                        data: _downloadUrl!,
                        version: QrVersions.auto,
                        size: 200.0,
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (){
                    _downloadQRCode(context, screenshotController);
                    },
                  child: Text('Download QR Code Image'),
                ),
                _savedImagePath != null
                    ? Text('QR code saved at: $_savedImagePath')
                    : Container(),
              ],
            )
                : Text('No file uploaded yet'),
          ],
        ),
      ),
    );
  }
}

