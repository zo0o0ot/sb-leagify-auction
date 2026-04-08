import { fileURLToPath, URL } from 'node:url'

import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
const env = loadEnv(process.env.NODE_ENV || 'development', process.cwd(), '')
const requiredEnvVars = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_ANON_KEY']
const missingEnvVars = requiredEnvVars.filter(key => !env[key])

if (missingEnvVars.length > 0) {
  console.warn(`\n⚠️  WARNING: Missing required environment variables: ${missingEnvVars.join(', ')}`)
  console.warn('⚠️  The application will build, but API requests will fail. Please check your .env file or deployment settings.\n')
}

export default defineConfig({
  plugins: [
    vue(),
    vueDevTools(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    },
  },
})

