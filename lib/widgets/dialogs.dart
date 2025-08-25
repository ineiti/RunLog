import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

void showFileActionDialog(BuildContext context, String mimeType, String name, String content) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share File'),
              onTap: () async {
                Navigator.pop(context);
                final params = ShareParams(
                  files: [
                    XFile.fromData(
                      utf8.encode(content),
                      mimeType: mimeType,
                    ),
                  ],
                  fileNameOverrides: [name],
                );
                await SharePlus.instance.share(params);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save to Device'),
              onTap: () async {
                Navigator.pop(context);
                await FilePicker.platform.saveFile(
                  dialogTitle: 'Where to store the file:',
                  fileName: name,
                  bytes: utf8.encode(content),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}