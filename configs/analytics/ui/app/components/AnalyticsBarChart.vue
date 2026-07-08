<script setup lang="ts">
import { Bar } from "vue-chartjs";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
} from "chart.js";

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip);

interface Props {
  data: { pathname: string; count: number }[];
}

const props = defineProps<Props>();

const chartData = computed(() => ({
  labels: props.data.map((d) =>
    d.pathname.length > 18 ? d.pathname.slice(0, 18) + "…" : d.pathname,
  ),
  datasets: [
    {
      label: "Views",
      data: props.data.map((d) => d.count),
      backgroundColor: "#6366f1",
      borderRadius: 4,
      barThickness: 16,
    },
  ],
}));

const chartOptions = {
  indexAxis: "y" as const,
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: "#18181b",
      borderColor: "#27272a",
      borderWidth: 1,
      titleColor: "#fafafa",
      bodyColor: "#fafafa",
      cornerRadius: 8,
      callbacks: {
        label: (ctx: { parsed: { x: number } }) => `${ctx.parsed.x} views`,
      },
    },
  },
  scales: {
    x: {
      grid: { color: "#27272a" },
      ticks: { color: "#71717a" },
    },
    y: {
      grid: { display: false },
      ticks: { color: "#71717a" },
    },
  },
};
</script>

<template>
  <div class="h-[260px] w-full">
    <Bar v-if="data.length" :data="chartData" :options="chartOptions" />
    <div v-else class="flex h-full items-center justify-center text-zinc-500">No data</div>
  </div>
</template>
