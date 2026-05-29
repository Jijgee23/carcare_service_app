# Авто машины оношилгооны апп — Flutter

## Файлын бүтэц

```
lib/
├── main.dart                          # App entry point, MultiProvider
├── core/
│   └── theme/
│       └── app_theme.dart             # AppColors, AppTextStyles, AppDimens, AppTheme
├── models/
│   └── models.dart                    # CheckItem, InspectionSection, Vehicle, InspectionRecord, SampleData
├── providers/
│   └── providers.dart                 # InspectionProvider, NewInspectionProvider, BottomNavProvider
├── widgets/
│   ├── common/
│   │   └── common_widgets.dart        # StatusBadge, CheckItemRow, StatCounterRow, AppCard, AppTextField, AppButton ...
│   └── cards/
│       └── inspection_cards.dart      # InspectionListCard, QuickActionCard, TodaySummaryCard, PhotoGrid
└── screens/
    ├── main_shell.dart                # Bottom nav + FAB shell
    ├── home/
    │   └── home_screen.dart           # Нүүр дэлгэц
    ├── inspection/
    │   ├── new_inspection_screen.dart # 3 алхамт форм (Мэдээлэл → Чеклист → Тайлбар)
    │   └── inspection_result_screen.dart # Дэлгэрэнгүй харах
    ├── history/
    │   └── history_screen.dart        # Жагсаалт + шүүлтүүр
    └── analytics/
        └── analytics_screen.dart      # Тайлан, Donut chart, Bar chart
```

## Суулгах

```bash
flutter pub get
flutter run
```

## Ашигласан багцууд

| Багц | Зорилго |
|------|---------|
| `provider ^6.1.2` | State management |
| `go_router ^13.2.0` | Navigation |
| `fl_chart ^0.68.0` | Donut & Bar charts |
| `intl ^0.19.0` | Огноо форматлах |
| `image_picker ^1.1.2` | Зураг оруулах |

## Architecture

- **Provider** pattern — `ChangeNotifier` + `ChangeNotifierProvider`
- **Separation of concerns** — models, providers, screens, widgets тусдаа
- **Reusable widgets** — `AppCard`, `AppButton`, `AppTextField`, `StatusBadge`, `StatCounterRow`
- **Theme tokens** — `AppColors`, `AppTextStyles`, `AppDimens` нэгдсэн системтэй
