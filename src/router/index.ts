import { createRouter, createWebHistory } from 'vue-router'
import { useAuctionStore } from '@/stores/auction'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/join',
    },
    {
      path: '/join',
      name: 'join',
      component: () => import('@/views/JoinView.vue'),
    },
    {
      path: '/create',
      name: 'create',
      component: () => import('@/views/CreateAuctionView.vue'),
    },
    {
      path: '/auction/:id/lobby',
      name: 'lobby',
      component: () => import('@/views/auction/LobbyView.vue'),
      meta: { requiresSession: true },
    },
    {
      path: '/auction/:id/draft',
      name: 'draft',
      component: () => import('@/views/auction/DraftView.vue'),
      meta: { requiresSession: true },
    },
    {
      path: '/admin/schools',
      name: 'admin-schools',
      component: () => import('@/views/admin/MaintainSchoolsView.vue'),
    },
  ],
})

router.beforeEach((to) => {
  if (to.meta.requiresSession) {
    const store = useAuctionStore()
    const session = store.loadSession()
    if (!session) return { name: 'join' }
    // Redirect to correct auction if ID mismatch
    const routeAuctionId = Number(to.params.id)
    if (session.auctionId !== routeAuctionId) return { name: 'join' }
  }
})

export default router
