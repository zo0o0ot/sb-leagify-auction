<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuctionStore } from '@/stores/auction'

const router = useRouter()
const store = useAuctionStore()

function logout() {
  store.clearSession()
  router.push('/join')
}
</script>

<template>
  <!-- Fixed Header -->
  <header
    class="fixed top-0 w-full z-50 flex justify-between items-center px-6 h-16"
    style="background: #0a0e14; border-bottom: 1px solid rgba(49,53,60,0.3); box-shadow: 0 4px 20px rgba(0,68,147,0.15);"
  >
    <div class="flex items-center gap-8">
      <span class="text-2xl font-black italic tracking-widest text-primary font-headline uppercase">
        DRAFT COMMAND
      </span>
      <nav class="hidden md:flex space-x-8 font-headline uppercase tracking-tighter text-sm">
        <slot name="nav" />
      </nav>
    </div>
    <div class="flex items-center gap-4">
      <slot name="header-actions" />
      <button
        class="text-on-surface-variant hover:text-on-surface p-2 transition-colors"
        @click="logout"
      >
        <span class="material-symbols-outlined">logout</span>
      </button>
    </div>
  </header>

  <!-- Fixed Sidebar -->
  <aside
    class="fixed left-0 top-16 h-[calc(100vh-64px)] w-64 flex flex-col py-8 z-40 font-headline font-bold uppercase"
    style="background: linear-gradient(to right, #1c2026, transparent); background-color: #0a0e14;"
  >
    <div class="px-6 mb-8">
      <slot name="sidebar-header" />
    </div>
    <nav class="flex-1 space-y-1">
      <slot name="sidebar-nav" />
    </nav>
    <div class="px-6 pb-4">
      <slot name="sidebar-footer" />
    </div>
  </aside>

  <!-- Main Content -->
  <main class="ml-64 mt-16">
    <slot />
  </main>

  <!-- Footer Ticker -->
  <footer
    class="fixed bottom-0 left-0 w-full h-10 z-50 flex items-center gap-12 px-10 overflow-hidden whitespace-nowrap font-headline text-sm font-bold uppercase tracking-widest"
    style="background: #31353c; border-top: 2px solid #ffb3b2; box-shadow: 0 -4px 15px rgba(191,1,44,0.2); transform: skewX(-6deg);"
  >
    <div class="flex items-center gap-2 text-secondary animate-pulse shrink-0">
      <span class="w-2 h-2 bg-secondary rounded-full"></span>
      <slot name="ticker-status">SYSTEM STATUS: LIVE</slot>
    </div>
    <div class="flex gap-12 text-on-surface animate-[ticker_20s_linear_infinite]">
      <slot name="ticker-content" />
    </div>
  </footer>
</template>

<style scoped>
@keyframes ticker {
  from { transform: translateX(0); }
  to { transform: translateX(-50%); }
}
</style>
