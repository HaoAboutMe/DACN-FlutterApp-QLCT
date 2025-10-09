import 'package:flutter/material.dart';

enum IconGroup {
  all,
  food,
  entertainment,
  transport,
  shopping,
  bills,
  education,
  health,
  saving,
  others
}

class IconGroupHelper {
  static const Map<IconGroup, String> groupNames = {
    IconGroup.all: 'Tất cả',
    IconGroup.food: 'Ăn uống',
    IconGroup.entertainment: 'Giải trí',
    IconGroup.transport: 'Đi lại',
    IconGroup.shopping: 'Mua sắm',
    IconGroup.bills: 'Hóa đơn',
    IconGroup.education: 'Giáo dục',
    IconGroup.health: 'Sức khỏe',
    IconGroup.saving: 'Tiết kiệm',
    IconGroup.others: 'Khác',
  };

  static const Map<IconGroup, List<IconData>> groupedIcons = {
    IconGroup.food: [
      Icons.restaurant,
      Icons.fastfood,
      Icons.local_cafe,
      Icons.local_pizza,
      Icons.ramen_dining,
      Icons.icecream,
      Icons.cake,
      Icons.lunch_dining,
      Icons.dinner_dining,
      Icons.breakfast_dining,
      Icons.local_bar,
      Icons.wine_bar,
    ],
    IconGroup.entertainment: [
      Icons.sports_esports,
      Icons.movie,
      Icons.music_note,
      Icons.sports_soccer,
      Icons.videogame_asset,
      Icons.theaters,
      Icons.casino,
      Icons.sports_basketball,
      Icons.sports_tennis,
      Icons.attractions,
      Icons.celebration,
      Icons.party_mode,
    ],
    IconGroup.transport: [
      Icons.directions_car,
      Icons.directions_bike,
      Icons.directions_bus,
      Icons.local_taxi,
      Icons.local_gas_station,
      Icons.flight_takeoff,
      Icons.train,
      Icons.subway,
      Icons.motorcycle,
      Icons.directions_boat,
      Icons.electric_car,
      Icons.local_shipping,
    ],
    IconGroup.shopping: [
      Icons.shopping_bag,
      Icons.shopping_cart,
      Icons.local_mall,
      Icons.card_giftcard,
      Icons.store,
      Icons.sell,
      Icons.local_grocery_store,
      Icons.checkroom,
      Icons.diamond,
      Icons.watch,
      Icons.devices,
      Icons.phone_android,
    ],
    IconGroup.bills: [
      Icons.receipt_long,
      Icons.water_drop,
      Icons.lightbulb,
      Icons.wifi,
      Icons.cable,
      Icons.home_repair_service,
      Icons.electrical_services,
      Icons.plumbing,
      Icons.phone,
      Icons.smartphone,
      Icons.tv,
      Icons.router,
    ],
    IconGroup.education: [
      Icons.menu_book,
      Icons.school,
      Icons.computer,
      Icons.brush,
      Icons.science,
      Icons.language,
      Icons.psychology,
      Icons.auto_stories,
      Icons.calculate,
      Icons.architecture,
      Icons.biotech,
      Icons.code,
    ],
    IconGroup.health: [
      Icons.health_and_safety,
      Icons.local_hospital,
      Icons.vaccines,
      Icons.fitness_center,
      Icons.spa,
      Icons.medical_services,
      Icons.healing,
      Icons.medication,
      Icons.psychology,
      Icons.self_improvement,
      Icons.sports_gymnastics,
      Icons.favorite,
    ],
    IconGroup.saving: [
      Icons.savings,
      Icons.account_balance,
      Icons.trending_up,
      Icons.account_balance_wallet,
      Icons.analytics,
      Icons.insights,
      Icons.attach_money,
      Icons.currency_exchange,
      Icons.monetization_on,
      Icons.paid,
      Icons.price_change,
      Icons.show_chart,
    ],
    IconGroup.others: [
      Icons.more_horiz,
      Icons.extension,
      Icons.category,
      Icons.settings,
      Icons.star,
      Icons.note,
      Icons.work,
      Icons.home,
      Icons.pets,
      Icons.child_care,
      Icons.elderly,
      Icons.volunteer_activism,
    ],
  };

  static List<IconData> getAllIcons() {
    List<IconData> allIcons = [];
    for (IconGroup group in IconGroup.values) {
      if (group != IconGroup.all) {
        allIcons.addAll(groupedIcons[group] ?? []);
      }
    }
    return allIcons;
  }

  static List<IconData> getIconsByGroup(IconGroup group) {
    if (group == IconGroup.all) {
      return getAllIcons();
    }
    return groupedIcons[group] ?? [];
  }

  static String getGroupName(IconGroup group) {
    return groupNames[group] ?? 'Không xác định';
  }

  static IconGroup? findGroupByIcon(IconData iconData) {
    for (IconGroup group in IconGroup.values) {
      if (group != IconGroup.all) {
        final icons = groupedIcons[group] ?? [];
        if (icons.any((icon) => icon.codePoint == iconData.codePoint)) {
          return group;
        }
      }
    }
    return IconGroup.others;
  }
}
