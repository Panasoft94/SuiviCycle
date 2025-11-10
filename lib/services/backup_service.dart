import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart'; // Import DatabaseHelper

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper(); // Instantiate DatabaseHelper

  Future<void> backupDatabase(BuildContext context) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, 'cycles.db');
      final File sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur: La base de données source est introuvable.')));
        return;
      }

      final Uint8List fileBytes = await sourceFile.readAsBytes();

      String? resultPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Veuillez choisir un emplacement pour la sauvegarde',
        fileName: 'cycles_backup_${DateTime.now().toIso8601String().substring(0, 10)}.db',
        bytes: fileBytes,
      );

      if (resultPath != null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sauvegarde réussie: $resultPath')),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sauvegarde annulée.')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    }
  }

  Future<void> restoreDatabase(BuildContext context) async {
    try {
      // 1. Let the user pick a file and read its content (bytes).
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Use FileType.any and let the OS handle filtering if possible.
        withData: true, // This is crucial to get the file content as bytes.
      );

      if (result != null && result.files.single.bytes != null) {
        final Uint8List backupBytes = result.files.single.bytes!;

        // 2. Get the path to the app's database.
        final dbPath = await getDatabasesPath();
        final destinationPath = join(dbPath, 'cycles.db');

        // 3. Close the existing database.
        await _dbHelper.closeDB();

        // 4. Write the backup bytes to the database file, overwriting it.
        final File dbFile = File(destinationPath);
        await dbFile.writeAsBytes(backupBytes);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restauration réussie ! Veuillez redémarrer l\'application.')),
        );

      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restauration annulée ou fichier invalide.')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la restauration: $e')),
      );
    }
  }
}
