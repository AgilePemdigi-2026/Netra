import 'package:integration_test/integration_test.dart';

import 'netra_test.dart' as beranda;
import 'login_bdd_test.dart' as login;
import 'pengaturan_bdd_test.dart' as pengaturan;
import 'kamera_bdd_test.dart' as kamera;
import 'laporan_perjalanan_bdd_test.dart' as laporan;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Beranda: BDD-01, BDD-02
  beranda.main();

  // Login Admin: BDD-LOG-01 sampai BDD-LOG-06
  login.main();

  // Pengaturan: BDD-PGT-01 sampai BDD-PGT-09
  pengaturan.main();

  // Kamera dan Selesai Perjalanan: BDD-KAM-01, 02 dan BDD-SEL-01 sampai 03
  kamera.main();

  // Laporan Perjalanan: BDD-LAP-01 sampai BDD-LAP-04
  laporan.main();
}