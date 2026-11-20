<script setup>
import { computed, onMounted, ref } from "vue";
import Button from "primevue/button";
import Card from "primevue/card";
import Message from "primevue/message";
import Tag from "primevue/tag";
import StatCard from "../../components/StatCard.vue";
import { rpc } from "../../services/supabase";

const attendance = ref({ sessions: [], active: null });
const grades = ref([]);
const schedules = ref([]);
const loading = ref(true);
const message = ref("");

const students = computed(() => {
  const set = new Set();
  attendance.value.active?.records?.forEach(
    (r) => r.studentCode && set.add(r.studentCode),
  );
  grades.value.forEach((g) =>
    g.grades?.forEach((r) => r.studentCode && set.add(r.studentCode)),
  );
  return set.size;
});

const attendanceSessionCount = computed(
  () => attendance.value.sessions?.length || 0,
);
const gradeCount = computed(() => grades.value.length);
const scheduleCount = computed(() => schedules.value.length);

const quickMenus = [
  {
    label: "สร้างรหัสเช็คชื่อ",
    description: "เปิดรอบเช็คชื่อสำหรับนักเรียน",
    icon: "pi pi-check-circle",
    tone: "green",
    to: "/teacher/attendance",
  },
  {
    label: "รายชื่อนักเรียน",
    description: "ตรวจสอบข้อมูลนักเรียน",
    icon: "pi pi-users",
    tone: "blue",
    to: "/teacher/students",
  },
  {
    label: "จัดการคะแนน",
    description: "บันทึกและตรวจสอบคะแนน",
    icon: "pi pi-star",
    tone: "orange",
    to: "/teacher/grades",
  },
  {
    label: "จัดการตารางเรียน",
    description: "ดูคาบเรียนและครูสอนแทน",
    icon: "pi pi-calendar",
    tone: "purple",
    to: "/teacher/schedule",
  },
  {
    label: "จัดการข้อสอบ",
    description: "สร้างและจัดการชุดข้อสอบ",
    icon: "pi pi-file-edit",
    tone: "pink",
    to: "/teacher/exams",
  },
  {
    label: "ตั้งค่าระบบ",
    description: "ภาคเรียน ปีการศึกษา และข้อมูลโรงเรียน",
    icon: "pi pi-cog",
    tone: "gray",
    to: "/teacher/settings",
  },
];

async function loadDashboard() {
  loading.value = true;
  message.value = "";
  try {
    const [attendanceData, gradeData, scheduleData] = await Promise.all([
      rpc("teacher_attendance_dashboard"),
      rpc("teacher_gradebook_get"),
      rpc("teacher_schedule_get"),
    ]);
    attendance.value = attendanceData || { sessions: [], active: null };
    grades.value = gradeData || [];
    schedules.value = scheduleData || [];
  } catch (error) {
    message.value = error?.message || "ไม่สามารถโหลดข้อมูลหน้าหลักได้";
  } finally {
    loading.value = false;
  }
}

onMounted(loadDashboard);
</script>

