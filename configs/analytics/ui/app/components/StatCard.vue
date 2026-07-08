<script setup lang="ts">
defineProps<{
  label: string;
  value: string | number;
}>();
</script>

<template>
  <div class="rounded-xl border border-zinc-800 bg-zinc-900 p-5">
    <p class="text-xs font-medium uppercase tracking-wider text-zinc-500">{{ label }}</p>
    <p class="mt-1 text-2xl font-bold">{{ value }}</p>
  </div>
</template>
