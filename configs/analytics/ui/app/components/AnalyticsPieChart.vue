<script setup lang="ts">
import { Doughnut } from "vue-chartjs";
import { Chart as ChartJS, ArcElement, Tooltip } from "chart.js";

ChartJS.register(ArcElement, Tooltip);

interface Props {
  data: Record<string, string | number>[];
  nameKey: string;
}

const props = defineProps<Props>();

const COLORS = ["#6366f1", "#818cf8", "#a5b4fc", "#c7d2fe", "#e0e7ff", "#312e81"];

const chartData = computed(() => ({
  labels: props.data.map((d) => String(d[props.nameKey] ?? "unknown")),
  datasets: [
    {
      data: props.data.map((d) => Number(d.count)),
      backgroundColor: COLORS,
      borderColor: "#09090b",
      borderWidth: 2,
    },
  ],
}));

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: "55%",
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
};
</script>

<template>
  <div class="h-[200px] w-full">
    <Doughnut v-if="data.length" :data="chartData" :options="chartOptions" />
    <div v-else class="flex h-full items-center justify-center text-zinc-500">No data</div>
  </div>
</template>
