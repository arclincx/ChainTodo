import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/tugas.dart';
import 'services/chain_service.dart';

enum FilterTugas { semua, belumSelesai, selesai, milikSaya }

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
  FilterTugas _filter = FilterTugas.semua;

  List<Tugas> get _daftarTersaring {
    switch (_filter) {
      case FilterTugas.belumSelesai:
        return _daftar.where((t) => !t.selesai).toList();
      case FilterTugas.selesai:
        return _daftar.where((t) => t.selesai).toList();
      case FilterTugas.milikSaya:
        return _daftar
            .where((t) => t.pembuat == _service.walletAddress)
            .toList();
      case FilterTugas.semua:
        return _daftar;
    }
  }

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  @override
  void dispose() {
    _service.hentikanPantauEvent();
    super.dispose();
  }

  Future<void> _mulai() async {
    try {
      await _service.init();
      await _muatUlang();
      await _service.mulaiPantauEvent(
        onEventMasuk: (jenisEvent) async {
          if (!mounted) return;
          await _muatUlang(senyap: true);
          if (!mounted || _mengirim) return;
          _snack('Event $jenisEvent terdeteksi — daftar diperbarui otomatis');
        },
      );
    } catch (e, st) {
      setState(() {
        _error = '$e\n\n$st';
        _loading = false;
      });
    }
  }

  Future<void> _muatUlang({bool senyap = false}) async {
    if (!senyap) setState(() => _loading = true);
    try {
      final hasil = await _service.ambilSemua();
      if (!mounted) return;
      setState(() {
        _daftar = hasil;
        _error = null;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = '$e\n\n$st');
    } finally {
      if (mounted && !senyap) setState(() => _loading = false);
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
      if (mounted) setState(() => _mengirim = false);
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

  Future<void> _dialogEdit(Tugas t) async {
    final controller = TextEditingController(text: t.isi);
    final isiBaru = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit tugas'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Judul tugas baru...'),
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
    if (isiBaru != null && isiBaru.isNotEmpty && isiBaru != t.isi) {
      await _jalankanTx(() => _service.edit(t.id, isiBaru), 'Mengedit tugas');
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SelectableText(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    final items = _daftarTersaring;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Semua'),
                selected: _filter == FilterTugas.semua,
                onSelected: (_) => setState(() => _filter = FilterTugas.semua),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Belum Selesai'),
                selected: _filter == FilterTugas.belumSelesai,
                onSelected: (_) =>
                    setState(() => _filter = FilterTugas.belumSelesai),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Selesai'),
                selected: _filter == FilterTugas.selesai,
                onSelected: (_) =>
                    setState(() => _filter = FilterTugas.selesai),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Milik Saya'),
                selected: _filter == FilterTugas.milikSaya,
                onSelected: (_) =>
                    setState(() => _filter = FilterTugas.milikSaya),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Belum ada tugas'))
              : RefreshIndicator(
                  onRefresh: _muatUlang,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final t = items[i];
                      final punyaInfoPembuat = t.pembuat.length >= 10;
                      final adalahPembuat =
                          t.pembuat == _service.walletAddress;

                      return ListTile(
                        leading: Checkbox(
                          value: t.selesai,
                          onChanged: (_mengirim || t.selesai)
                              ? null
                              : (_) => _jalankanTx(
                                    () => _service.toggle(t.id),
                                    'Mengubah status',
                                  ),
                        ),
                        title: Text(
                          t.isi,
                          style: TextStyle(
                            decoration:
                                t.selesai ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: punyaInfoPembuat
                            ? Text(
                                'Pembuat: ${t.pembuat.substring(0, 6)}...${t.pembuat.substring(t.pembuat.length - 4)}',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: adalahPembuat
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit judul',
                                    onPressed: _mengirim
                                        ? null
                                        : () => _dialogEdit(t),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Hapus tugas',
                                    onPressed: _mengirim
                                        ? null
                                        : () => _jalankanTx(
                                              () => _service.hapus(t.id),
                                              'Menghapus tugas',
                                            ),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}