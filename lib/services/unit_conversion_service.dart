enum UnitCategory {
  weight,
  volume,
  count,
}

class CountUnitConfig {
  final double pieceMultiplier;
  final double packetMultiplier;
  final double dozenMultiplier;
  final double boxMultiplier;
  final double cartonMultiplier;

  const CountUnitConfig({
    this.pieceMultiplier = 1.0,
    this.packetMultiplier = 1.0,
    this.dozenMultiplier = 12.0,
    this.boxMultiplier = 1.0,
    this.cartonMultiplier = 1.0,
  });
}

class UnitConversionService {
  static const CountUnitConfig defaultConfig = CountUnitConfig();

  /// Gets the base unit identifier string for a given category.
  static String getBaseUnit(UnitCategory category) {
    switch (category) {
      case UnitCategory.weight:
        return 'g';
      case UnitCategory.volume:
        return 'ml';
      case UnitCategory.count:
        return 'pcs';
    }
  }

  /// Gets the user-friendly base unit label in Bengali/English.
  static String getBaseUnitLabel(UnitCategory category) {
    switch (category) {
      case UnitCategory.weight:
        return 'Gram (g)';
      case UnitCategory.volume:
        return 'Milliliter (ml)';
      case UnitCategory.count:
        return 'Piece (pcs)';
    }
  }

  /// Available selectable units for a given category.
  static List<String> getAvailableUnits(UnitCategory category) {
    switch (category) {
      case UnitCategory.weight:
        return ['g', 'kg'];
      case UnitCategory.volume:
        return ['ml', 'L'];
      case UnitCategory.count:
        return ['Piece', 'Packet', 'Dozen', 'Box', 'Carton'];
    }
  }

  /// Quick quantity options for POS UI based on category.
  static List<Map<String, dynamic>> getQuickQuantityOptions(UnitCategory category) {
    switch (category) {
      case UnitCategory.weight:
        return [
          {'label': '100 g', 'value': 100.0, 'unit': 'g'},
          {'label': '250 g', 'value': 250.0, 'unit': 'g'},
          {'label': '500 g', 'value': 500.0, 'unit': 'g'},
          {'label': '750 g', 'value': 750.0, 'unit': 'g'},
          {'label': '1 kg', 'value': 1.0, 'unit': 'kg'},
          {'label': '2 kg', 'value': 2.0, 'unit': 'kg'},
        ];
      case UnitCategory.volume:
        return [
          {'label': '100 ml', 'value': 100.0, 'unit': 'ml'},
          {'label': '250 ml', 'value': 250.0, 'unit': 'ml'},
          {'label': '500 ml', 'value': 500.0, 'unit': 'ml'},
          {'label': '750 ml', 'value': 750.0, 'unit': 'ml'},
          {'label': '1 L', 'value': 1.0, 'unit': 'L'},
          {'label': '2 L', 'value': 2.0, 'unit': 'L'},
        ];
      case UnitCategory.count:
        return [
          {'label': '1', 'value': 1.0, 'unit': 'Piece'},
          {'label': '2', 'value': 2.0, 'unit': 'Piece'},
          {'label': '3', 'value': 3.0, 'unit': 'Piece'},
          {'label': '6', 'value': 6.0, 'unit': 'Piece'},
          {'label': '12', 'value': 12.0, 'unit': 'Piece'},
          {'label': '24', 'value': 24.0, 'unit': 'Piece'},
        ];
    }
  }

  /// Converts a quantity in a specific unit to the internal base unit (g, ml, pcs).
  static double toBaseQuantity(
    double quantity,
    String unit,
    UnitCategory category, {
    CountUnitConfig config = defaultConfig,
  }) {
    if (quantity <= 0) return 0.0;

    switch (category) {
      case UnitCategory.weight:
        final normalizedUnit = unit.toLowerCase().trim();
        if (normalizedUnit == 'kg') {
          return quantity * 1000.0;
        }
        return quantity; // g

      case UnitCategory.volume:
        final normalizedUnit = unit.trim();
        if (normalizedUnit == 'L' || normalizedUnit.toLowerCase() == 'l' || normalizedUnit.toLowerCase() == 'liter') {
          return quantity * 1000.0;
        }
        return quantity; // ml

      case UnitCategory.count:
        final normalizedUnit = unit.toLowerCase().trim();
        if (normalizedUnit.contains('dozen')) {
          return quantity * config.dozenMultiplier;
        } else if (normalizedUnit.contains('packet')) {
          return quantity * config.packetMultiplier;
        } else if (normalizedUnit.contains('box')) {
          return quantity * config.boxMultiplier;
        } else if (normalizedUnit.contains('carton')) {
          return quantity * config.cartonMultiplier;
        }
        return quantity * config.pieceMultiplier; // pcs / piece
    }
  }

