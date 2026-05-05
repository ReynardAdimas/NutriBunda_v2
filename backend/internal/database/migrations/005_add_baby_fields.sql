-- Migration 005: Add baby nutrition fields to users table
-- Menambahkan kolom data bayi untuk kalkulasi target MPASI dinamis
-- (Holliday-Segar + standar WHO/IDAI)

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS baby_birth_date DATE,
    ADD COLUMN IF NOT EXISTS baby_weight_kg  DECIMAL(5, 2);

COMMENT ON COLUMN users.baby_birth_date IS
    'Tanggal lahir bayi. Digunakan untuk menghitung usia dalam bulan secara dinamis.';

COMMENT ON COLUMN users.baby_weight_kg IS
    'Berat badan bayi terakhir (kg). Digunakan untuk kalkulasi Holliday-Segar. NULL = fallback data statis WHO.';