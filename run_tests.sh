#!/bin/bash
echo "=============================="
echo "  NutriBunda Test Suite"
echo "=============================="

echo ""
echo "▶ Menjalankan Backend Tests..."
cd backend
go test ./... -v
BACKEND_STATUS=$?
cd ..

echo ""
echo "▶ Menjalankan Flutter Tests..."
cd nutribunda
flutter test --verbose
FLUTTER_STATUS=$?
cd ..

echo ""
echo "=============================="
echo "  Ringkasan Hasil"
echo "=============================="
if [ $BACKEND_STATUS -eq 0 ]; then
  echo "✅ Backend Tests: LULUS"
else
  echo "❌ Backend Tests: GAGAL"
fi

if [ $FLUTTER_STATUS -eq 0 ]; then
  echo "✅ Flutter Tests: LULUS"
else
  echo "❌ Flutter Tests: GAGAL"
fi
