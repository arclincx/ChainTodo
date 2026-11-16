import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get rpcUrl => dotenv.env['RPC_URL']!.trim();
  static int get chainId => int.parse(dotenv.env['CHAIN_ID']!.trim());
  static String get contractAddress => dotenv.env['CONTRACT_ADDRESS']!.trim();
  static String get privateKey => dotenv.env['PRIVATE_KEY']!.trim();

  // Matches your ABI function names exactly
  static const fnTambah = 'tambahTugas';
  static const fnToggle = 'tandaiSelesai';
  static const fnJumlah = 'jumlahTugas';
  static const fnAmbil = 'ambilTugas';
}