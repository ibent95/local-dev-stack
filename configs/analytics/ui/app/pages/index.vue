<template>
  <div class="mx-auto max-w-7xl px-4 py-8">
    <!-- Header -->
    <div class="mb-8 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold">📊 LDS Analytics</h1>
        <p class="text-sm text-zinc-500">Privacy-first web analytics</p>
      </div>
      <select
        v-model="selectedSite"
        class="rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm"
      >
        <option v-for="site in sites" :key="site.id" :value="site.id">
          {{ site.name }} ({{ site.domain }})
        </option>
      </select>
    </div>

    <!-- Overview Stats -->
    <div class="mb-6 grid grid-cols-2 gap-4 md:grid-cols-3">
      <StatCard label="Pageviews" :value="overview?.totalPageviews?.toLocaleString() ?? '—'" />
      <StatCard label="Active Days" :value="overview?.uniqueVisitors ?? '—'" />
      <StatCard label="Avg Screen" :value="overview?.avgScreenWidth ? `${overview.avgScreenWidth}px` : '—'" />
    </div>

    <!-- Charts Row -->
    <div class="mb-6 grid gap-6 lg:grid-cols-2">
      <AnalyticsSection title="Pageviews over time">
        <ClientOnly>
          <AnalyticsLineChart :data="pageviews" />
          <template #fallback>
            <div class="flex h-[260px] items-center justify-center text-zinc-500">Loading…</div>
          </template>
        </ClientOnly>
      </AnalyticsSection>

      <AnalyticsSection title="Top Pages">
        <ClientOnly>
          <AnalyticsBarChart :data="topPages.slice(0, 8)" />
          <template #fallback>
            <div class="flex h-[260px] items-center justify-center text-zinc-500">Loading…</div>
          </template>
        </ClientOnly>
      </AnalyticsSection>
    </div>

    <!-- Second Row -->
    <div class="mb-6 grid gap-6 md:grid-cols-3">
      <AnalyticsSection title="Devices">
        <ClientOnly>
          <AnalyticsPieChart :data="devices" name-key="device" />
          <template #fallback>
            <div class="flex h-[200px] items-center justify-center text-zinc-500">Loading…</div>
          </template>
        </ClientOnly>
        <div class="mt-2 flex flex-wrap gap-3 text-xs text-zinc-400">
          <span v-for="d in devices" :key="d.device" class="flex items-center gap-1">
            <component :is="deviceIcon(d.device)" class="h-4 w-4" />
            {{ d.device || 'unknown' }}: {{ d.count }}
          </span>
        </div>
      </AnalyticsSection>

      <AnalyticsSection title="Browsers">
        <ClientOnly>
          <AnalyticsPieChart :data="browsers" name-key="browser" />
          <template #fallback>
            <div class="flex h-[200px] items-center justify-center text-zinc-500">Loading…</div>
          </template>
        </ClientOnly>
        <div class="mt-2 flex flex-wrap gap-3 text-xs text-zinc-400">
          <span v-for="b in browsers" :key="b.browser">
            {{ b.browser || 'unknown' }}: {{ b.count }}
          </span>
        </div>
      </AnalyticsSection>

      <AnalyticsSection title="Top Referrers">
        <div class="space-y-2">
          <p v-if="referrers.length === 0" class="text-sm text-zinc-500">No referrer data yet</p>
          <div v-for="r in referrers.slice(0, 8)" :key="r.referrer" class="flex items-center justify-between text-sm">
            <span class="flex items-center gap-2 truncate text-zinc-300">
              <ExternalLink class="h-3 w-3 shrink-0 text-zinc-500" />
              <span class="truncate">{{ r.referrer }}</span>
            </span>
            <span class="shrink-0 text-zinc-500">{{ r.count }}</span>
          </div>
        </div>
      </AnalyticsSection>
    </div>

    <!-- Countries -->
    <AnalyticsSection v-if="countries.length > 0" title="Countries">
      <div class="flex flex-wrap gap-3">
        <span v-for="c in countries" :key="c.country" class="inline-flex items-center gap-1 rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-1.5 text-sm">
          <Globe class="h-3 w-3 text-zinc-500" />
          {{ c.country }}: {{ c.count }}
        </span>
      </div>
    </AnalyticsSection>

    <!-- Recent Events -->
    <div class="mt-6">
      <AnalyticsSection title="Recent Events">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-zinc-800 text-left text-xs text-zinc-500">
                <th class="pb-2">Time</th>
                <th class="pb-2">Page</th>
                <th class="pb-2">Device</th>
                <th class="pb-2">Browser</th>
                <th class="pb-2">Country</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="e in recent" :key="e.id" class="border-b border-zinc-800/50">
                <td class="py-2 text-zinc-400">{{ new Date(e.created_at).toLocaleTimeString() }}</td>
                <td class="py-2">{{ e.pathname }}</td>
                <td class="py-2 text-zinc-400">{{ e.device || '—' }}</td>
                <td class="py-2 text-zinc-400">{{ e.browser || '—' }}</td>
                <td class="py-2 text-zinc-400">{{ e.country || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </AnalyticsSection>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Globe, Monitor, Smartphone, Tablet, ExternalLink } from "lucide-vue-next";

const { sites, selectedSite, overview, pageviews, topPages, referrers, countries, devices, browsers, recent, loadSites, loadAnalytics } = useAnalytics();

function deviceIcon(device: string) {
  switch (device) {
    case "mobile": return Smartphone;
    case "tablet": return Tablet;
    default: return Monitor;
  }
}

onMounted(async () => {
  await loadSites();
});

watch(selectedSite, async (siteId) => {
  if (siteId) await loadAnalytics(siteId);
});
</script>
