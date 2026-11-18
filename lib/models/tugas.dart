class Tugas {
  final int id;
  final String isi;
  final bool selesai;
  final String pembuat;

  Tugas({
    required this.id,
    required this.isi,
    required this.selesai,
    this.pembuat = '',
  });
}