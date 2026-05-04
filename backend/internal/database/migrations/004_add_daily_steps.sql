CREATE TABLE IF NOT EXISTS daily_steps (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date        DATE NOT NULL,
    steps       INTEGER NOT NULL DEFAULT 0,
    calories_burned DECIMAL(7,2) NOT NULL DEFAULT 0.0,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_steps_user_date ON daily_steps(user_id, date);