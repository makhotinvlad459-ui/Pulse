import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

extension BackendLocalizer on BuildContext {
  String localizeString(String string) {
    final t = AppLocalizations.of(this)!;
    switch (string) {
      // Единицы измерения
      case 'шт':
        return t.unitPcs;
      case 'кг':
        return t.unitKg;
      case 'г':
        return t.unitG;
      case 'л':
        return t.unitL;
      case 'мл':
        return t.unitMl;
      case 'м':
        return t.unitM;
      case 'см':
        return t.unitCm;
      case 'упаковка':
        return t.unitPackage;
      // Типы счетов
      case 'Наличные':
        return t.accountTypeCash;
      case 'Банк':
        return t.accountTypeBank;
      case 'Пользовательский':
        return t.accountTypeCustom;
      // Роли
      case 'Управляющий':
        return t.roleManager;
      case 'Сотрудник':
        return t.roleEmployee;
      case 'Основатель':
        return t.roleFounder;
      // Статусы заказов
      case 'Ожидают':
        return t.orderStatusPending;
      case 'Приняты':
        return t.orderStatusAccepted;
      case 'Выполнены':
        return t.orderStatusCompleted;
      case 'Провалены':
        return t.orderStatusFailed;
      default:
        return string;
    }
  }
}