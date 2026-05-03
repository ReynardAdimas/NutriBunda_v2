# NutriBunda

Aplikasi mobile Flutter untuk memantau gizi MPASI (Makanan Pendamping ASI) anak usia 6–24 bulan dan mendukung program diet pemulihan pasca-melahirkan bagi ibu.

## 📱 Fitur Utama

- **Autentikasi Aman**: Login dengan JWT dan autentikasi biometrik (sidik jari/Face ID)
- **Food Diary**: Pencatatan makanan harian untuk bayi dan ibu
- **Diet Plan**: Kalkulasi BMR/TDEE dan tracking kalori dengan pedometer
- **Shake-to-Recipe**: Rekomendasi resep MPASI dengan menggoyangkan smartphone
- **TanyaBunda AI**: Chatbot konsultan gizi berbasis Gemini API
- **Location-Based Service**: Pencarian fasilitas kesehatan terdekat
- **Kuis Gizi**: Mini game edukatif tentang nutrisi
- **Notifikasi**: Pengingat jadwal makan MPASI dan vitamin
- **Offline-First**: Aplikasi tetap berfungsi tanpa koneksi internet

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.x
- Go 1.26+
- Docker Desktop

### Setup in 5 Minutes

```bash
# 1. Start database
docker-compose up -d

# 2. Setup backend
cd backend
cp .env.example .env
go mod download
go run cmd/api/main.go

# 3. Setup Flutter (in new terminal)
cd nutribunda
flutter pub get
flutter run
```

**Untuk panduan lengkap, lihat [Getting Started Guide](./docs/getting-started/)**

## 📚 Dokumentasi

Semua dokumentasi telah diorganisir di folder [`docs/`](./docs/):

### 🎯 [Getting Started](./docs/getting-started/)
Panduan setup dan memulai development
- [Project Overview](./docs/getting-started/project-overview.md)
- [Database Setup](./docs/getting-started/database-setup.md)
- [Backend Setup](./docs/getting-started/backend-setup.md)
- [Flutter Setup](./docs/getting-started/flutter-setup.md)

### 🔧 [Backend Documentation](./docs/backend/)
Dokumentasi backend API (Golang)
- [API Testing Guide](./docs/backend/api-testing-guide.md)
- [Testing Guide](./docs/backend/testing-guide.md)
- [Modules Documentation](./docs/backend/modules/)

### 📱 [Frontend Documentation](./docs/frontend/)
Dokumentasi Flutter mobile app
- [Testing Guide](./docs/frontend/testing-guide.md)
- [Accessibility Guide](./docs/frontend/accessibility-guide.md)
- [Features Documentation](./docs/frontend/features/)
- [Architecture Documentation](./docs/frontend/architecture/)

### 💡 [Implementation Guides](./docs/implementation/)
Panduan implementasi fitur-fitur spesifik
- [Gemini API Setup](./docs/implementation/gemini-api-setup.md)
- [SQLite Implementation](./docs/implementation/sqlite-implementation.md)
- [Sync Implementation](./docs/implementation/sync-implementation.md)
- [Pedometer Implementation](./docs/implementation/pedometer/)


## 🏗️ Arsitektur

### Frontend (Flutter)
- **Framework**: Flutter 3.x
- **State Management**: Provider
- **Local Storage**: SQLite + flutter_secure_storage
- **Sensors**: Pedometer, Accelerometer, GPS
- **Maps**: Google Maps Flutter

### Backend (Golang)
- **Framework**: Gin
- **Database**: PostgreSQL 14+
- **ORM**: GORM
- **Authentication**: JWT + bcrypt

## 📁 Struktur Proyek

```
NutriBunda/
├── backend/                # Golang backend API
├── nutribunda/            # Flutter mobile app
├── database/              # Database setup
├── docs/                  # 📚 Dokumentasi lengkap
│   ├── getting-started/  # Setup guides
│   ├── backend/          # Backend documentation
│   ├── frontend/         # Frontend documentation
│   ├── implementation/   # Implementation guides
│   ├── tasks/            # Task summaries
│   └── testing/          # Testing documentation
├── .kiro/                # Kiro specs
└── docker-compose.yml    # PostgreSQL container
```
## 🔐 Security

- Passwords di-hash menggunakan bcrypt
- JWT untuk session management
- Secure storage untuk token di device
- Biometric authentication support
- CORS middleware
- Input validation

## 📄 License

This project is private and not licensed for public use.

## 👥 Team

Developed by Reynard Adimas Nabil & Andhika Kusuma Wardana

---

## 🔗 Quick Links

- [📖 Full Documentation](./docs/)
- [🚀 Getting Started](./docs/getting-started/)
- [🔧 Backend API](./docs/backend/)
- [📱 Flutter App](./docs/frontend/)
- [💡 Implementation Guides](./docs/implementation/)

---

**Last Updated**: May 3, 2026
