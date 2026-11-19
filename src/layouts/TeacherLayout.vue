<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import Button from "primevue/button";
const router = useRouter();
const open = ref(false);
const menu = [
  ["pi-home", "หน้าหลัก", "/teacher"],
  ["pi-check-circle", "เช็คชื่อ", "/teacher/attendance"],
  ["pi-id-card", "รายชื่อครู", "/teacher/homeroom-teachers"],
  ["pi-book", "วิชาและชั้นเรียน", "/teacher/subjects-classes"],
  ["pi-users", "รายชื่อนักเรียน", "/teacher/students"],
  // ["pi-star", "คะแนน", "/teacher/grades"],
  ["pi-calendar", "ตารางเรียน", "/teacher/schedule"],
  ["pi-file-edit", "จัดการข้อสอบ", "/teacher/exams"],
];
</script>
<template>
  <div class="shell">
    <aside :class="['sidebar', { open }]">
      <div class="brand">
        <i class="pi pi-graduation-cap" />
        <div><b>Education Hub</b><small>Teach • Learn • Grow</small></div>
      </div>
      <nav>
        <RouterLink
          v-for="m in menu"
          :key="m[2]"
          :to="m[2]"
          @click="open = false"
          ><i :class="['pi', m[0]]" />{{ m[1] }}</RouterLink
        >
      </nav>
      <div class="profile">
        <i class="pi pi-user" />
        <div><b>ครูผู้สอน</b><small>Teacher workspace</small></div>
      </div>
    </aside>
    <main>
      <header>
        <Button
          icon="pi pi-bars"
          text
          rounded
          class="mobile"
          @click="open = !open"
        /><span>{{
          new Date().toLocaleDateString("th-TH", { dateStyle: "full" })
        }}</span>
        <div><i class="pi pi-bell" /> <b>ครูผู้สอน</b></div>
      </header>
      <section class="content"><RouterView /></section>
    </main>
    <nav class="bottom">
      <RouterLink v-for="m in menu" :key="m[2]" :to="m[2]"
        ><i :class="['pi', m[0]]" /><small>{{ m[1] }}</small></RouterLink
      >
    </nav>
  </div>
</template>
