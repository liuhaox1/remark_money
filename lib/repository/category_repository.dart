import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';

class CategoryRepository {
  static const _key = 'categories_v1';

  static final List<Category> defaultCategories = [
    // 一级：餐饮
    Category(
      key: 'top_food',
      name: AppStrings.catTopFood,
      icon: Icons.restaurant_outlined,
      isExpense: true,
    ),
    // 餐饮 - 二级
    Category(
      key: 'food_meal',
      name: AppStrings.catFoodMeal,
      icon: Icons.restaurant_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_breakfast',
      name: AppStrings.catFoodBreakfast,
      icon: Icons.free_breakfast_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_snack',
      name: AppStrings.catFoodSnack,
      icon: Icons.cookie_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_drink',
      name: AppStrings.catFoodDrink,
      icon: Icons.local_cafe_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_takeout',
      name: AppStrings.catFoodTakeout,
      icon: Icons.delivery_dining_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_supper',
      name: AppStrings.catFoodSupper,
      icon: Icons.nightlife_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),

    // 一级：购物
    Category(
      key: 'top_shopping',
      name: AppStrings.catTopShopping,
      icon: Icons.local_mall_outlined,
      isExpense: true,
    ),
    Category(
      key: 'shop_daily',
      name: AppStrings.catShopDaily,
      icon: Icons.inventory_2_outlined,
      isExpense: true,
      parentKey: 'top_shopping',
    ),
    Category(
      key: 'shop_supermarket',
      name: AppStrings.catShopSupermarket,
      icon: Icons.local_grocery_store_outlined,
      isExpense: true,
      parentKey: 'top_shopping',
    ),
    Category(
      key: 'shop_clothes',
      name: AppStrings.catShopClothes,
      icon: Icons.checkroom_outlined,
      isExpense: true,
      parentKey: 'top_shopping',
    ),
    Category(
      key: 'shop_digital',
      name: AppStrings.catShopDigital,
      icon: Icons.devices_other_outlined,
      isExpense: true,
      parentKey: 'top_shopping',
    ),
    Category(
      key: 'shop_beauty',
      name: AppStrings.catShopBeauty,
      icon: Icons.brush_outlined,
      isExpense: true,
      parentKey: 'top_shopping',
    ),
    Category(
      key: 'shop_other',
      name: AppStrings.catShopOther,
      icon: Icons.shopping_bag_outlined,
      isExpense: true,
      parentKey: 'top_shopping',
    ),

    // 一级：出行
    Category(
      key: 'top_transport',
      name: AppStrings.catTopTransport,
      icon: Icons.directions_bus_outlined,
      isExpense: true,
    ),
    Category(
      key: 'trans_commute',
      name: AppStrings.catTransCommute,
      icon: Icons.directions_subway_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_taxi',
      name: AppStrings.catTransTaxi,
      icon: Icons.local_taxi_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_drive',
      name: AppStrings.catTransDrive,
      icon: Icons.local_gas_station_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_longtrip',
      name: AppStrings.catTransLongTrip,
      icon: Icons.flight_takeoff_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_share',
      name: AppStrings.catTransShare,
      icon: Icons.directions_bike_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),

    // 一级：居住与账单
    Category(
      key: 'top_living',
      name: AppStrings.catTopLiving,
      icon: Icons.house_outlined,
      isExpense: true,
    ),
    Category(
      key: 'living_rent',
      name: AppStrings.catLivingRent,
      icon: Icons.apartment_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),
    Category(
      key: 'living_property',
      name: AppStrings.catLivingProperty,
      icon: Icons.receipt_long_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),
    Category(
      key: 'living_utility',
      name: AppStrings.catLivingUtility,
      icon: Icons.electric_bolt_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),
    Category(
      key: 'living_internet',
      name: AppStrings.catLivingInternet,
      icon: Icons.wifi_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),
    Category(
      key: 'living_service',
      name: AppStrings.catLivingService,
      icon: Icons.cleaning_services_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),
    Category(
      key: 'living_decorate',
      name: AppStrings.catLivingDecorate,
      icon: Icons.chair_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),

    // 一级：娱乐休闲
    Category(
      key: 'top_leisure',
      name: AppStrings.catTopLeisure,
      icon: Icons.sports_esports_outlined,
      isExpense: true,
    ),
    Category(
      key: 'fun_online',
      name: AppStrings.catFunOnline,
      icon: Icons.live_tv_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),
    Category(
      key: 'fun_offline',
      name: AppStrings.catFunOffline,
      icon: Icons.movie_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),
    Category(
      key: 'fun_sport',
      name: AppStrings.catFunSport,
      icon: Icons.fitness_center_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),
    Category(
      key: 'fun_travel',
      name: AppStrings.catFunTravel,
      icon: Icons.beach_access_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),
    Category(
      key: 'fun_hobby',
      name: AppStrings.catFunHobby,
      icon: Icons.color_lens_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),

    // 一级：教育成长
    Category(
      key: 'top_education',
      name: AppStrings.catTopEducation,
      icon: Icons.school_outlined,
      isExpense: true,
    ),
    Category(
      key: 'edu_course',
      name: AppStrings.catEduCourse,
      icon: Icons.menu_book_outlined,
      isExpense: true,
      parentKey: 'top_education',
    ),
    Category(
      key: 'edu_book',
      name: AppStrings.catEduBook,
      icon: Icons.auto_stories_outlined,
      isExpense: true,
      parentKey: 'top_education',
    ),
    Category(
      key: 'edu_exam',
      name: AppStrings.catEduExam,
      icon: Icons.fact_check_outlined,
      isExpense: true,
      parentKey: 'top_education',
    ),
    Category(
      key: 'edu_language',
      name: AppStrings.catEduLanguage,
      icon: Icons.translate_outlined,
      isExpense: true,
      parentKey: 'top_education',
    ),
    Category(
      key: 'edu_online',
      name: AppStrings.catEduOnline,
      icon: Icons.cast_for_education_outlined,
      isExpense: true,
      parentKey: 'top_education',
    ),

    // 一级：健康医疗
    Category(
      key: 'top_health',
      name: AppStrings.catTopHealth,
      icon: Icons.medical_services_outlined,
      isExpense: true,
    ),
    Category(
      key: 'health_clinic',
      name: AppStrings.catHealthClinic,
      icon: Icons.local_hospital_outlined,
      isExpense: true,
      parentKey: 'top_health',
    ),
    Category(
      key: 'health_medicine',
      name: AppStrings.catHealthMedicine,
      icon: Icons.vaccines_outlined,
      isExpense: true,
      parentKey: 'top_health',
    ),
    Category(
      key: 'health_check',
      name: AppStrings.catHealthCheck,
      icon: Icons.health_and_safety_outlined,
      isExpense: true,
      parentKey: 'top_health',
    ),
    Category(
      key: 'health_dental',
      name: AppStrings.catHealthDental,
      icon: Icons.medication_outlined,
      isExpense: true,
      parentKey: 'top_health',
    ),
    Category(
      key: 'health_insurance',
      name: AppStrings.catHealthInsurance,
      icon: Icons.assignment_ind_outlined,
      isExpense: true,
      parentKey: 'top_health',
    ),

    // 一级：家庭与人情
    Category(
      key: 'top_family',
      name: AppStrings.catTopFamily,
      icon: Icons.family_restroom_outlined,
      isExpense: true,
    ),
    Category(
      key: 'family_child',
      name: AppStrings.catFamilyChild,
      icon: Icons.child_care_outlined,
      isExpense: true,
      parentKey: 'top_family',
    ),
    Category(
      key: 'family_elder',
      name: AppStrings.catFamilyElder,
      icon: Icons.elderly_outlined,
      isExpense: true,
      parentKey: 'top_family',
    ),
    Category(
      key: 'family_meal',
      name: AppStrings.catFamilyMeal,
      icon: Icons.dining_outlined,
      isExpense: true,
      parentKey: 'top_family',
    ),
    Category(
      key: 'family_gift',
      name: AppStrings.catFamilyGift,
      icon: Icons.redeem_outlined,
      isExpense: true,
      parentKey: 'top_family',
    ),
    Category(
      key: 'family_social',
      name: AppStrings.catFamilySocial,
      icon: Icons.diversity_3_outlined,
      isExpense: true,
      parentKey: 'top_family',
    ),
    Category(
      key: 'family_pet',
      name: AppStrings.catFamilyPet,
      icon: Icons.pets_outlined,
      isExpense: true,
      parentKey: 'top_family',
    ),

    // 一级：金融与其他
    Category(
      key: 'top_finance',
      name: '金融',
      icon: Icons.account_balance_wallet_outlined,
      isExpense: true,
    ),
    Category(
      key: 'fin_repay',
      name: '还贷/卡费',
      icon: Icons.credit_card_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_fee',
      name: '利息手续费',
      icon: Icons.receipt_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_invest_loss',
      name: '投资亏损',
      icon: Icons.show_chart_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_adjust',
      name: '调账',
      icon: Icons.tune_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),

    // 收入一级
    Category(
      key: 'top_income_salary',
      name: AppStrings.catTopIncomeSalary,
      icon: Icons.attach_money,
      isExpense: false,
    ),
    Category(
      key: 'top_income_parttime',
      name: AppStrings.catTopIncomeParttime,
      icon: Icons.work_outline,
      isExpense: false,
    ),
    Category(
      key: 'top_income_invest',
      name: AppStrings.catTopIncomeInvest,
      icon: Icons.trending_up,
      isExpense: false,
    ),
    Category(
      key: 'top_income_other',
      name: AppStrings.catTopIncomeOther,
      icon: Icons.card_giftcard,
      isExpense: false,
    ),

    // 收入 - 二级
    Category(
      key: 'income_basic_salary',
      name: AppStrings.catIncomeBasicSalary,
      icon: Icons.attach_money,
      isExpense: false,
      parentKey: 'top_income_salary',
    ),
    Category(
      key: 'income_bonus',
      name: AppStrings.catIncomeBonus,
      icon: Icons.card_giftcard,
      isExpense: false,
      parentKey: 'top_income_salary',
    ),
    Category(
      key: 'income_year_end',
      name: AppStrings.catIncomeYearEnd,
      icon: Icons.workspace_premium_outlined,
      isExpense: false,
      parentKey: 'top_income_salary',
    ),
    Category(
      key: 'income_parttime_online',
      name: AppStrings.catIncomeParttimeOnline,
      icon: Icons.computer_outlined,
      isExpense: false,
      parentKey: 'top_income_parttime',
    ),
    Category(
      key: 'income_parttime_offline',
      name: AppStrings.catIncomeParttimeOffline,
      icon: Icons.storefront_outlined,
      isExpense: false,
      parentKey: 'top_income_parttime',
    ),
    Category(
      key: 'income_invest_interest',
      name: AppStrings.catIncomeInvestInterest,
      icon: Icons.savings_outlined,
      isExpense: false,
      parentKey: 'top_income_invest',
    ),
    Category(
      key: 'income_invest_stock',
      name: AppStrings.catIncomeInvestStock,
      icon: Icons.show_chart_outlined,
      isExpense: false,
      parentKey: 'top_income_invest',
    ),
    Category(
      key: 'income_red_packet',
      name: AppStrings.catIncomeRedPacket,
      icon: Icons.wallet_giftcard_outlined,
      isExpense: false,
      parentKey: 'top_income_other',
    ),
    Category(
      key: 'income_refund',
      name: AppStrings.catIncomeRefund,
      icon: Icons.undo_outlined,
      isExpense: false,
      parentKey: 'top_income_other',
    ),
  ];

  Future<List<Category>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    // 如果本地还没有数据，或者被清空为一个空列表，就回写一份默认分类
    if (raw == null || raw.isEmpty) {
      await saveCategories(defaultCategories);
      return List<Category>.from(defaultCategories);
    }

    return raw.map((value) => Category.fromJson(value)).toList();
  }

  Future<void> saveCategories(List<Category> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = categories.map((c) => c.toJson()).toList();
    await prefs.setStringList(_key, payload);
  }

  Future<List<Category>> add(Category category) async {
    final list = await loadCategories();
    list.add(category);
    await saveCategories(list);
    return list;
  }

  Future<List<Category>> delete(String key) async {
    final list = await loadCategories();
    list.removeWhere((element) => element.key == key);
    await saveCategories(list);
    return list;
  }

  Future<List<Category>> update(Category category) async {
    final list = await loadCategories();
    final index = list.indexWhere((c) => c.key == category.key);
    if (index != -1) {
      list[index] = category;
      await saveCategories(list);
    }
    return list;
  }
}
