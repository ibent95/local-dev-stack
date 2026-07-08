<script setup lang="ts">
import { Line } from "vue-chartjs";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
);

interface Props {
  data: { date: string; count: number }[];
}

const props = defineProps<Props>();

const chartData = computed(() => ({
  labels: props.data.map((d) => d.date),
  datasets: [
    {
      label: "Pageviews",
      data: props.data.map((d) => d.count),
      borderColor: "#6366f1",
      backgroundColor: "rgba(99,102,241,0.1)",
      borderWidth: 2,
      pointRadius: 0,
      tension: 0.3,
      fill: true,
    },
  ],
}));

const chartOptions = {
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
    },
  },
  scales: {
    x: {
      grid: { color: "#27272a" },
      ticks: { color: "#71717a" },
    },
    y: {
      grid: { color: "#27272a" },
      ticks: { color: "#71717a" },
    },
  },
};
</script>

<template>
  <div class="h-[260px] w-full">
    <Line v-if="data.length" :data="chartData" :options="chartOptions" />
    <div v-else class="flex h-full items-center justify-center text-zinc-500">No data</div>
  </div>
</template>
