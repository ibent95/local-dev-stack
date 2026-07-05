export interface Site {
  id: string;
  domain: string;
  name: string;
  created_at: string;
}

export interface Overview {
  totalPageviews: number;
  uniqueVisitors: number;
  avgScreenWidth: number;
  period: { since: string; until: string };
}

export interface TimeSeriesPoint {
  date: string;
  count: number;
}

export interface TopPage {
  pathname: string;
  count: number;
}

export interface Referrer {
  referrer: string;
  count: number;
}

export interface Country {
  country: string | null;
  count: number;
}

export interface DeviceBreakdown {
  device: string;
  count: number;
}

export interface BrowserBreakdown {
  browser: string;
  count: number;
}

export interface RecentEvent {
  id: number;
  site_id: string;
  pathname: string;
  referrer: string | null;
  country: string | null;
  device: string | null;
  browser: string | null;
  os: string | null;
  created_at: string;
}
