import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'http://localhost:54321'
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  global: {
    headers: {
      get 'x-session-token'() {
        try {
          const raw = localStorage.getItem('auction_session')
          if (!raw) return ''
          return JSON.parse(raw).sessionToken ?? ''
        } catch {
          return ''
        }
      },
    },
  },
})
