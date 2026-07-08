<script setup lang="ts">
defineProps<{
  title: string;
}>();
</script>

<template>
  <div class="rounded-xl border border-zinc-800 bg-zinc-900 p-5">
    <h2 class="mb-4 text-sm font-medium uppercase tracking-wider text-zinc-500">{{ title }}</h2>
    <slot />
  </div>
</template>
