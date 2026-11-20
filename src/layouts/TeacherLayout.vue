<script setup>
import { onMounted, onUnmounted, ref } from "vue";
import { RouterLink, RouterView, useRoute, useRouter } from "vue-router";
import Button from "primevue/button";
import { supabase } from "../services/supabase";

const router = useRouter();
const route = useRoute();
const open = ref(false);
const user = ref(null);
const authLoading = ref(false);
let authSubscription = null;

const menu = [
  ["pi-home", "หน้าหลัก", "/teacher"],
  ["pi-check-circle", "เช็คชื่อ", "/teacher/attendance"],
  ["pi-id-card", "รายชื่อครู", "/teacher/homeroom-teachers"],
  ["pi-book", "วิชาและชั้นเรียน", "/teacher/subjects-classes"],
  ["pi-users", "รายชื่อนักเรียน", "/teacher/students"],
  ["pi-calendar", "ตารางเรียน", "/teacher/schedule"],
  ["pi-file-edit", "จัดการข้อสอบ", "/teacher/exams"],
];

async function loadUser() {
  try {
    const { data, error } = await supabase.auth.getUser();
    if (error) {
      user.value = null;
      return;
    }
    user.value = data?.user || null;
  } catch (error) {
    console.error("loadUser:", error);
    user.value = null;
  }
}

async function goLogin() {
  open.value = false;
  await router.push({
    path: "/login",
    query: { redirect: route.fullPath },
  });
}

async function logout() {
  if (!window.confirm("ยืนยันออกจากระบบ?")) return;
  authLoading.value = true;
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    user.value = null;
    open.value = false;
    await router.replace("/login");
  } catch (error) {
    window.alert(error?.message || "ไม่สามารถออกจากระบบได้");
  } finally {
    authLoading.value = false;
  }
}

function menuActive(path) {
  return path === "/teacher"
    ? route.path === "/teacher"
    : route.path.startsWith(path);
}

onMounted(async () => {
  await loadUser();
  const { data } = supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user || null;
  });
  authSubscription = data?.subscription || null;
});

onUnmounted(() => authSubscription?.unsubscribe());
</script>

<template>
  <div class="shell">
    <div v-if="open" class="sidebar-overlay" @click="open = false" />

    <aside :class="['sidebar', { open }]">
      <div class="brand">
        <i class="pi pi-graduation-cap" />
        <div><b>Education Hub</b><small>Teach • Learn • Grow</small></div>
      </div>

      <nav class="menu">
        <RouterLink
          v-for="item in menu"
          :key="item[2]"
          :to="item[2]"
          class="menu-item"
          :class="{ active: menuActive(item[2]) }"
          @click="open = false"
        >
          <i :class="['pi', item[0]]" />
          <span>{{ item[1] }}</span>
        </RouterLink>
      </nav>

      <div class="profile">
        <div class="profile-head">
          <div class="profile-icon"><i class="pi pi-user" /></div>
          <div class="profile-info">
            <template v-if="user">
              <b>ครูผู้สอน</b>
              <small :title="user.email">{{ user.email || "Teacher workspace" }}</small>
            </template>
            <template v-else>
              <b>ยังไม่ได้เข้าสู่ระบบ</b>
              <small>กรุณาเข้าสู่ระบบก่อนใช้งาน</small>
            </template>
          </div>
        </div>

      </div>
    </aside>

    <main class="main">
      <header class="topbar">
        <button type="button" class="menu-toggle" aria-label="เปิดเมนู" @click="open = !open">
          <i class="pi pi-bars" />
        </button>
        <div class="topbar-title">Education Hub</div>
        <div class="topbar-user">
          <template v-if="user">
            <i class="pi pi-user" />
            <div class="topbar-user-info">
              <b>ครูผู้สอน</b>
              <small :title="user.email">{{ user.email || "Teacher workspace" }}</small>
            </div>
            <Button
              type="button"
              label="ออกจากระบบ"
              icon="pi pi-sign-out"
              severity="danger"
              text
              size="small"
              :loading="authLoading"
              @click="logout"
            />
          </template>

          <Button
            v-else
            type="button"
            label="เข้าสู่ระบบ"
            icon="pi pi-sign-in"
            text
            size="small"
            @click="goLogin"
          />
        </div>
      </header>
      <section class="content"><RouterView /></section>
    </main>
  </div>
