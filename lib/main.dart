import 'package:flutter/material.dart';
import 'app.dart';
import 'core/localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Localization().init();
  runApp(const SabziSetuApp());
}
