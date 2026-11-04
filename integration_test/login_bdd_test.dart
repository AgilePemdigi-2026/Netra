import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:netra_app/screens/admin/login_screen.dart';

import 'bdd_helper.dart';

// Dibaca dari --dart-define-from-file=env.json (tidak ditulis di kode).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_KEY');

// Opsional: untuk menguji login berhasil. Tambahkan dua key ini
// ke env.json milikmu sendiri. Kalau kosong, test tersebut di-SKIP.
const _emailAdmin = String.fromEnvironment('TEST_ADMIN_EMAIL');
const _sandiAdmin = String.fromEnvironment('TEST_ADMIN_PASSWORD');

bool get _supabaseSiap => _supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty;

bool get _adaAkunAdmin =>
    _supabaseSiap && _emailAdmin.isNotEmpty && _sandiAdmin.isNotEmpty;

Future<void> bukaLogin(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    ),
  );

  await tungguTeks(tester, find.text('Kata Sandi'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BDD - Login Admin NETRA', () {
    setUpAll(() async {
      if (_supabaseSiap) {
        await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseKey);
      }
    });

    testWidgets(
      'BDD-LOG-01: Halaman login ditampilkan dengan benar',
      (WidgetTester tester) async {
        // GIVEN: Pengguna membuka halaman login
        await bukaLogin(tester);

        // THEN: Elemen utama login tampil
        expect(find.text('Dinas Sosial Kota Surabaya'), findsOneWidget);
        expect(
          find.text(
            'Sistem Pelayanan Aksesibilitas\n'
            'Publik Berbasis AI untuk\n'
            'Disabilitas Netra di Surabaya',
          ),
          findsOneWidget,
        );
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Kata Sandi'), findsOneWidget);
        expect(find.text('Masukkan email petugas'), findsOneWidget);
        expect(find.text('Masukkan kata sandi'), findsOneWidget);
        expect(find.text('Masuk'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));

        // Fitur "Lupa Sandi" sudah dihapus dari desain.
        expect(find.text('Lupa Sandi?'), findsNothing);

        debugPrint('BDD-LOG-01 PASS: Halaman login tampil lengkap');
      },
    );

    testWidgets(
      'BDD-LOG-02: Login gagal ketika email dan kata sandi kosong',
      (WidgetTester tester) async {
        // GIVEN: Kedua kolom kosong
        await bukaLogin(tester);

        // WHEN: Pengguna menekan Masuk
        await tekan(tester, find.text('Masuk'));

        // THEN: Muncul pesan validasi dan tetap di halaman login
        expect(find.text('Email wajib diisi.'), findsOneWidget);
        expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
        expect(find.text('Masuk'), findsOneWidget);

        debugPrint('BDD-LOG-02 PASS: Validasi kolom kosong muncul');
      },
    );

    testWidgets(
      'BDD-LOG-03: Login gagal ketika format email tidak valid',
      (WidgetTester tester) async {
        // GIVEN: Email tidak berformat benar dan kata sandi terisi
        await bukaLogin(tester);

        await tester.enterText(find.byType(TextFormField).first, 'bukanemail');
        await tester.enterText(find.byType(TextFormField).last, 'abc12345');
        await tester.pump(const Duration(milliseconds: 300));

        // WHEN: Pengguna menekan Masuk
        await tekan(tester, find.text('Masuk'));

        // THEN: Muncul pesan format email tidak valid
        expect(find.text('Format email tidak valid.'), findsOneWidget);

        debugPrint('BDD-LOG-03 PASS: Format email tidak valid ditolak');
      },
    );

    testWidgets(
      'BDD-LOG-04: Pengguna dapat menampilkan dan menyembunyikan kata sandi',
      (WidgetTester tester) async {
        // GIVEN: Kata sandi tersembunyi secara bawaan
        await bukaLogin(tester);
        expect(find.byTooltip('Tampilkan kata sandi'), findsOneWidget);

        // WHEN: Pengguna menekan ikon mata
        await tekan(tester, find.byTooltip('Tampilkan kata sandi'));

        // THEN: Kata sandi ditampilkan, ikon berubah
        expect(find.byTooltip('Sembunyikan kata sandi'), findsOneWidget);

        // WHEN: Ditekan lagi
        await tekan(tester, find.byTooltip('Sembunyikan kata sandi'));

        // THEN: Kembali tersembunyi
        expect(find.byTooltip('Tampilkan kata sandi'), findsOneWidget);

        debugPrint('BDD-LOG-04 PASS: Tampil/sembunyi kata sandi berfungsi');
      },
    );

    testWidgets(
      'BDD-LOG-05: Login gagal dengan akun yang tidak terdaftar',
      (WidgetTester tester) async {
        // GIVEN: Email dan kata sandi valid secara format, tapi tidak terdaftar
        await bukaLogin(tester);

        await tester.enterText(
          find.byType(TextFormField).first,
          'bukan.admin@example.com',
        );
        await tester.enterText(find.byType(TextFormField).last, 'salah-12345');
        await tester.pump(const Duration(milliseconds: 300));

        // WHEN: Pengguna menekan Masuk
        await tekan(tester, find.text('Masuk'));

        // THEN: Muncul pesan error dan tetap di halaman login
        await tungguTeks(
          tester,
          find.text('Email atau kata sandi salah.'),
          maksDetik: 25,
        );
        expect(find.text('Masuk'), findsOneWidget);
        expect(find.text('Dashboard Admin (Sementara)'), findsNothing);

        debugPrint('BDD-LOG-05 PASS: Akun tidak terdaftar ditolak');
      },
      skip: !_supabaseSiap,
    );

    testWidgets(
      'BDD-LOG-06: Admin terdaftar berhasil login',
      (WidgetTester tester) async {
        // GIVEN: Admin memasukkan email dan kata sandi yang benar
        await bukaLogin(tester);

        await tester.enterText(
          find.byType(TextFormField).first,
          _emailAdmin,
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          _sandiAdmin,
        );
        await tester.pump(const Duration(milliseconds: 300));

        try {
          // WHEN: Admin menekan Masuk
          await tekan(tester, find.text('Masuk'));

          // THEN: Admin masuk ke dashboard.
          // Catatan: saat ini masih dashboard sementara. Jika dashboard
          // asli sudah menggantikan, sesuaikan teks pengecekan ini.
          await tungguTeks(
            tester,
            find.text('Login berhasil'),
            maksDetik: 25,
          );
          expect(find.text('Dashboard Admin (Sementara)'), findsOneWidget);

          debugPrint('BDD-LOG-06 PASS: Admin berhasil login');
        } finally {
          await Supabase.instance.client.auth.signOut();
        }
      },
      skip: !_adaAkunAdmin,
    );
  });
}