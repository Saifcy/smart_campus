# Smart Campus Navigation & Event Hub

A comprehensive Flutter application designed to enhance the campus experience through navigation, event management, and real-time updates.

## 🌟 Features

- **Interactive Campus Navigation**
  - Real-time location tracking
  - Interactive campus maps
  - Turn-by-turn navigation
  - Points of interest (POIs) display

- **Event Management**
  - Event creation and management
  - Event notifications
  - Event calendar integration
  - Event registration and attendance tracking

- **User Authentication**
  - Secure login system
  - Google Sign-In integration
  - User profile management
  - Role-based access control

- **Real-time Updates**
  - Push notifications
  - Dynamic content updates
  - Emergency alerts
  - Campus announcements

## 🛠️ Technical Stack

- **Frontend Framework**: Flutter
- **State Management**: Provider & GetX
- **Backend Services**: Firebase
  - Authentication
  - Cloud Firestore
  - Storage
  - Cloud Messaging
  - Dynamic Links
- **Maps Integration**: Google Maps & Flutter Map
- **Localization**: Internationalization (i18n) support
- **UI Components**: Material Design & Custom Components

## 📱 Supported Platforms

- Android
- iOS
- Web
- Windows
- macOS
- Linux

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (^3.7.0)
- Dart SDK
- Firebase account
- Google Maps API key

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Saifcy/smart_campus.git
   ```

2. Navigate to the project directory:
   ```bash
   cd smart_campus
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Configure Firebase:
   - Create a new Firebase project
   - Add your Android/iOS apps to the Firebase project
   - Download and add the configuration files
   - Enable required Firebase services

5. Configure Google Maps:
   - Get a Google Maps API key
   - Add the key to the appropriate configuration files

6. Run the app:
   ```bash
   flutter run
   ```

## 📦 Project Structure

```
lib/
├── core/           # Core functionality and utilities
├── features/       # Feature-based modules
├── shared/         # Shared widgets and components
├── services/       # Service layer (API, Firebase, etc.)
└── main.dart       # Application entry point
```

## 🔧 Configuration

The app requires several configuration files:

- `google-services.json` for Android
- `GoogleService-Info.plist` for iOS
- Environment variables for API keys

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Saif Emad Shaheen** - *Initial work* - [GitHub](https://github.com/Saifcy)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for the backend services
- All contributors who have helped shape this project

## 📞 Contact

Saif Emad Shaheen - semad9238@gmail.com

Project Link: [https://github.com/Saifcy/smart_campus](https://github.com/Saifcy/smart_campus) 
