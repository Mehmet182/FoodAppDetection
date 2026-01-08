/// Yemek verileri - Backend ile senkronize
/// Ana yemek listesi, fiyatlar ve kaloriler

/// Mevcut yemek isimleri listesi
const List<String> foodItems = [
  'ana-yemek',
  'cay',
  'cikolata',
  'corba',
  'ekmek',
  'gozleme',
  'haslanmis-yumurta',
  'kek',
  'menemen',
  'meyvesuyu',
  'meze',
  'patates-kizartmasi',
  'patates-sosis',
  'peynir',
  'pogoca',
  'su-sisesi',
  'yan-yemek',
  'zeytin',
];

/// Yemek fiyatları (TL)
const Map<String, double> foodPrices = {
  'ana-yemek': 55.0,
  'cay': 10.0,
  'cikolata': 15.0,
  'corba': 35.0,
  'ekmek': 5.0,
  'gozleme': 45.0,
  'haslanmis-yumurta': 8.0,
  'kek': 25.0,
  'menemen': 40.0,
  'meyvesuyu': 20.0,
  'meze': 30.0,
  'patates-kizartmasi': 25.0,
  'patates-sosis': 35.0,
  'peynir': 20.0,
  'pogoca': 12.0,
  'su-sisesi': 10.0,
  'yan-yemek': 30.0,
  'zeytin': 15.0,
};

/// Yemek kalorileri
const Map<String, int> foodCalories = {
  'ana-yemek': 450,
  'cay': 2,
  'cikolata': 220,
  'corba': 150,
  'ekmek': 80,
  'gozleme': 350,
  'haslanmis-yumurta': 78,
  'kek': 280,
  'menemen': 200,
  'meyvesuyu': 120,
  'meze': 180,
  'patates-kizartmasi': 320,
  'patates-sosis': 380,
  'peynir': 110,
  'pogoca': 180,
  'su-sisesi': 0,
  'yan-yemek': 200,
  'zeytin': 50,
};

/// Yemek isimlerini daha okunabilir hale getir
String formatFoodName(String name) {
  return name
      .replaceAll('-', ' ')
      .split(' ')
      .map((word) => word.isNotEmpty 
          ? '${word[0].toUpperCase()}${word.substring(1)}' 
          : '')
      .join(' ');
}
