import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/constants/app_constants.dart';
import 'data/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    // ignore: avoid_print
    print('Firebase initialization failed (expected in some environments): $e');
  }

  try {
    await Hive.initFlutter();
    await StorageService.registerAdapters();
    await Hive.openBox<dynamic>(AppConstants.hiveBoxSettings);
  } catch (e) {
    // ignore: avoid_print
    print('Hive initialization failed: $e');
  }

  runApp(const ProviderScope(child: BookstrApp()));
}
