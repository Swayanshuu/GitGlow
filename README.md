# GitHub Contribution Live Wallpaper (Flutter) 🎨

A stunning Android Live Wallpaper built with Flutter that displays your GitHub contribution heatmap directly on your home screen.

## ✨ Features

- **Flutter Rendering**: High-performance heatmap visualization using `CustomPainter`.
- **GitHub OAuth**: Secure login flow using `flutter_custom_tabs` and `uni_links`.
- **GraphQL API**: Fetches real-time contribution data.
- **Animated Background**: Smooth, dark-themed gradient that feels alive.
- **Live Wallpaper Bridge**: Native Android service to host the Flutter view.
- **Performance Optimized**: Low battery consumption, rendering only when visible.

## 🛠 Setup Instructions

1. **GitHub OAuth Registry**:
   - Go to [GitHub Developer Settings](https://github.com/settings/developers).
   - Create a new **OAuth App**.
   - Set **Homepage URL** to `https://example.com`.
   - Set **Authorization callback URL** to `githubwallpaper://oauth`.

2. **Android Configuration**:
   - Open `android/local.properties`.
   - Add your credentials:
     ```properties
     GITHUB_CLIENT_ID=your_id
     GITHUB_CLIENT_SECRET=your_secret
     GITHUB_REDIRECT_URI=githubwallpaper://oauth
     ```

3. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

4. **Run the App**:
   - Connect an Android device.
   - Run `flutter run`.

5. **Activate Wallpaper**:
   - Open the app.
   - Login with GitHub.
   - Tap **Set Live Wallpaper**.
   - Select **GitHub Contributions**.

## 🏗 Tech Stack

- **Framework**: Flutter
- **Language**: Dart / Kotlin (Bridge)
- **API**: GitHub GraphQL
- **Storage**: Shared Preferences
- **Deep Linking**: Uni Links

## 📄 License

MIT License