</template>

<style scoped>
.shell{min-height:100vh;display:grid;grid-template-columns:208px minmax(0,1fr);background:#f4f8fc}.sidebar{position:sticky;top:0;height:100vh;display:flex;flex-direction:column;padding:18px 12px 14px;background:linear-gradient(180deg,#173d6b,#102f56);color:#fff;z-index:50}.brand{display:flex;align-items:center;gap:10px;padding:8px 10px 20px}.brand>i{font-size:24px}.brand b,.brand small,.profile-info b,.profile-info small{display:block}.brand b{font-size:17px}.brand small,.profile-info small{color:#d8e7f7;font-size:10px}.menu{display:grid;gap:6px}.menu-item{min-height:43px;display:flex;align-items:center;gap:12px;padding:0 13px;border-radius:10px;color:#fff;font-size:14px;font-weight:700;text-decoration:none}.menu-item:hover{background:rgba(255,255,255,.1)}.menu-item.active{background:#2867aa}.profile{margin-top:auto;padding:18px 8px 4px;border-top:1px solid rgba(255,255,255,.16)}.profile-head{display:grid;grid-template-columns:auto minmax(0,1fr);align-items:center;gap:10px}.profile-icon{width:34px;height:34px;display:grid;place-items:center;border-radius:50%;background:rgba(255,255,255,.09)}.profile-info{min-width:0}.profile-info small{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.auth-button{width:100%;margin-top:12px}.profile :deep(.p-button){width:100%;justify-content:center}.main{min-width:0;display:grid;grid-template-rows:auto 1fr}.topbar{min-height:70px;position:sticky;top:0;display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:16px;padding:0 25px;border-bottom:1px solid #dbe5ef;background:rgba(255,255,255,.96);z-index:30}.menu-toggle{width:36px;height:36px;display:grid;place-items:center;border:0;border-radius:9px;background:transparent;color:#23b27e;cursor:pointer}.topbar-title{text-align:center;color:#66809d;font-weight:700}.topbar-user{display:flex;align-items:center;gap:6px;color:#596f89;font-size:12px;font-weight:700}.content{min-width:0;padding:22px}.sidebar-overlay{display:none}@media(max-width:900px){.shell{display:block}.sidebar{position:fixed;left:0;width:230px;transform:translateX(-100%);transition:transform .2s}.sidebar.open{transform:translateX(0)}.sidebar-overlay{position:fixed;inset:0;display:block;background:rgba(10,27,46,.38);z-index:40}.content{padding:14px}}@media(max-width:580px){.topbar{min-height:60px;padding:0 12px}.topbar-user span{display:none}.content{padding:10px}}


.topbar-user {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  min-width: 0;
  color: #596f89;
}

.topbar-user-info {
  min-width: 0;
  text-align: left;
}

.topbar-user-info b,
.topbar-user-info small {
  display: block;
}

.topbar-user-info b {
  font-size: 12px;
}

.topbar-user-info small {
  max-width: 180px;
  overflow: hidden;
  color: #7b8fa8;
  font-size: 9px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.topbar-user :deep(.p-button) {
  margin-left: 4px;
  white-space: nowrap;
}

@media (max-width: 580px) {
  .topbar-user-info {
    display: none;
  }

  .topbar-user :deep(.p-button-label) {
    display: none;
  }

  .topbar-user :deep(.p-button) {
    width: 36px;
    height: 36px;
    margin-left: 0;
    padding: 0;
  }
}
</style>
