import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/company.dart';

class HiveService {
  static const String companyBoxName = 'companies';
  static const String profileBoxName = 'profileBox'; // 追加

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Adapters
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(SelectionTrackAdapter());
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(SelectionPhaseAdapter());
    if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(DesireLevelAdapter());
    if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(ScheduleTypeAdapter());
    if (!Hive.isAdapterRegistered(14)) Hive.registerAdapter(ScheduleItemAdapter());
    if (!Hive.isAdapterRegistered(15)) Hive.registerAdapter(EsQaAdapter());
    if (!Hive.isAdapterRegistered(16)) Hive.registerAdapter(CompanyAdapter());

    // Boxes
    await Hive.openBox<Company>(companyBoxName);
    await Hive.openBox(profileBoxName); // 追加（文字列保存用。型指定なしでOK）

    _initialized = true;
  }

  static Box<Company> companyBox() {
    return Hive.box<Company>(companyBoxName);
  }

  static Box profileBox() {
    return Hive.box(profileBoxName);
  }
}