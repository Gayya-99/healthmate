# HealthMate – Personal Health & Wellness Tracker

A Flutter app for recording daily **steps**, **calories burned** and **water intake**, reviewing past days, and tracking progress against daily goals.

> **Current build: frontend only.** `DatabaseHelper` keeps records in memory, so data resets when the app restarts. Its methods are written to be swapped for sqflite later without changing the controller or screens (see *Adding SQLite later*).

## Features

**Core**
- Add health entries (date, steps, calories, water) with form validation
- View past records grouped by day, with daily totals
- Edit or delete records (swipe left to delete, with **Undo**)
- Search records by date and filter by Today / Last 7 days / This month / custom range
- Dashboard summary of today's activity

**Additional**
- Daily goals (editable) with animated progress rings
- 7-day bar chart per metric, with a goal line
- Activity streak counter and weekly averages
- Quick-add water buttons (+250 ml / +500 ml)
- Daily goals editable by tapping a dashboard card
- Starts in light mode; dark or system theme can be chosen from the app bar menu
- Alexandria font bundled with the app (works offline)
- Responsive layout for small phones (labels scale down, text size capped at 115%)
- Reload sample data / delete all records (Records menu)
- Unsaved-changes warning on the entry form
- Custom launcher icon

## Architecture – MVC + Provider

```mermaid
flowchart TD
    subgraph Views["View (views/ + widgets/)"]
        D[dashboard_screen.dart]
        L[record_list_screen.dart]
        F[record_form_screen.dart]
        W[metric_card.dart<br/>reusable widgets]
    end
    C[controllers/health_controller.dart<br/>HealthController - ChangeNotifier]
    DB[database/database_helper.dart<br/>DatabaseHelper]
    M[models/health_record.dart<br/>HealthRecord]

    D -- watch / actions --> C
    L -- watch / actions --> C
    F -- add / update / delete --> C
    D --> W
    L --> W
    C -- CRUD + search --> DB
    DB -- rows <-> objects --> M
    C --> M
```

- **Model** – `HealthRecord` (plus `DailySummary`, `DailyGoals`) with `toMap()` / `fromMap()` for the database.
- **Database** – `DatabaseHelper` (singleton) is the only class that stores data. It currently keeps rows in memory in the same shape as the SQLite `health_records` table.
- **Controller** – `HealthController` holds app state, performs CRUD, search/filter and dashboard calculations, and calls `notifyListeners()` so the views rebuild. It is provided to the widget tree with `ChangeNotifierProvider`.
- **Views** – screens that display controller state and send user actions back to it. `widgets/metric_card.dart` contains reusable components (metric card, progress ring, record tile, etc.).

## Project structure

```
lib/
├── main.dart                       # App entry, Provider setup, theme, bottom navigation
├── models/
│   └── health_record.dart          # HealthRecord model + date/number helpers
├── database/
│   └── database_helper.dart        # Data storage (in-memory now, sqflite next) + dummy data
├── controllers/
│   └── health_controller.dart      # State, CRUD, search, dashboard logic, validators
├── views/
│   ├── dashboard_screen.dart       # Today summary, goals, weekly chart
│   ├── record_form_screen.dart     # Add / edit form with validation
│   └── record_list_screen.dart     # Record list with search & filter by date
└── widgets/
    └── metric_card.dart            # Reusable UI components
test/
├── health_record_test.dart         # Model
├── health_controller_test.dart     # CRUD, search, dashboard logic
├── validators_test.dart            # Form validation rules
└── widget_test.dart                # UI flows
```

## Colour scheme

| Element | Colour | Reason |
|---|---|---|
| Brand / primary | Teal `#00897B` | Calm and associated with health |
| Steps | Green `#2E9E5B` | Movement and activity |
| Calories | Red `#E5484D` | Energy and burning |
| Water | Blue `#2F80ED` | Universally associated with water |

## Packages

| Package | Why |
|---|---|
| `provider` | Official, lightweight state management – exposes `HealthController` (a `ChangeNotifier`) to every screen |
| `intl` | Date and number formatting ("18 August 2026", "7,850") |

**Font:** [Alexandria](https://fonts.google.com/specimen/Alexandria) (SIL Open Font License), bundled in `assets/fonts/`.

## Running

```bash
flutter pub get
flutter run
flutter test
flutter build apk --release   # output: build/app/outputs/flutter-apk/app-release.apk
```

## Adding SQLite later

1. Add `sqflite` and `path` to `pubspec.yaml`.
2. In `database/database_helper.dart`, open the database and create the `health_records` table (SQL is in the class comment).
3. Replace the body of each method with the matching sqflite call (`query`, `insert`, `update`, `delete`). `HealthRecord.toMap()` / `fromMap()` already match the table columns.

The method names stay the same, so `HealthController` and the screens do not change.