  /// Converts a base quantity to a target unit display quantity.
  static double fromBaseQuantity(
    double baseQuantity,
    String targetUnit,
    UnitCategory category, {
    CountUnitConfig config = defaultConfig,
  }) {
    if (baseQuantity <= 0) return 0.0;

    switch (category) {
      case UnitCategory.weight:
        if (targetUnit.toLowerCase().trim() == 'kg') {
          return baseQuantity / 1000.0;
        }
        return baseQuantity;

      case UnitCategory.volume:
        final normalized = targetUnit.trim().toLowerCase();
        if (normalized == 'l' || normalized == 'liter') {
          return baseQuantity / 1000.0;
        }
        return baseQuantity;

      case UnitCategory.count:
        final normalized = targetUnit.toLowerCase().trim();
        if (normalized.contains('dozen')) {
          return baseQuantity / config.dozenMultiplier;
        } else if (normalized.contains('packet')) {
          return baseQuantity / config.packetMultiplier;
        } else if (normalized.contains('box')) {
          return baseQuantity / config.boxMultiplier;
        } else if (normalized.contains('carton')) {
          return baseQuantity / config.cartonMultiplier;
        }
        return baseQuantity / config.pieceMultiplier;
    }
  }

  /// Calculates total price for a given base quantity and price per base unit.
  static double calculateTotalPrice(double baseQuantity, double baseUnitPrice) {
    return baseQuantity * baseUnitPrice;
  }

  /// Formats opening stock helper text for Add/Edit product screen.
  /// Example: "5000 g = 5 kg", "10000 ml = 10 L", "25 pcs"
  static String formatOpeningStockHelper(double stockInBaseUnit, UnitCategory category) {
    final cleanBase = _stripTrailingZero(stockInBaseUnit);
    switch (category) {
      case UnitCategory.weight:
        if (stockInBaseUnit >= 1000) {
          final kg = _stripTrailingZero(stockInBaseUnit / 1000.0);
          return '$cleanBase g = $kg kg';
        }
        return '$cleanBase g';

      case UnitCategory.volume:
        if (stockInBaseUnit >= 1000) {
          final l = _stripTrailingZero(stockInBaseUnit / 1000.0);
          return '$cleanBase ml = $l L';
        }
        return '$cleanBase ml';

      case UnitCategory.count:
        return '$cleanBase pcs';
    }
  }

  /// Formats stock quantity in human-readable units for inventory displays.
  /// Example: 5000 g -> "5 kg", 450 g -> "450 g", 10000 ml -> "10 L", 25 pcs -> "25 pcs"
  static String formatStockDisplay(double stockInBaseUnit, UnitCategory category) {
    switch (category) {
      case UnitCategory.weight:
        if (stockInBaseUnit >= 1000) {
          final kg = _stripTrailingZero(stockInBaseUnit / 1000.0);
          return '$kg kg';
        }
        return '${_stripTrailingZero(stockInBaseUnit)} g';

      case UnitCategory.volume:
        if (stockInBaseUnit >= 1000) {
          final l = _stripTrailingZero(stockInBaseUnit / 1000.0);
          return '$l L';
        }
        return '${_stripTrailingZero(stockInBaseUnit)} ml';

      case UnitCategory.count:
        return '${_stripTrailingZero(stockInBaseUnit)} pcs';
    }
  }

  /// Formats a quantity with unit nicely (e.g. 1.5 L, 300 g, 3 pcs).
  static String formatQuantityWithUnit(double qty, String unit) {
    return '${_stripTrailingZero(qty)} $unit';
  }

  /// Helper to remove unnecessary trailing decimals (e.g. 1.50 -> 1.5, 5.0 -> 5).
  static String _stripTrailingZero(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Category name helper in Bengali.
  static String getCategoryLabelBengali(UnitCategory category) {
    switch (category) {
      case UnitCategory.weight:
        return 'ওজন (Weight)';
      case UnitCategory.volume:
        return 'আয়তন/তরল (Volume)';
      case UnitCategory.count:
        return 'সংখ্যা/টি (Count)';
    }
  }

  /// Parse category from String with fallback to Count.
  static UnitCategory parseCategory(String? categoryStr) {
    if (categoryStr == null) return UnitCategory.count;
    final lower = categoryStr.toLowerCase().trim();
    if (lower.contains('weight') || lower.contains('ওজন')) {
      return UnitCategory.weight;
    } else if (lower.contains('volume') || lower.contains('তরল') || lower.contains('আয়তন')) {
      return UnitCategory.volume;
    }
    return UnitCategory.count;
  }
}
