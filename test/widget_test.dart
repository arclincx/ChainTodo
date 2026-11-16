import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

// Check if your chain_service.dart is in lib/ or lib/services/
import '../lib/models/tugas.dart';
import '../lib/services/chain_service.dart';

class FakeChainService extends ChainService {
  final List<Tugas> _items = [
    Tugas(id: 0, isi: 'Belajar Smart Contract', selesai: false),
    Tugas(id: 1, isi: 'Deploy ke Sepolia', selesai: true),
  ];

  @override
  Future<void> init() async {}

  @override
  Future<List<Tugas>> ambilSemua() async => List.from(_items);

  @override
  Future<String> tambah(String isi) async {
    _items.add(Tugas(id: _items.length, isi: isi, selesai: false));
    return '0xmocktxhash_tambah';
  }

  @override
  Future<String> toggle(int id) async {
    final index = _items.indexWhere((t) => t.id == id);
    if (index != -1) {
      _items[index] = Tugas(
        id: _items[index].id,
        isi: _items[index].isi,
        selesai: !_items[index].selesai,
      );
    }
    return '0xmocktxhash_toggle';
  }

  @override
  Future<void> tunggu(String txHash) async {}
}

void main() {
  test('EthPrivateKey derives a valid EthereumAddress', () {
    const samplePrivateKey =
        '0x0000000000000000000000000000000000000000000000000000000000000001';
    final credentials = EthPrivateKey.fromHex(samplePrivateKey);
    expect(
      credentials.address.with0x,
      '0x7e5f4552091a69125d5dfcb7b8c2659029395bdf',
    );
  });

  test('FakeChainService reads, adds, and toggles Tugas items', () async {
    final service = FakeChainService();
    await service.init();

    var list = await service.ambilSemua();
    expect(list.length, 2);
    expect(list.first.isi, 'Belajar Smart Contract');

    await service.tambah('Test Flutter Web3');
    list = await service.ambilSemua();
    expect(list.length, 3);
    expect(list.last.isi, 'Test Flutter Web3');
    expect(list.last.selesai, false);

    await service.toggle(2);
    list = await service.ambilSemua();
    expect(list.last.selesai, true);
  });
}