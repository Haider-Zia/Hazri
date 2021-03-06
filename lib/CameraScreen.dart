import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart'  as firebase_storage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'AttendanceList.dart';
import 'package:http/http.dart' as http;


//In addition to the Camera Screen Stateful Widget,
// this file contains a helper class,
// and a commented out Widget to Display a taken picture on a separate screen

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  final CameraDescription camera;

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _photoCountdown = 3;
  File? file;
  List<String> data = [];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;
  Future uploadFile() async {

    print('here1');
    if (file == null) return;
    final fileName = basename(file!.path);
    final destination = 'files';

    try {
      final ref = firebase_storage.FirebaseStorage.instance
          .ref(destination)
          .child('$fileName');
      await ref.putFile(file!);
      await ref.getDownloadURL().then(
            (value) => print("Done: $value"),
      );

    } catch (e) {
      print('error occured');
    }
  }
  //function to make http request to flask
  Future<http.Response> getFaceCoordinate(String link) async {
    ///MultiPart request
    String filename = basename(file!.path);
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(link),
    );
    Map<String, String> headers = {"Content-type": "multipart/form-data"};
    request.files.add(
      http.MultipartFile(
        'image',
        file!.readAsBytes().asStream(),
        file!.lengthSync(),
        filename: filename,
      ),
    );
    request.headers.addAll(headers);
    print("request: " + request.toString());
    var res = await request.send();
    var response = await http.Response.fromStream(res);
    print("This is response:" + response.body);
    print("This is res: ${res.statusCode} ");
    print("This is response: ${response.statusCode} ");
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future:  _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final mediaSize = MediaQuery.of(context).size;
            final scale =
                1 / (_controller.value.aspectRatio * mediaSize.aspectRatio);
            return ClipRect(
              clipper: _MediaSizeClipper(mediaSize),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
                child: CameraPreview(_controller),
              ),
            );
          } else {
            // Otherwise, display a loading indicator.
            return const Center(
                child: CircularProgressIndicator(
                  color: Colors.green,
                ));
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        height: 200,
        width: 200,
        child: FittedBox(
          child: FloatingActionButton(
            // Provide an onPressed callback.
            onPressed: () async {
              // Take the Picture in a try / catch block. If anything goes wrong,
              // catch the error.
              try {
                // Ensure that the camera is initialized.
                await _initializeControllerFuture;
                final image = await _controller.takePicture();
                // Attempt to take a picture and get the file `image`
                // where it was saved.

                setState(() {
                  _photoCountdown--;
                });

                if (_photoCountdown < 1) {

                  // If the picture was taken, display it on a new screen.
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DisplayPictureScreen(
                        // Pass the automatically generated path to
                        // the DisplayPictureScreen widget.
                        imagePath: image.path,
                      ),
                    ),
                  );
                  //   await Navigator.of(context).pushReplacement(MaterialPageRoute(
                  //       builder: (context) => AttendanceList(data: data)));
                }

                // final image = await _controller.takePicture();
                setState(() async {
                  if (image != null) {
                    file = File(image.path);
                    uploadFile();
                    final res = await getFaceCoordinate(
                        "http://cbc7-34-75-198-28.ngrok.io/face_detection");
                    //debugPrint(res.body);
                    final val = jsonDecode(res.body);
                    print("Val: $val");

                    for (var item in val['faces']) {
                      data.add("$item");
                    }
                    print(data);
                    debugPrint("$data");
                    await Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => AttendanceList(data: data)));


                  } else {
                    print('No image selected.');
                  }
                });

                // // If the picture was taken, display it on a new screen.
                // await Navigator.of(context).push(
                //   MaterialPageRoute(
                //     builder: (context) => DisplayPictureScreen(
                //       // Pass the automatically generated path to
                //       // the DisplayPictureScreen widget.
                //       imagePath: image.path,
                //     ),
                //   ),
                // );


              } catch (e) {
                if (kDebugMode) {
                  print(e);
                }
              }
            },
            child: _photoCountdown == 3
                ? Image.asset('assets/Hazri app icons_3 Square Snapshot.png')
                : _photoCountdown == 2
                ? Image.asset(
                'assets/Hazri app icons_2 Square Snapshot.png')
                : Image.asset(
                'assets/Hazri app icons_1 Square Snapshot.png'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
    );
  }




}

class _MediaSizeClipper extends CustomClipper<Rect> {
  final Size mediaSize;
  const _MediaSizeClipper(this.mediaSize);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, mediaSize.width, mediaSize.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}



class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key? key, required this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      backgroundColor: Colors.white,
      body: Image.file(File(imagePath)),
    );
  }
}