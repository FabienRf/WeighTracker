# ⚖️ WeighTracker

Lightweight weight-tracking app to manage profiles, log weigh-ins, and monitor
progress toward personal goals.

## 🛠️ Technologies

- Flutter (Material 3)
- Dart
- SharedPreferences for local persistence
- fl_chart for weight evolution charts
- intl for date/number formatting

## 📋 Features

- Create and switch between multiple user profiles (name, height, current
  weight, goal weight).
- Log weigh-ins with date and optional note; prevent duplicate dates and future
  entries.
- View progress toward the goal with percentages, progress bar, and line chart
  over selectable ranges.
- Edit goals and profiles; delete profiles along with their stored entries.

## 💡 How it can be improved

- Add cloud sync/auth to keep data across devices.
- Export/import weight history (CSV/JSON) and simple analytics (trends, pace).
- Reminders/notifications for regular weigh-ins.
- Theming and accessibility refinements (contrast, larger text presets).
- UI polish for tablets/desktop layouts and chart interactions (zoom/tooltip
  details).

## ⚡ Running the project

1. Install Flutter SDK and set up a device/emulator (`flutter doctor`).
2. From the project root:
   - `flutter pub get`
   - `flutter run`
3. Select your target device (Android, iOS, web, or desktop where supported)
   when prompted.

## 🍿 Video

- "WeighTracker Demo: Track Weight and Hit Your Goal"
