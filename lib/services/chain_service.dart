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

  Future<void> init() async {
    _client = Web3Client(Config.rpcUrl, http.Client());
    _credentials = EthPrivateKey.fromHex(Config.privateKey);

    final raw = await rootBundle.loadString('assets/ChainTodo.json');
    final decoded = jsonDecode(raw);
    // Works with a plain ABI array or a full Hardhat/Foundry artifact
    final abi = decoded is Map ? decoded['abi'] : decoded;

    _contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'ChainTodo'),
      EthereumAddress.fromHex(Config.contractAddress),
    );
  }

  ContractFunction _fn(String name) {
    final matches = _contract.functions.where((f) => f.name == name);
    if (matches.isEmpty) {
      throw Exception('Fungsi "$name" tidak ditemukan di ABI ChainTodo.json');
    }
    return matches.first;
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
      daftar.add(Tugas(id: i, isi: r[0] as String, selesai: r[1] as bool));
    }
    return daftar;
  }

  // ---------- WRITE (costs Sepolia ETH) ----------

  Future<String> tambah(String isi) => _kirim(Config.fnTambah, [isi]);

  Future<String> toggle(int id) => _kirim(Config.fnToggle, [BigInt.from(id)]);

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