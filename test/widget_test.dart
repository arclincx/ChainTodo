import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

import 'package:chaintodo/models/tugas.dart';
import 'package:chaintodo/services/chain_service.dart';

class FakeChainService extends ChainService {
  final List<Tugas> items = [
    Tugas(id: 0, isi: 'Belajar Solidity', selesai: true, pembuat: '0xaaa'),
    Tugas(id: 1, isi: 'Deploy Sepolia', selesai: false, pembuat: '0xbbb'),
  ];

  void Function(String jenisEvent)? _listener;

  @override
  String get walletAddress => '0xaaa';

  @override
  Future<void> init() async {}

  @override
  Future<List<Tugas>> ambilSemua() async => List.of(items);

  @override
  Future<String> tambah(String isi) async {
    items.add(
      Tugas(
        id: items.length,
        isi: isi,
        selesai: false,
        pembuat: walletAddress,
      ),
    );
    simulasiEvent('TugasBaru');
    return '0x1111111111';
  }

  @override
  Future<String> toggle(int id) async {
    final idx = items.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final lama = items[idx];
      items[idx] = Tugas(
        id: lama.id,
        isi: lama.isi,
        selesai: true,
        pembuat: lama.pembuat,
      );
      simulasiEvent('TugasSelesai');
    }
    return '0x2222222222';
  }

  @override
  Future<String> edit(int id, String judulBaru) async {
    final idx = items.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final lama = items[idx];
      items[idx] = Tugas(
        id: lama.id,
        isi: judulBaru,
        selesai: lama.selesai,
        pembuat: lama.pembuat,
      );
      simulasiEvent('TugasDiedit');
    }
    return '0x3333333333';
  }

  @override
  Future<String> hapus(int id) async {
    items.removeWhere((t) => t.id == id);
    simulasiEvent('TugasDihapus');
    return '0x4444444444';
  }

  @override
  Future<void> tunggu(String txHash) async {}

  @override
  Future<void> mulaiPantauEvent({
    required void Function(String jenisEvent) onEventMasuk,
    Duration interval = const Duration(seconds: 6),
  }) async {
    _listener = onEventMasuk;
  }

  @override
  void hentikanPantauEvent() {
    _listener = null;
  }

  void simulasiEvent(String namaEvent) {
    _listener?.call(namaEvent);
  }
}

void main() {
  test('Derivasi alamat Ethereum dari private key berjalan benar', () {
    final key = EthPrivateKey.fromHex(
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    expect(key.address.with0x.toLowerCase(), startsWith('0x'));
    expect(key.address.with0x.length, 42);
  });

  test('Tambah, edit, hapus, filter milik saya, dan event listener berjalan sesuai', () async {
    final service = FakeChainService();
    final logEvent = <String>[];

    await service.mulaiPantauEvent(
      onEventMasuk: (jenis) => logEvent.add(jenis),
    );

    // 1. Tambah tugas baru
    await service.tambah('Uji Edit dan Hapus');
    var semua = await service.ambilSemua();
    expect(semua.length, 3);
    expect(logEvent.last, 'TugasBaru');

    // 2. Filter milik wallet sendiri
    final milikSaya =
        semua.where((t) => t.pembuat == service.walletAddress).toList();
    expect(milikSaya.length, 2);

    // 3. Edit judul tugas
    await service.edit(2, 'Judul Tugas Diperbarui');
    semua = await service.ambilSemua();
    expect(semua.firstWhere((t) => t.id == 2).isi, 'Judul Tugas Diperbarui');
    expect(logEvent.last, 'TugasDiedit');

    // 4. Hapus tugas
    await service.hapus(2);
    semua = await service.ambilSemua();
    expect(semua.any((t) => t.id == 2), isFalse);
    expect(logEvent.last, 'TugasDihapus');

    service.hentikanPantauEvent();
  });
}