<template>
  <div class="dashboard-page">
    <section class="welcome-hero">
      <div class="welcome-content">
        <span class="welcome-kicker"
          ><i class="pi pi-sparkles" /> TEACHER DASHBOARD</span
        >
        <h1>สวัสดีครับ ครูผู้สอน</h1>
        <p>
          ยินดีต้อนรับสู่ Education Hub
          จัดการงานสอนและข้อมูลนักเรียนได้จากหน้าเดียว
        </p>
        <div class="welcome-actions">
          <RouterLink to="/teacher/attendance"
            ><Button label="เช็คชื่อ" icon="pi pi-check-circle"
          /></RouterLink>
          <RouterLink to="/teacher/schedule"
            ><Button label="ดูตารางเรียน" icon="pi pi-calendar" outlined
          /></RouterLink>
        </div>
      </div>
      <div class="hero-dashboard-art" aria-hidden="true">
        <div class="art-main">
          <i class="pi pi-graduation-cap" /><span></span><span></span>
        </div>
        <div class="art-small art-one"><i class="pi pi-book" /></div>
        <div class="art-small art-two"><i class="pi pi-users" /></div>
      </div>
    </section>

    <Message v-if="message" severity="error" closable @close="message = ''">{{
      message
    }}</Message>

    <section class="stats">
      <StatCard
        icon="pi-users"
        label="นักเรียนทั้งหมด"
        :value="students"
        unit="คน"
        tone="blue"
      />
      <StatCard
        icon="pi-check-circle"
        label="รอบเช็คชื่อทั้งหมด"
        :value="attendanceSessionCount"
        unit="รอบ"
        tone="green"
      />
      <StatCard
        icon="pi-star"
        label="รายการคะแนน"
        :value="gradeCount"
        unit="รายการ"
        tone="orange"
      />
      <StatCard
        icon="pi-calendar"
        label="ตารางเรียน"
        :value="scheduleCount"
        unit="รายการ"
        tone="purple"
      />
    </section>

    <section class="dashboard-grid">
      <Card class="dashboard-card attendance-card"
        ><template #content>
          <div class="card-heading">
            <div class="heading-icon green">
              <i class="pi pi-check-circle" />
            </div>
            <div>
              <h2>รอบเช็คชื่อปัจจุบัน</h2>
              <p>ตรวจสอบหรือสร้างรอบเช็คชื่อสำหรับนักเรียน</p>
            </div>
            <Tag
              v-if="attendance.active"
              severity="success"
              value="กำลังเปิด"
            />
          </div>
          <div v-if="attendance.active" class="active-attendance">
            <div class="attendance-code">
              <small>รหัสเช็คชื่อ</small
              ><strong>{{ attendance.active.code }}</strong>
            </div>
            <div class="attendance-info">
              <b>{{ attendance.active.title || "รอบเช็คชื่อ" }}</b
              ><span>นักเรียนสามารถใช้รหัสนี้สำหรับเช็คชื่อได้</span>
            </div>
            <RouterLink to="/teacher/attendance"
              ><Button
                label="ดูรายละเอียด"
                icon="pi pi-arrow-right"
                icon-pos="right"
            /></RouterLink>
          </div>
          <div v-else class="attendance-empty">
            <div class="empty-icon"><i class="pi pi-plus-circle" /></div>
            <div>
              <b>ยังไม่มีรอบเช็คชื่อที่กำลังเปิด</b>
              <p>สร้างรหัสเช็คชื่อใหม่เพื่อให้นักเรียนเช็คชื่อเข้าเรียน</p>
            </div>
            <RouterLink to="/teacher/attendance"
              ><Button label="สร้างรหัสเช็คชื่อ" icon="pi pi-plus"
            /></RouterLink>
          </div> </template
      ></Card>

      <Card class="dashboard-card"
        ><template #content>
          <div class="card-heading">
            <div class="heading-icon blue"><i class="pi pi-bolt" /></div>
            <div>
              <h2>เมนูลัด</h2>
              <p>เข้าถึงเมนูที่ใช้งานบ่อย</p>
            </div>
          </div>
          <div class="quick-grid">
            <RouterLink
              v-for="item in quickMenus"
              :key="item.to"
              :to="item.to"
              class="quick-item"
            >
              <div :class="['quick-icon', item.tone]">
                <i :class="item.icon" />
              </div>
              <div class="quick-text">
                <b>{{ item.label }}</b
                ><small>{{ item.description }}</small>
              </div>
              <i class="pi pi-chevron-right quick-arrow" />
            </RouterLink>
          </div> </template
      ></Card>
    </section>

    <section class="management-section">
      <div class="management-heading">
        <div>
          <h2>จัดการข้อมูลการเรียน</h2>
          <p>เมนูสำหรับงานสอนและข้อมูลภายในห้องเรียน</p>
        </div>
      </div>
      <div class="management-grid">
        <RouterLink to="/teacher/students" class="management-card"
          ><span class="manage-icon students"><i class="pi pi-users" /></span>
          <div>
            <b>นักเรียน</b><small>ดูและจัดการรายชื่อนักเรียน</small>
          </div></RouterLink
        >
        <RouterLink to="/teacher/schedule" class="management-card"
          ><span class="manage-icon schedule"
            ><i class="pi pi-calendar"
          /></span>
          <div>
            <b>ตารางเรียน</b><small>จัดคาบและครูผู้สอนแทน</small>
          </div></RouterLink
        >
        <RouterLink to="/teacher/exams" class="management-card"
          ><span class="manage-icon exams"><i class="pi pi-file-edit" /></span>
          <div>
            <b>ข้อสอบ</b><small>สร้างและจัดการชุดข้อสอบ</small>
          </div></RouterLink
        >
        <RouterLink to="/teacher/settings" class="management-card"
          ><span class="manage-icon settings"><i class="pi pi-cog" /></span>
          <div>
            <b>ตั้งค่าระบบ</b><small>ตั้งค่าปีการศึกษาและโรงเรียน</small>
          </div></RouterLink
        >
      </div>
    </section>
  </div>
</template>

