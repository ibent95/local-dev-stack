-- LDS Analytics database initialization
-- Creates the sites and events tables for the analytics app

CREATE TABLE IF NOT EXISTS sites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE NOT NULL,
  pathname TEXT NOT NULL DEFAULT '/',
  referrer TEXT,
  country TEXT,
  city TEXT,
  device TEXT,
  browser TEXT,
  os TEXT,
  screen_width INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_site_created ON events(site_id, created_at);
CREATE INDEX IF NOT EXISTS idx_events_created ON events(created_at);
