import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/tugas.dart';
import 'services/chain_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ChainTodoApp());
}

class ChainTodoApp extends StatelessWidget {
  const ChainTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChainTodo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HalamanTugas(),
    );
  }
}

class HalamanTugas extends StatefulWidget {
  const HalamanTugas({super.key});

  @override
  State<HalamanTugas> createState() => _HalamanTugasState();
}

class _HalamanTugasState extends State<HalamanTugas> {
  final _service = ChainService();
  List<Tugas> _daftar = [];
  bool _loading = true;
  bool _mengirim = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    try {
      await _service.init();
      await _muatUlang();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _muatUlang() async {
    setState(() => _loading = true);
    try {
      final hasil = await _service.ambilSemua();
      setState(() {
        _daftar = hasil;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _jalankanTx(Future<String> Function() aksi, String pesan) async {
    setState(() => _mengirim = true);
    _snack('$pesan... menunggu konfirmasi blok');
    try {
      final hash = await aksi();
      await _service.tunggu(hash);
      _snack('Berhasil! tx: ${hash.substring(0, 10)}...');
      await _muatUlang();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _mengirim = false);
    }
  }

  void _snack(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _dialogTambah() async {
    final controller = TextEditingController();
    final isi = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tugas baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tulis tugas...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (isi != null && isi.isNotEmpty) {
      await _jalankanTx(() => _service.tambah(isi), 'Menambah tugas');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChainTodo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _muatUlang,
          ),
        ],
        bottom: _mengirim
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _isi(),
      floatingActionButton: FloatingActionButton(
        onPressed: (_loading || _mengirim) ? null : _dialogTambah,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _isi() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_daftar.isEmpty) return const Center(child: Text('Belum ada tugas'));

    return RefreshIndicator(
      onRefresh: _muatUlang,
      child: ListView.builder(
        itemCount: _daftar.length,
        itemBuilder: (_, i) {
          final t = _daftar[i];
          return CheckboxListTile(
            value: t.selesai,
            title: Text(
              t.isi,
              style: TextStyle(
                decoration: t.selesai ? TextDecoration.lineThrough : null,
              ),
            ),
            onChanged: (_mengirim || t.selesai)
              ? null
              : (_) => _jalankanTx(
                () => _service.toggle(t.id),
                'Mengubah status',
              ),
          );
        },
      ),
    );
  }
}