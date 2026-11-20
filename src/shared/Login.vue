<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Button from 'primevue/button'
import Message from 'primevue/message'
import { supabase } from "../services/supabase";

const router = useRouter()
const route = useRoute()
const email = ref('')
const password = ref('')
const loading = ref(false)
const message = ref('')
const showPassword = ref(false)

async function login() {
  message.value = ''

  if (!email.value.trim()) {
    message.value = 'กรุณากรอกอีเมล'
    return
  }

  if (!password.value) {
    message.value = 'กรุณากรอกรหัสผ่าน'
    return
  }

  loading.value = true

  try {
    const { error } = await supabase.auth.signInWithPassword({
      email: email.value.trim(),
      password: password.value,
    })

    if (error) throw error

    const redirect =
      typeof route.query.redirect === 'string' &&
      route.query.redirect.startsWith('/')
        ? route.query.redirect
        : '/teacher'

    await router.replace(redirect)
  } catch (error) {
    message.value =
      error?.message === 'Invalid login credentials'
        ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'
        : error?.message || 'ไม่สามารถเข้าสู่ระบบได้'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <section class="login-card">
      <div class="brand">
        <div class="brand-icon"><i class="pi pi-graduation-cap" /></div>
        <div>
          <h1>Education Hub</h1>
          <p>Teach • Learn • Grow</p>
        </div>
      </div>

      <div class="welcome">
        <span class="badge"><i class="pi pi-shield" /> TEACHER LOGIN</span>
        <h2>เข้าสู่ระบบครูผู้สอน</h2>
        <p>เข้าสู่ระบบเพื่อจัดการเช็คชื่อ นักเรียน ตารางเรียน และข้อสอบ</p>
      </div>

      <Message v-if="message" severity="error" :closable="false">
        {{ message }}
      </Message>

      <form class="login-form" @submit.prevent="login">
        <label>
          <span>อีเมล</span>
          <div class="input-wrap">
            <i class="pi pi-envelope" />
            <input
              v-model="email"
              type="email"
              autocomplete="email"
              placeholder="teacher@school.com"
              :disabled="loading"
            />
          </div>
        </label>

        <label>
          <span>รหัสผ่าน</span>
          <div class="input-wrap">
            <i class="pi pi-lock" />
            <input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="current-password"
              placeholder="กรอกรหัสผ่าน"
              :disabled="loading"
            />
            <button
              type="button"
              class="password-toggle"
              :aria-label="showPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'"
              @click="showPassword = !showPassword"
            >
              <i :class="showPassword ? 'pi pi-eye-slash' : 'pi pi-eye'" />
            </button>
          </div>
        </label>

        <Button
          type="submit"
          label="เข้าสู่ระบบ"
          icon="pi pi-sign-in"
          :loading="loading"
          class="login-button"
        />
      </form>

      <div class="login-note">
        <i class="pi pi-info-circle" />
        <span>ใช้บัญชีครูที่สร้างไว้ใน Supabase Authentication</span>
      </div>
    </section>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background:
    radial-gradient(circle at 15% 15%, #dff4ff 0, transparent 34%),
    radial-gradient(circle at 85% 82%, #dcf8eb 0, transparent 32%),
    linear-gradient(135deg, #f7fbff, #eef6ff 52%, #f3fbf7);
}

.login-card {
  width: min(460px, 100%);
  padding: 28px;
  border: 1px solid #dce8f3;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 22px 60px rgba(29, 67, 107, 0.13);
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-bottom: 22px;
  border-bottom: 1px solid #e5edf5;
}

.brand-icon {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  border-radius: 14px;
  background: linear-gradient(135deg, #2376d8, #173d6b);
  color: #fff;
  font-size: 22px;
}

.brand h1,
.brand p,
.welcome h2,
.welcome p {
  margin: 0;
}

.brand h1 {
  color: #14345d;
  font-size: 21px;
}

.brand p {
  margin-top: 2px;
  color: #71859d;
  font-size: 11px;
}

.welcome {
  padding: 24px 0 18px;
}

.badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 9px;
  border-radius: 999px;
  background: #e8f3ff;
  color: #1975d2;
  font-size: 9px;
  font-weight: 800;
}

.welcome h2 {
  margin-top: 12px;
  color: #102b52;
  font-size: 26px;
}

.welcome p {
  margin-top: 6px;
  color: #72849a;
  font-size: 12px;
  line-height: 1.6;
}

.login-form {
  display: grid;
  gap: 16px;
  margin-top: 18px;
}

.login-form label {
  display: grid;
  gap: 7px;
  color: #294766;
  font-size: 12px;
  font-weight: 700;
}

.input-wrap {
  min-height: 46px;
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 9px;
  padding: 0 12px;
  border: 1px solid #d3dfeb;
  border-radius: 11px;
  background: #fff;
}

.input-wrap:focus-within {
  border-color: #2d8ae7;
  box-shadow: 0 0 0 3px rgba(45, 138, 231, 0.1);
}

.input-wrap > i {
  color: #7f94aa;
}

.input-wrap input {
  min-width: 0;
  width: 100%;
  height: 44px;
  border: 0;
  outline: 0;
  background: transparent;
  color: #17324f;
  font: inherit;
}

.password-toggle {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: #7389a1;
  cursor: pointer;
}

.password-toggle:hover {
  background: #f0f6fc;
}

.login-button {
  width: 100%;
  margin-top: 4px;
}

.login-form :deep(.p-button) {
  justify-content: center;
  min-height: 46px;
  border-radius: 11px;
  font-weight: 800;
}

.login-note {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 20px;
  padding: 11px 12px;
  border-radius: 10px;
  background: #f6f9fc;
  color: #71849b;
  font-size: 10px;
  line-height: 1.5;
}

@media (max-width: 520px) {
  .login-page { padding: 12px; }
  .login-card { padding: 22px 18px; border-radius: 18px; }
  .welcome h2 { font-size: 22px; }
}
</style>
