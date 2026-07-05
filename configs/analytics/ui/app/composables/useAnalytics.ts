import type {
  Site, Overview, TimeSeriesPoint, TopPage, Referrer,
  Country, DeviceBreakdown, BrowserBreakdown, RecentEvent,
} from "~/types/api";

const BASE = "/api";

export async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`);
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export function useAnalytics() {
  const sites = ref<Site[]>([]);
  const selectedSite = ref("");
  const overview = ref<Overview | null>(null);
  const pageviews = ref<TimeSeriesPoint[]>([]);
  const topPages = ref<TopPage[]>([]);
  const referrers = ref<Referrer[]>([]);
  const countries = ref<Country[]>([]);
  const devices = ref<DeviceBreakdown[]>([]);
  const browsers = ref<BrowserBreakdown[]>([]);
  const recent = ref<RecentEvent[]>([]);

  async function loadSites() {
    sites.value = await fetchJson<Site[]>("/sites");
    if (sites.value.length > 0) {
      selectedSite.value = sites.value[0].id;
    }
  }

  async function loadAnalytics(siteId: string) {
    const base = `/analytics/${siteId}`;
    const [ov, pv, tp, ref, co, dev, br, rec] = await Promise.all([
      fetchJson<Overview>(`${base}/overview`),
      fetchJson<TimeSeriesPoint[]>(`${base}/pageviews`),
      fetchJson<TopPage[]>(`${base}/top-pages`),
      fetchJson<Referrer[]>(`${base}/referrers`),
      fetchJson<Country[]>(`${base}/countries`),
      fetchJson<DeviceBreakdown[]>(`${base}/devices`),
      fetchJson<BrowserBreakdown[]>(`${base}/browsers`),
      fetchJson<RecentEvent[]>(`${base}/recent`),
    ]);
    overview.value = ov;
    pageviews.value = pv;
    topPages.value = tp;
    referrers.value = ref;
    countries.value = co;
    devices.value = dev;
    browsers.value = br;
    recent.value = rec;
  }

  return {
    sites, selectedSite, overview, pageviews, topPages,
    referrers, countries, devices, browsers, recent,
    loadSites, loadAnalytics,
  };
}
