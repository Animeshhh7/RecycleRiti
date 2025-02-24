class RecyclableItem {
  final String name;
  final String description;
  final double pricePerKg;
  final String imageUrl;
  final bool isRecyclable;

  RecyclableItem({
    required this.name,
    required this.description,
    required this.pricePerKg,
    required this.imageUrl,
    required this.isRecyclable,
  });
}

class RecyclableCategory {
  final String category;
  final List<RecyclableItem> items;

  RecyclableCategory({
    required this.category,
    required this.items,
  });
}

// Recyclable Categories (What We Take)
final List<RecyclableCategory> recyclableCategories = [
  RecyclableCategory(
    category: "Plastic",
    items: [
      RecyclableItem(
        name: "PET Bottles",
        description: "Clear plastic bottles, e.g., water bottles.",
        pricePerKg: 30.0,
        imageUrl: "https://images.pexels.com/photos/257526/pexels-photo-257526.jpeg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "HDPE Containers",
        description: "Milk jugs, detergent bottles.",
        pricePerKg: 25.0,
        imageUrl: "https://images.pexels.com/photos/919073/pexels-photo-919073.jpeg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "Plastic Bags",
        description: "Clean, dry plastic bags (e.g., grocery bags).",
        pricePerKg: 20.0,
        imageUrl: "https://images.pexels.com/photos/123456/plastic-bags.jpg",
        isRecyclable: true,
      ),
    ],
  ),
  RecyclableCategory(
    category: "Paper",
    items: [
      RecyclableItem(
        name: "Newspapers",
        description: "Clean, dry newspapers.",
        pricePerKg: 15.0,
        imageUrl: "https://images.pexels.com/photos/486/pile-of-newspapers.jpg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "Cardboard",
        description: "Flattened cardboard boxes.",
        pricePerKg: 20.0,
        imageUrl: "https://images.pexels.com/photos/4397930/pexels-photo-4397930.jpeg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "Office Paper",
        description: "White office paper, no staples.",
        pricePerKg: 18.0,
        imageUrl: "https://images.pexels.com/photos/1591056/pexels-photo-1591056.jpeg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "Magazines",
        description: "Glossy magazines, clean and dry.",
        pricePerKg: 12.0,
        imageUrl: "https://images.pexels.com/photos/261579/pexels-photo-261579.jpeg",
        isRecyclable: true,
      ),
    ],
  ),
  RecyclableCategory(
    category: "Metal",
    items: [
      RecyclableItem(
        name: "Aluminum Cans",
        description: "Clean aluminum beverage cans.",
        pricePerKg: 50.0,
        imageUrl: "https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "Steel Cans",
        description: "Tin cans, e.g., soup cans.",
        pricePerKg: 40.0,
        imageUrl: "https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "Copper Wire",
        description: "Clean copper wire, no insulation.",
        pricePerKg: 200.0,
        imageUrl: "https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg",
        isRecyclable: true,
      ),
    ],
  ),
  RecyclableCategory(
    category: "Glass",
    items: [
      RecyclableItem(
        name: "Glass Bottles",
        description: "Clear or colored glass bottles, no lids.",
        pricePerKg: 10.0,
        imageUrl: "https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg",
        isRecyclable: true,
      ),
      RecyclableItem(
        name: "Glass Jars",
        description: "Clean glass jars, e.g., jam jars.",
        pricePerKg: 8.0,
        imageUrl: "https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg",
        isRecyclable: true,
      ),
    ],
  ),
];

// Non-Recyclable Items (What We Don’t Take)
final List<RecyclableCategory> nonRecyclableCategories = [
  RecyclableCategory(
    category: "Contaminated Items",
    items: [
      RecyclableItem(
        name: "Greasy Pizza Boxes",
        description: "Cannot recycle due to food contamination.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/1438672/pexels-photo-1438672.jpeg",
        isRecyclable: false,
      ),
      RecyclableItem(
        name: "Dirty Plastic Bags",
        description: "Plastic bags with food residue are not accepted.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/123456/dirty-plastic-bags.jpg",
        isRecyclable: false,
      ),
      RecyclableItem(
        name: "Soiled Paper",
        description: "Paper contaminated with food or grease.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/123456/soiled-paper.jpg",
        isRecyclable: false,
      ),
    ],
  ),
  RecyclableCategory(
    category: "Hazardous Waste",
    items: [
      RecyclableItem(
        name: "Batteries",
        description: "Hazardous materials, dispose of at designated centers.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg",
        isRecyclable: false,
      ),
      RecyclableItem(
        name: "Paint Cans",
        description: "Chemical waste, not recyclable through this app.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg",
        isRecyclable: false,
      ),
      RecyclableItem(
        name: "Electronics",
        description: "E-waste, requires special recycling facilities.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/190312/pexels-photo-190312.jpeg",
        isRecyclable: false,
      ),
      RecyclableItem(
        name: "Medical Waste",
        description: "Syringes, bandages, etc., pose health risks.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/123456/medical-waste.jpg",
        isRecyclable: false,
      ),
    ],
  ),
  RecyclableCategory(
    category: "Non-Recyclable Plastics",
    items: [
      RecyclableItem(
        name: "Plastic Straws",
        description: "Too small and often contaminated.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/123456/plastic-straws.jpg",
        isRecyclable: false,
      ),
      RecyclableItem(
        name: "Styrofoam",
        description: "Not recyclable due to material properties.",
        pricePerKg: 0.0,
        imageUrl: "https://images.pexels.com/photos/123456/styrofoam.jpg",
        isRecyclable: false,
      ),
    ],
  ),
];// 25155
// 11335
