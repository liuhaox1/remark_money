import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';

class CategoryRepository {
  static const _key = 'categories_v1';

  /// 兜底分类：当无法识别出合理的支出分类时，使用“未分类”避免误落到高频分类（如“餐饮”）。
  static const String uncategorizedExpenseKey = 'top_uncategorized';

  /// 这些分类本质上是“资金动作/财务操作”，不适合放在普通“记一笔”的消费分类里。
  /// 为兼容历史数据仍保留在分类表中，但默认不在“记一笔”分类选择器中展示。
  static const Set<String> hiddenInRecordPickerKeys = {
    'fin_loan', // 借贷还款
    'fin_credit', // 信用卡还款
    'fin_adjust', // 账户调整
    uncategorizedExpenseKey, // 兜底“其他”（内部使用，不给用户手动选）
  };

  static final List<Category> defaultCategories = [
    // 一级：餐饮
    Category(
      key: 'top_food',
      name: AppStrings.catTopFood,
      icon: Icons.restaurant_outlined,
      isExpense: true,
    ),
    // 餐饮 - 二级（统一按场景维度）
    Category(
      key: 'food_breakfast',
      name: AppStrings.catFoodBreakfast,
      icon: Icons.free_breakfast_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_lunch',
      name: AppStrings.catFoodLunch,
      icon: Icons.lunch_dining_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_dinner',
      name: AppStrings.catFoodDinner,
      icon: Icons.dinner_dining_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_afternoon_tea',
      name: AppStrings.catFoodAfternoonTea,
      icon: Icons.local_cafe_outlined,
      isExpense: true,
      parentKey: 'top_food',
    ),
    Category(
      key: 'food_drink',
      name: AppStrings.catFoodDrink,
      icon: Icons.local_drink_outlined,
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
    Category(
      key: 'food_takeout',
      name: AppStrings.catFoodTakeout,
      icon: Icons.delivery_dining_outlined,
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
    // 购物 - 二级（统一按商品类型分类）
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
    // 出行 - 二级（统一按交通方式，拆分自驾养车）
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
      key: 'trans_share',
      name: AppStrings.catTransShare,
      icon: Icons.directions_bike_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_fuel',
      name: AppStrings.catTransFuel,
      icon: Icons.local_gas_station_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_charging',
      name: AppStrings.catTransCharging,
      icon: Icons.ev_station_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_parking',
      name: AppStrings.catTransParking,
      icon: Icons.local_parking_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_toll',
      name: AppStrings.catTransToll,
      icon: Icons.toll_outlined,
      isExpense: true,
      parentKey: 'top_transport',
    ),
    Category(
      key: 'trans_maintenance',
      name: AppStrings.catTransMaintenance,
      icon: Icons.build_outlined,
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

    // 一级：居住与账单
    Category(
      key: 'top_living',
      name: AppStrings.catTopLiving,
      icon: Icons.house_outlined,
      isExpense: true,
    ),
    // 居住与账单 - 二级（统一命名，优化粒度）
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
      key: 'living_tv',
      name: AppStrings.catLivingTv,
      icon: Icons.tv_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),
    Category(
      key: 'living_cleaning',
      name: AppStrings.catLivingCleaning,
      icon: Icons.cleaning_services_outlined,
      isExpense: true,
      parentKey: 'top_living',
    ),
    Category(
      key: 'living_repair',
      name: AppStrings.catLivingRepair,
      icon: Icons.build_outlined,
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
    Category(
      key: 'living_furniture',
      name: AppStrings.catLivingFurniture,
      icon: Icons.weekend_outlined,
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
    // 娱乐休闲 - 二级（统一维度，补充具体活动）
    Category(
      key: 'fun_game',
      name: AppStrings.catFunGame,
      icon: Icons.sports_esports_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),
    Category(
      key: 'fun_media',
      name: AppStrings.catFunMedia,
      icon: Icons.live_tv_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),
    Category(
      key: 'fun_movie',
      name: AppStrings.catFunMovie,
      icon: Icons.movie_outlined,
      isExpense: true,
      parentKey: 'top_leisure',
    ),
    Category(
      key: 'fun_show',
      name: AppStrings.catFunShow,
      icon: Icons.theater_comedy_outlined,
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
      key: 'fun_party',
      name: AppStrings.catFunParty,
      icon: Icons.celebration_outlined,
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
    // 教育成长 - 二级（优化粒度，补充细分）
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
      key: 'edu_certificate',
      name: AppStrings.catEduCertificate,
      icon: Icons.workspace_premium_outlined,
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
    Category(
      key: 'edu_tuition',
      name: AppStrings.catEduTuition,
      icon: Icons.school_outlined,
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
    // 健康医疗 - 二级（统一维度，合并重叠分类）
    Category(
      key: 'health_clinic',
      name: AppStrings.catHealthClinic,
      icon: Icons.local_hospital_outlined,
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
      key: 'health_medicine',
      name: AppStrings.catHealthMedicine,
      icon: Icons.vaccines_outlined,
      isExpense: true,
      parentKey: 'top_health',
    ),
    Category(
      key: 'health_surgery',
      name: AppStrings.catHealthSurgery,
      icon: Icons.medical_services_outlined,
      isExpense: true,
      parentKey: 'top_health',
    ),
    Category(
      key: 'health_treatment',
      name: AppStrings.catHealthTreatment,
      icon: Icons.healing_outlined,
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
      key: 'health_vision',
      name: AppStrings.catHealthVision,
      icon: Icons.remove_red_eye_outlined,
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
    // 家庭与人情 - 二级（统一维度，补充具体事件）
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
      key: 'family_friends',
      name: AppStrings.catFamilyFriends,
      icon: Icons.people_outlined,
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
      name: AppStrings.catTopFinance,
      icon: Icons.account_balance_wallet_outlined,
      isExpense: true,
    ),
    // 金融与其他 - 二级（优化粒度，补充细分）
    Category(
      key: 'fin_loan',
      name: AppStrings.catFinLoan,
      icon: Icons.account_balance_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_credit',
      name: AppStrings.catFinCredit,
      icon: Icons.credit_card_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_interest',
      name: AppStrings.catFinInterest,
      icon: Icons.trending_up_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_fee',
      name: AppStrings.catFinFee,
      icon: Icons.receipt_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_invest_loss',
      name: AppStrings.catFinInvestLoss,
      icon: Icons.show_chart_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),
    Category(
      key: 'fin_adjust',
      name: AppStrings.catFinAdjust,
      icon: Icons.tune_outlined,
      isExpense: true,
      parentKey: 'top_finance',
    ),

    // 支出一级：未分类（兜底用，避免错误归类）
    Category(
      key: uncategorizedExpenseKey,
      name: AppStrings.catUncategorized,
      icon: Icons.category_outlined,
      isExpense: true,
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

    // 收入 - 二级（补充常见投资类型）
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
      key: 'income_invest_fund',
      name: AppStrings.catIncomeInvestFund,
      icon: Icons.trending_up_outlined,
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
      key: 'income_invest_bond',
      name: AppStrings.catIncomeInvestBond,
      icon: Icons.account_balance_outlined,
      isExpense: false,
      parentKey: 'top_income_invest',
    ),
    Category(
      key: 'income_invest_interest',
      name: AppStrings.catIncomeInvestInterest,
      icon: Icons.savings_outlined,
      isExpense: false,
      parentKey: 'top_income_invest',
    ),
    Category(
      key: 'income_rental',
      name: AppStrings.catIncomeRental,
      icon: Icons.home_outlined,
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

    final categories = raw.map((value) => Category.fromJson(value)).toList();
    
    // 迁移旧分类：更新分类名称，删除已废弃的分类
    final migratedCategories = migrateCategories(categories);
    
    // 检查是否有变化：数量变化或名称变化
    bool hasChanges = migratedCategories.length != categories.length;
    if (!hasChanges) {
      // 检查是否有分类名称被更新
      for (final migrated in migratedCategories) {
        final original = categories.firstWhere(
          (c) => c.key == migrated.key,
          orElse: () => migrated,
        );
        if (original.name != migrated.name) {
          hasChanges = true;
          break;
        }
      }
    }
    
    // 如果迁移后有变化，保存更新后的分类
    if (hasChanges || migratedCategories.any((c) => needsMigration(c))) {
      await saveCategories(migratedCategories);
    }
    
    return migratedCategories;
  }

  /// 迁移旧分类到新分类结构
  /// 删除已废弃的分类，更新分类名称
  /// 这是一个公共静态方法，供数据库版本的 repository 使用
  static List<Category> migrateCategories(List<Category> categories) {
    final migrated = <Category>[];
    final oldKeyToNewKey = <String, String>{
      // 已删除的分类key映射到新的分类key
      'food_meal': 'food_lunch', // 正餐 -> 午餐
      'food_snack': 'food_afternoon_tea', // 零食小吃 -> 下午茶
      'shop_online': 'shop_other', // 线上购物 -> 其他购物
      'shop_offline': 'shop_other', // 线下购物 -> 其他购物
      'trans_ride_hailing': 'trans_taxi', // 网约车 -> 打车
      'health_registration': 'health_clinic', // 挂号 -> 门诊
      'health_physical': 'health_check', // 体检 -> 检查
      'fun_social': 'fun_party', // 社交 -> 聚会
      'edu_ebook': 'edu_book', // 电子书 -> 书籍
      'edu_misc': 'edu_tuition', // 学杂费 -> 学费
      'fin_transfer_fee': 'fin_fee', // 转账手续费 -> 手续费
    };
    
    // 旧分类名称到新分类名称的映射
    final oldNameToNewName = <String, String>{
      '正餐（午/晚）': AppStrings.catFoodLunch,
      '正餐/工作餐': AppStrings.catFoodLunch,
      '零食小吃': AppStrings.catFoodAfternoonTea,
      '饮品': AppStrings.catFoodDrink,
      '打车/网约车': AppStrings.catTransTaxi,
      '打车': AppStrings.catTransTaxi,
      '网约车': AppStrings.catTransTaxi,
      '长途出行': AppStrings.catTransLongTrip,
      '油费/充电': AppStrings.catTransFuel,
      '自驾养车': AppStrings.catTransFuel,
      '网络/电视': AppStrings.catLivingInternet,
      '网络与电视': AppStrings.catLivingInternet,
      '家政/维修': AppStrings.catLivingCleaning,
      '家政维修服务': AppStrings.catLivingCleaning,
      '装修/家居': AppStrings.catLivingDecorate,
      '装修及家居': AppStrings.catLivingDecorate,
      '游戏/影音': AppStrings.catFunGame,
      '电影/演出': AppStrings.catFunMovie,
      '聚会/社交': AppStrings.catFunParty,
      '社交': AppStrings.catFunParty,
      '书籍/电子书': AppStrings.catEduBook,
      '电子书': AppStrings.catEduBook,
      '考试/证书': AppStrings.catEduExam,
      '学费/学杂费': AppStrings.catEduTuition,
      '学杂费': AppStrings.catEduTuition,
      '门诊挂号': AppStrings.catHealthClinic,
      '门诊': AppStrings.catHealthClinic,
      '挂号': AppStrings.catHealthClinic,
      '检查体检': AppStrings.catHealthCheck,
      '检查': AppStrings.catHealthCheck,
      '体检': AppStrings.catHealthCheck,
      '手术/治疗': AppStrings.catHealthSurgery,
      '牙科/视力': AppStrings.catHealthDental,
      '利息/手续费': AppStrings.catFinInterest,
      '转账手续费': AppStrings.catFinFee,
      '资金调账': AppStrings.catFinAdjust,
      '还贷/卡费': AppStrings.catFinLoan,
      '借贷与卡费还款': AppStrings.catFinLoan,
    };
    
    for (final category in categories) {
      // 如果这个分类key已经被废弃，尝试映射到新key
      if (oldKeyToNewKey.containsKey(category.key)) {
        final newKey = oldKeyToNewKey[category.key]!;
        // 检查新key的分类是否已存在
        if (!categories.any((c) => c.key == newKey)) {
          // 如果不存在，创建新分类
          final newCategory = Category(
            key: newKey,
            name: _getNewCategoryName(newKey),
            icon: category.icon,
            isExpense: category.isExpense,
            parentKey: category.parentKey,
          );
          migrated.add(newCategory);
        }
        // 跳过旧分类，不添加到migrated列表
        continue;
      }
      
      // 如果分类名称包含"/"或旧的命名，更新名称
      String newName = category.name;
      if (oldNameToNewName.containsKey(category.name)) {
        newName = oldNameToNewName[category.name]!;
      } else {
        // 尝试从默认分类中获取正确名称（如果key匹配但名称不同，说明需要更新）
        final defaultCat = defaultCategories.firstWhere(
          (c) => c.key == category.key,
          orElse: () => category,
        );
        // 如果找到了默认分类且名称不同，使用默认分类的名称
        if (defaultCat.key == category.key && defaultCat.name != category.name) {
          newName = defaultCat.name;
        } else if (category.name.contains('/') || category.name.contains('（') || category.name.contains('与')) {
          // 如果名称包含"/"、"（"或"与"，也更新名称
          newName = defaultCat.name;
        }
      }
      
      // 创建迁移后的分类
      final migratedCategory = Category(
        key: category.key,
        name: newName,
        icon: category.icon,
        isExpense: category.isExpense,
        parentKey: category.parentKey,
        createdAt: category.createdAt,
        updatedAt: category.updatedAt,
      );
      migrated.add(migratedCategory);
    }

    // 新增的内置兜底分类：确保旧数据也能拥有“未分类”，避免后续功能（如语音记账）落到不合理分类。
    if (!migrated.any((c) => c.key == uncategorizedExpenseKey)) {
      final defaultCat = defaultCategories.firstWhere(
        (c) => c.key == uncategorizedExpenseKey,
        orElse: () => Category(
          key: uncategorizedExpenseKey,
          name: AppStrings.catUncategorized,
          icon: Icons.category_outlined,
          isExpense: true,
        ),
      );
      migrated.add(defaultCat);
    }
    
    return migrated;
  }

  /// 检查分类是否需要迁移
  static bool needsMigration(Category category) {
    // 检查是否是需要删除的旧分类key
    if (category.key == 'food_meal' ||
        category.key == 'food_snack' ||
        category.key == 'shop_online' ||
        category.key == 'shop_offline' ||
        category.key == 'trans_ride_hailing' ||
        category.key == 'health_registration' ||
        category.key == 'health_physical' ||
        category.key == 'fun_social' ||
        category.key == 'edu_ebook' ||
        category.key == 'edu_misc' ||
        category.key == 'fin_transfer_fee') {
      return true;
    }
    
    // 检查名称是否包含需要迁移的字符
    if (category.name.contains('/') || 
        category.name.contains('（') || 
        category.name.contains('与')) {
      return true;
    }
    
    // 检查默认分类中是否有相同key但名称不同的分类（说明名称需要更新）
    final defaultCat = defaultCategories.firstWhere(
      (c) => c.key == category.key,
      orElse: () => category,
    );
    if (defaultCat.key == category.key && defaultCat.name != category.name) {
      return true;
    }
    
    return false;
  }

  /// 根据分类key获取新的分类名称
  static String _getNewCategoryName(String key) {
    final defaultCat = defaultCategories.firstWhere(
      (c) => c.key == key,
      orElse: () => Category(
        key: key,
        name: '未分类',
        icon: Icons.category_outlined,
        isExpense: true,
      ),
    );
    return defaultCat.name;
  }

  Future<void> saveCategories(List<Category> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final payload = categories
        .map(
          (c) => c
              .copyWith(
                createdAt: c.createdAt ?? now,
                updatedAt: c.updatedAt ?? now,
              )
              .toJson(),
        )
        .toList();
    await prefs.setStringList(_key, payload);
  }

  Future<List<Category>> add(Category category) async {
    final list = await loadCategories();
    final now = DateTime.now();
    list.add(category.copyWith(createdAt: now, updatedAt: now));
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
      list[index] = category.copyWith(
        createdAt: list[index].createdAt,
        updatedAt: DateTime.now(),
      );
      await saveCategories(list);
    }
    return list;
  }

  /// 将分类名称标准化
  static String sanitizeCategoryName(String key, String name) {
    var v = name.trim();
    if (v.isEmpty) return AppStrings.catUncategorized;

    // 迁移/导入过程中可能存在 "xxx/yyy" 这样的旧名称；UI 不应该直接展示 "/"
    if (v.contains('/')) {
      final parts = v.split('/').map((e) => e.trim()).where((e) => e.isNotEmpty);
      final last = parts.isEmpty ? '' : parts.last;
      v = last.isEmpty ? v.replaceAll('/', ' ') : last;
    }

    // 避免显示“未知”这种研发味兜底；分类缺失时用“未分类”更符合用户预期
    if (v == AppStrings.unknown) return AppStrings.catUncategorized;

    return v;
  }
}
