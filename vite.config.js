import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ command }) => ({
  plugins: [vue()],

  // npm run dev      => /
  // npm run build    => /Education/
  base: command === 'serve'
    ? '/'
    : '/Education/'
}))
