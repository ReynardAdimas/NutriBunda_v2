import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'injection_container.dart' as di;
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/profile_provider.dart';
import 'presentation/providers/food_diary_provider.dart';
import 'presentation/providers/recipe_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/quiz_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/diet_plan_provider.dart';
import 'presentation/pages/splash/splash_screen.dart';
import 'presentation/pages/onboarding/onboarding_screen.dart';
import 'presentation/pages/auth/login_screen.dart';
import 'presentation/pages/auth/register_screen.dart';
import 'presentation/pages/main_navigation.dart';
import 'presentation/pages/dashboard/dashboard_screen.dart';
import 'presentation/pages/diary/diary_screen.dart';
import 'presentation/pages/profile/profile_screen.dart';
import 'presentation/pages/chat/chat_screen.dart';
import 'presentation/pages/quiz_screen.dart';
import 'presentation/pages/diet_plan/diet_plan_screen.dart';
import 'presentation/pages/recipe/favorite_recipes_screen.dart';
import 'presentation/pages/settings/notification_settings_page.dart';
import 'presentation/pages/settings/biometric_settings_page.dart';
import 'presentation/themes/app_theme.dart';
import 'presentation/providers/currency_provider.dart';
import 'presentation/pages/settings/currency_setting_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Indonesian locale for date formatting
  await initializeDateFormatting('id_ID', null);
  
  // Initialize dependency injection
  await di.init();

  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => di.sl<AuthProvider>()..initializeAuth(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<ProfileProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<FoodDiaryProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<RecipeProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<ChatProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<QuizProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<NotificationProvider>()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<DietPlanProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<CurrencyProvider>()..loadSupportedCurrencies(),
        ),
      ],
      child: MaterialApp(
        title: 'NutriBunda',
        debugShowCheckedModeBanner: false,
        // Task 19.1 - Apply consistent theme across all screens
        theme: AppTheme.lightTheme,
        // Use splash screen as initial route
        initialRoute: '/',
        // Define named routes for navigation
        // Requirements: 13.1, 13.3, 13.4, 13.5, 13.6
        routes: {
          '/': (context) => const SplashScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/main': (context) => const MainNavigation(),
          '/home': (context) => const DashboardScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/diary': (context) => const DiaryScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/chat': (context) => const ChatScreen(),
          '/quiz': (context) => const QuizScreen(),
          '/diet-plan': (context) => const DietPlanScreen(),
          '/favorites': (context) => const FavoriteRecipesScreen(),
          '/settings/notifications': (context) => const NotificationSettingsPage(),
          '/settings/biometric': (context) => const BiometricSettingsPage(),
          '/settings/currency': (context) => const CurrencySettingsPage()
        },
      ),
    );
  }
}
