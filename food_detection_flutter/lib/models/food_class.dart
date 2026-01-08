/// Yemek sınıfı bilgilerini tutan model
class FoodClass {
  final int id;
  final String name;
  final double price;

  const FoodClass({
    required this.id,
    required this.name,
    required this.price,
  });

  /// Tüm yemek sınıfları
  static const List<FoodClass> allClasses = [
    FoodClass(id: 0, name: 'Ana Yemek', price: 85.00),
    FoodClass(id: 1, name: 'Çay', price: 15.00),
    FoodClass(id: 2, name: 'Çikolata', price: 25.00),
    FoodClass(id: 3, name: 'Çorba', price: 45.00),
    FoodClass(id: 4, name: 'Ekmek', price: 5.00),
    FoodClass(id: 5, name: 'Gözleme', price: 55.00),
    FoodClass(id: 6, name: 'Haşlanmış Yumurta', price: 12.00),
    FoodClass(id: 7, name: 'Kek', price: 30.00),
    FoodClass(id: 8, name: 'Menemen', price: 50.00),
    FoodClass(id: 9, name: 'Meyve Suyu', price: 20.00),
    FoodClass(id: 10, name: 'Meze', price: 35.00),
    FoodClass(id: 11, name: 'Patates Kızartması', price: 40.00),
    FoodClass(id: 12, name: 'Patates Sosis', price: 55.00),
    FoodClass(id: 13, name: 'Peynir', price: 25.00),
    FoodClass(id: 14, name: 'Poğaça', price: 18.00),
    FoodClass(id: 15, name: 'Su Şişesi', price: 10.00),
    FoodClass(id: 16, name: 'Yan Yemek', price: 45.00),
    FoodClass(id: 17, name: 'Zeytin', price: 15.00),
  ];

  static FoodClass? getById(int id) {
    if (id >= 0 && id < allClasses.length) {
      return allClasses[id];
    }
    return null;
  }
}
