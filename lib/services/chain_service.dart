import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart';

import '../config.dart';
import '../models/tugas.dart';

class ChainService {
  late final Web3Client _client;
  late final EthPrivateKey _credentials;
  late final DeployedContract _contract;
  Timer? _eventTimer;
  int? _lastCheckedBlock;

  String get walletAddress => _credentials.address.with0x.toLowerCase();

  Future<void> init() async {
    _client = Web3Client(Config.rpcUrl, http.Client());
    _credentials = EthPrivateKey.fromHex(Config.privateKey);

    final contractAddr = EthereumAddress.fromHex(Config.contractAddress);
    final code = await _client.getCode(contractAddr);
    if (code.isEmpty) {
      throw Exception(
        'Tidak ada smart contract di ${Config.contractAddress} pada RPC ini.',
      );
    }

    final raw = await rootBundle.loadString('assets/ChainTodo.json');
    final decoded = jsonDecode(raw);
    final abi = decoded is Map ? decoded['abi'] : decoded;

    _contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'ChainTodo'),
      contractAddr,
    );
  }

  ContractFunction _fn(String name) {
    final matches = _contract.functions.where((f) => f.name == name);
    if (matches.isEmpty) {
      throw Exception('Fungsi "$name" tidak ditemukan di ABI ChainTodo.json');
    }
    return matches.first;
  }

  ContractEvent? _eventOpsional(String name) {
    final matches = _contract.events.where((e) => e.name == name);
    return matches.isEmpty ? null : matches.first;
  }

  // ---------- EVENT LISTENER (HTTP Polling getLogs) ----------

  Future<void> mulaiPantauEvent({
    required void Function(String jenisEvent) onEventMasuk,
    Duration interval = const Duration(seconds: 6),
  }) async {
    hentikanPantauEvent();
    _lastCheckedBlock = await _client.getBlockNumber();

    final kandidatEvent = [
      'TugasBaru',
      'TugasSelesai',
      'TugasDiedit',
      'TugasDihapus',
    ];

    final eventsAktif = <String, ContractEvent>{};
    for (final nama in kandidatEvent) {
      final ev = _eventOpsional(nama);
      if (ev != null) eventsAktif[nama] = ev;
    }

    if (eventsAktif.isEmpty) return;

    _eventTimer = Timer.periodic(interval, (_) async {
      try {
        final latestBlock = await _client.getBlockNumber();
        final fromBlock = (_lastCheckedBlock ?? latestBlock) + 1;
        if (fromBlock > latestBlock) return;

        String? eventTerdeteksi;
        for (final entry in eventsAktif.entries) {
          final logs = await _client.getLogs(
            FilterOptions.events(
              contract: _contract,
              event: entry.value,
              fromBlock: BlockNum.exact(fromBlock),
              toBlock: BlockNum.exact(latestBlock),
            ),
          );
          if (logs.isNotEmpty) {
            eventTerdeteksi = entry.key;
            break;
          }
        }

        _lastCheckedBlock = latestBlock;

        if (eventTerdeteksi != null) {
          onEventMasuk(eventTerdeteksi);
        }
      } catch (_) {
        // Abaikan error jaringan sementara saat polling agar aplikasi tetap berjalan
      }
    });
  }

  void hentikanPantauEvent() {
    _eventTimer?.cancel();
    _eventTimer = null;
  }

  // ---------- READ (free, no gas) ----------

  Future<List<Tugas>> ambilSemua() async {
    final hasil = await _client.call(
      sender: _credentials.address,
      contract: _contract,
      function: _fn(Config.fnJumlah),
      params: [],
    );
    final jumlah = (hasil.first as BigInt).toInt();

    final daftar = <Tugas>[];
    for (var i = 0; i < jumlah; i++) {
      final r = await _client.call(
        sender: _credentials.address,
        contract: _contract,
        function: _fn(Config.fnAmbil),
        params: [BigInt.from(i)],
      );

      final judul = r[0] as String;
      final alamatPembuat = r[3] is EthereumAddress
          ? (r[3] as EthereumAddress).with0x.toLowerCase()
          : r[3].toString().toLowerCase();
      final sudahDihapus = r.length > 4 && r[4] is bool && (r[4] as bool);

      if (sudahDihapus ||
          judul.isEmpty ||
          alamatPembuat == '0x0000000000000000000000000000000000000000') {
        continue;
      }

      daftar.add(
        Tugas(
          id: i,
          isi: judul,
          selesai: r[1] as bool,
          pembuat: alamatPembuat,
        ),
      );
    }
    return daftar;
  }

  // ---------- WRITE (costs Sepolia ETH) ----------

  Future<String> tambah(String isi) => _kirim(Config.fnTambah, [isi]);

  Future<String> toggle(int id) => _kirim(Config.fnToggle, [BigInt.from(id)]);

  Future<String> edit(int id, String judulBaru) =>
      _kirim('editTugas', [BigInt.from(id), judulBaru]);

  Future<String> hapus(int id) => _kirim('hapusTugas', [BigInt.from(id)]);

  Future<String> _kirim(String fnName, List<dynamic> params) async {
    final gasPrice = await _client.getGasPrice();
    return _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: _fn(fnName),
        parameters: params,
        maxGas: 500000,
        gasPrice: gasPrice,
      ),
      chainId: Config.chainId,
    );
  }

  /// Wait until the transaction is mined (about 12 seconds on Sepolia)
  Future<void> tunggu(String txHash) async {
    for (var i = 0; i < 60; i++) {
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) {
        if (receipt.status == false) {
          throw Exception('Transaksi gagal (reverted)');
        }
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw Exception('Timeout menunggu transaksi');
  }
}