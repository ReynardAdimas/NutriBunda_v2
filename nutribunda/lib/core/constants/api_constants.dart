import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Base URL - will be configured later
  static const String baseUrl = 'https://nutribundav2-production.up.railway.app/api';
  
  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  
  // Profile endpoints
  static const String profile = '/profile';
  static const String uploadImage = '/profile/upload-image';
  
  // Food endpoints
  static const String foods = '/foods';
  static const String foodsSync = '/foods/sync';
  
  // Diary endpoints
  static const String diary = '/diary';
  
  // Recipe endpoints
  static const String recipes = '/recipes';
  static const String recipesRandom = '/recipes/random';
  static const String recipesFavorites = '/recipes/favorites';
  
  // Quiz endpoints
  static const String quizQuestions = '/quiz/questions';
  static const String quizSubmit = '/quiz/submit';
  
  // Gemini API endpoints
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-2.5-flash';
  // API Key should be configured via environment variable or secure config
  // For development, you can set it here temporarily, but NEVER commit the actual key
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  
  // Timeout
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration geminiTimeout = Duration(seconds: 60); 

  // currency 
  static const String currencyBase = '/currency'; 
  static const String currencySupported = '/currency/supported'; 
  static const String currencyRate = '/currency/rate'; 
  static const String currencyConvert = '/currency/convert';
}

