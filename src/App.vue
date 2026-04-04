<script setup lang="ts">
import { RouterView } from 'vue-router'
</script>

<template>
  <div class="min-h-screen bg-gray-900 text-white">
    <header class="p-4 border-b border-gray-700">
      <h1 class="text-2xl font-bold">Leagify Fantasy Auction</h1>
    </header>
    <main class="p-4">
      <RouterView />
    </main>
  </div>
</template>
