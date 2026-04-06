<script setup lang="ts">
defineProps<{ visible: boolean }>()
const emit = defineEmits<{ retry: [] }>()
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-300"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-300"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="visible"
        class="fixed inset-0 z-[80] bg-black/85 backdrop-blur-sm flex flex-col items-center justify-center gap-6"
      >
        <span class="material-symbols-outlined text-6xl text-error animate-pulse">wifi_off</span>
        <div class="text-center">
          <div class="font-headline font-black uppercase text-error text-3xl tracking-tighter">CONNECTION LOST</div>
          <div class="text-sm font-label text-outline uppercase tracking-widest mt-2">
            Attempting to reconnect...
          </div>
        </div>
        <button
          class="px-8 py-3 bg-error-container text-on-error-container font-label font-black text-sm uppercase hover:bg-error/20 transition-colors active:scale-95"
          @click="emit('retry')"
        >
          Retry Now
        </button>
      </div>
    </Transition>
  </Teleport>
</template>