<style scoped>
.dashboard-page {
  --navy: #102b52;
  --blue: #167df5;
  --green: #19b77c;
  --muted: #71839d;
  --line: #dce7f2;
  display: grid;
  gap: 16px;
}
.welcome-hero {
  position: relative;
  min-height: 190px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  padding: 28px 32px;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 20px;
  background:
    radial-gradient(
      circle at 85% 20%,
      rgba(33, 145, 246, 0.12),
      transparent 24%
    ),
    linear-gradient(110deg, #fff, #f2f8ff 58%, #effbf6);
  box-shadow: 0 14px 36px rgba(24, 57, 94, 0.07);
}
.welcome-content {
  position: relative;
  z-index: 2;
  max-width: 590px;
}
.welcome-kicker {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 6px 10px;
  border-radius: 999px;
  background: #e7f2ff;
  color: var(--blue);
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.06em;
}
.welcome-hero h1 {
  margin: 12px 0 5px;
  color: var(--navy);
  font-size: 32px;
}
.welcome-hero p {
  max-width: 520px;
  margin: 0;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.6;
}
.welcome-actions {
  display: flex;
  gap: 8px;
  margin-top: 18px;
}
.welcome-actions a {
  text-decoration: none;
}
.hero-dashboard-art {
  position: relative;
  width: 260px;
  height: 130px;
  flex: 0 0 260px;
}
.art-main {
  position: absolute;
  right: 30px;
  top: 10px;
  width: 145px;
  height: 112px;
  display: grid;
  grid-template-columns: 43px 1fr;
  align-content: center;
  gap: 9px;
  padding: 18px;
  border: 1px solid #deebf7;
  border-radius: 18px;
  background: #fff;
  box-shadow: 0 18px 35px rgba(36, 91, 145, 0.14);
}
.art-main i {
  grid-row: 1/3;
  width: 43px;
  height: 43px;
  display: grid;
  place-items: center;
  border-radius: 13px;
  background: #e4f2ff;
  color: var(--blue);
  font-size: 21px;
}
.art-main span {
  height: 8px;
  border-radius: 999px;
  background: #dfeaf5;
}
.art-main span:last-child {
  width: 70%;
}
.art-small {
  position: absolute;
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  border-radius: 14px;
  box-shadow: 0 10px 22px rgba(38, 75, 112, 0.12);
}
.art-one {
  left: 24px;
  top: 17px;
  background: #e5f8ef;
  color: #17a66f;
}
.art-two {
  right: 2px;
  bottom: 4px;
  background: #f0e9ff;
  color: #7954d4;
}
.stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}
.dashboard-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(0, 0.9fr);
  gap: 14px;
}
.dashboard-card {
  height: 100%;
  border: 1px solid var(--line);
  border-radius: 18px;
  overflow: hidden;
  box-shadow: 0 10px 28px rgba(24, 57, 94, 0.05);
}
.card-heading {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 11px;
  margin-bottom: 16px;
}
.heading-icon {
  width: 43px;
  height: 43px;
  display: grid;
  place-items: center;
  border-radius: 12px;
  font-size: 18px;
}
.heading-icon.green {
  color: #0ca575;
  background: #ddf8ed;
}
.heading-icon.blue {
  color: #167df5;
  background: #e1efff;
}
.card-heading h2 {
  margin: 0;
  color: var(--navy);
  font-size: 18px;
}
.card-heading p {
  margin: 2px 0 0;
  color: var(--muted);
  font-size: 10px;
}
.active-attendance {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 16px;
  min-height: 135px;
  padding: 18px;
  border: 1px solid #bce8d7;
  border-radius: 15px;
  background: linear-gradient(110deg, #f3fff9, #ecfbf5);
}
.attendance-code {
  min-width: 115px;
  padding: 12px;
  border-radius: 12px;
  background: #fff;
  text-align: center;
  box-shadow: 0 5px 16px rgba(33, 112, 82, 0.08);
}
.attendance-code small {
  display: block;
  color: #698b7c;
  font-size: 9px;
}
.attendance-code strong {
  display: block;
  margin-top: 4px;
  color: #0d9369;
  font-size: 28px;
  letter-spacing: 0.07em;
}
.attendance-info b,
.attendance-info span {
  display: block;
}
.attendance-info b {
  color: #245541;
  font-size: 14px;
}
.attendance-info span {
  margin-top: 4px;
  color: #68877a;
  font-size: 10px;
}
.attendance-empty {
  min-height: 140px;
  display: flex;
  align-items: center;
  gap: 15px;
  padding: 18px;
  border: 1px dashed #cfddea;
  border-radius: 15px;
  background: #f8fbfe;
}
.empty-icon {
  width: 52px;
  height: 52px;
  display: grid;
  place-items: center;
  flex: 0 0 52px;
  border-radius: 50%;
  background: #e4f2ff;
  color: var(--blue);
  font-size: 21px;
}
.attendance-empty > div:nth-child(2) {
  flex: 1;
}
.attendance-empty b {
  color: #294766;
  font-size: 14px;
}
.attendance-empty p {
  margin: 4px 0 0;
  color: var(--muted);
  font-size: 10px;
}
.quick-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.quick-item {
  min-width: 0;
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 9px;
  padding: 11px;
  border: 1px solid #e2eaf3;
  border-radius: 11px;
  background: #fbfdff;
  color: inherit;
  text-decoration: none;
  transition: 0.15s;
}
.quick-item:hover {
  transform: translateY(-1px);
  border-color: #bfd6eb;
  box-shadow: 0 7px 18px rgba(34, 75, 116, 0.07);
}
.quick-icon {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  font-size: 14px;
}
.quick-icon.green {
  color: #0a9e70;
  background: #def8ed;
}
.quick-icon.blue {
  color: #167df5;
  background: #e2f0ff;
}
.quick-icon.orange {
  color: #de8421;
  background: #fff0dc;
}
.quick-icon.purple {
  color: #784cd9;
  background: #eee7ff;
}
.quick-icon.pink {
  color: #cb4c8e;
  background: #fde8f3;
}
.quick-icon.gray {
  color: #536a83;
  background: #e9eef4;
}
.quick-text {
  min-width: 0;
}
.quick-text b,
.quick-text small {
  display: block;
}
.quick-text b {
  color: #294766;
  font-size: 11px;
}
.quick-text small {
  margin-top: 2px;
  overflow: hidden;
  color: #8192a6;
  font-size: 8px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.quick-arrow {
  color: #a2afbc;
  font-size: 9px;
}
.management-section {
  padding: 18px;
  border: 1px solid var(--line);
  border-radius: 18px;
  background: #fff;
  box-shadow: 0 10px 28px rgba(24, 57, 94, 0.04);
}
.management-heading {
  margin-bottom: 13px;
}
.management-heading h2 {
  margin: 0;
  color: var(--navy);
  font-size: 17px;
}
.management-heading p {
  margin: 2px 0 0;
  color: var(--muted);
  font-size: 9px;
}
.management-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 9px;
}
.management-card {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 72px;
  padding: 12px;
  border: 1px solid #e3ebf3;
  border-radius: 12px;
  color: inherit;
  text-decoration: none;
  transition: 0.15s;
}
.management-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(32, 70, 109, 0.08);
}
.manage-icon {
  width: 39px;
  height: 39px;
  display: grid;
  place-items: center;
  flex: 0 0 39px;
  border-radius: 11px;
}
.manage-icon.students {
  color: #167df5;
  background: #e3f0ff;
}
.manage-icon.schedule {
  color: #18a675;
  background: #ddf8ed;
}
.manage-icon.exams {
  color: #7951d5;
  background: #eee7ff;
}
.manage-icon.settings {
  color: #e18327;
  background: #fff0de;
}
.management-card b,
.management-card small {
  display: block;
}
.management-card b {
  color: #294766;
  font-size: 11px;
}
.management-card small {
  margin-top: 2px;
  color: #8192a6;
  font-size: 8px;
}
@media (max-width: 1050px) {
  .stats {
    grid-template-columns: 1fr 1fr;
  }
  .dashboard-grid {
    grid-template-columns: 1fr;
  }
  .hero-dashboard-art {
    display: none;
  }
  .management-grid {
    grid-template-columns: 1fr 1fr;
  }
}
@media (max-width: 700px) {
  .welcome-hero {
    padding: 22px 19px;
  }
  .welcome-hero h1 {
    font-size: 25px;
  }
  .welcome-actions {
    align-items: stretch;
    flex-direction: column;
  }
  .welcome-actions a,
  .welcome-actions :deep(.p-button) {
    width: 100%;
  }
  .stats {
    grid-template-columns: 1fr 1fr;
  }
  .active-attendance {
    grid-template-columns: 1fr;
  }
  .attendance-code {
    width: 100%;
  }
  .attendance-empty {
    align-items: flex-start;
    flex-direction: column;
  }
  .attendance-empty a,
  .attendance-empty :deep(.p-button) {
    width: 100%;
  }
  .quick-grid,
  .management-grid {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 420px) {
  .stats {
    grid-template-columns: 1fr;
  }
}
</style>
