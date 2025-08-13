class MenuItem {
  final int? idMenu;
  final String namaMenu;
  final double harga;
  final int stok;
  final String kategori;
  final String ukuranMenu;
  final String pathGambar; // path file lokal

  MenuItem({
    this.idMenu,
    required this.namaMenu,
    required this.harga,
    required this.stok,
    required this.kategori,
    required this.ukuranMenu,
    required this.pathGambar,
  });

  factory MenuItem.fromMap(Map<String, dynamic> m) => MenuItem(
        idMenu: m['id_menu'] as int?,
        namaMenu: m['nama_menu'] as String,
        harga: (m['harga'] as num).toDouble(),
        stok: (m['stok'] as num).toInt(),
        kategori: m['kategori'] as String,
        ukuranMenu: m['ukuran_menu'] as String,
        pathGambar: m['path_gambar'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id_menu': idMenu,
        'nama_menu': namaMenu,
        'harga': harga,
        'stok': stok,
        'kategori': kategori,
        'ukuran_menu': ukuranMenu,
        'path_gambar': pathGambar,
      };
}
