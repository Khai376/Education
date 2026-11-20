<script setup>
import { computed, onMounted, ref } from "vue";
import Button from "primevue/button";
import Card from "primevue/card";
import Column from "primevue/column";
import DataTable from "primevue/datatable";
import Dialog from "primevue/dialog";
import InputText from "primevue/inputtext";
import Message from "primevue/message";
import Select from "primevue/select";
import Tag from "primevue/tag";
import { rpc } from "../../services/supabase";
import schoolLogo from "../../assets/image.png";

const weekDays = [
  { key: 1, label: "จันทร์" },
  { key: 2, label: "อังคาร" },
  { key: 3, label: "พุธ" },
  { key: 4, label: "พฤหัสบดี" },
  { key: 5, label: "ศุกร์" },
];
const teachingPeriods = [
  { key: 1, label: "คาบ 1", start: "08:30", end: "09:30" },
  { key: 2, label: "คาบ 2", start: "09:30", end: "10:30" },
  { key: 3, label: "คาบ 3", start: "10:30", end: "11:30" },
  { key: 4, label: "คาบ 4", start: "12:30", end: "13:30" },
  { key: 5, label: "คาบ 5", start: "13:30", end: "14:30" },
  { key: 6, label: "คาบ 6", start: "14:30", end: "15:30" },
];

const schoolReport = ref({
  schoolName: "โรงเรียนบ้านบ่อ",
  semester: "2",
  academicYear: "2569",
  academicHeadTitle: "หัวหน้าฝ่ายวิชาการ",
  academicHeadName: "นางสาวพิกุลทอง ถ่องตะคุ",
  directorTitle: "ผู้อำนวยการ",
  directorName: "นายจิรวัฒน์ แสงสุรินทร์",
});
const teachers = ref([]),
  schedule = ref([]),
  loading = ref(false),
  saving = ref(false),
  deleting = ref(false);
const message = ref(""),
  successMessage = ref(""),
  search = ref("");
const gradeFilter = ref("all"),
  roomFilter = ref("all"),
  statusFilter = ref("all");
const editorVisible = ref(false),
  deleteVisible = ref(false),
  subjectsVisible = ref(false),
  scheduleVisible = ref(false);
const editId = ref(null),
  deleteTarget = ref(null),
  selectedTeacher = ref(null),
  printTeacher = ref(null);

const gradeLevels = [
  "ป.1",
  "ป.2",
  "ป.3",
  "ป.4",
  "ป.5",
  "ป.6",
  "ม.1",
  "ม.2",
  "ม.3",
].map((value) => ({ label: value, value }));
const rooms = [1, 2, 3, 4, 5, 6].map((value) => ({
  label: `ห้อง ${value}`,
  value: String(value),
}));
const statuses = [
  { label: "ใช้งาน", value: "active" },
  { label: "พักการใช้งาน", value: "inactive" },
];
function emptyForm() {
  return {
    teacherCode: "",
    teacherName: "",
    gradeLevel: "ป.1",
    room: "1",
    phone: "",
    email: "",
    status: "active",
  };
}
const form = ref(emptyForm());

const filteredTeachers = computed(() => {
  const term = search.value.trim().toLowerCase();
  return teachers.value.filter((row) => {
    const matchesSearch =
      !term ||
      [
        row.teacherCode,
        row.teacherName,
        row.email,
        row.phone,
        (row.teachingSubjects || []).map((s) => s.subjectName).join(" "),
      ].some((v) =>
        String(v || "")
          .toLowerCase()
          .includes(term),
      );
    return (
      matchesSearch &&
      (gradeFilter.value === "all" || row.gradeLevel === gradeFilter.value) &&
      (roomFilter.value === "all" ||
        String(row.room) === String(roomFilter.value)) &&
      (statusFilter.value === "all" || row.status === statusFilter.value)
    );
  });
});
const activeCount = computed(
  () => teachers.value.filter((r) => r.status === "active").length,
);
const inactiveCount = computed(() => teachers.value.length - activeCount.value);
const assignedRoomCount = computed(
  () =>
    new Set(
      teachers.value
        .filter((r) => r.gradeLevel && r.room)
        .map((r) => `${r.gradeLevel}/${r.room}`),
    ).size,
);
function teachingSubjects(row) {
  return row.teachingSubjects || [];
}
function visibleSubjects(row) {
  return teachingSubjects(row).slice(0, 2);
}
function hiddenSubjectCount(row) {
  return Math.max(0, teachingSubjects(row).length - 2);
}
function initials(name) {
  return (
    String(name || "?")
      .trim()
      .charAt(0) || "?"
  );
}
function statusLabel(s) {
  return s === "active" ? "ใช้งาน" : "พักการใช้งาน";
}
function statusSeverity(s) {
  return s === "active" ? "success" : "secondary";
}
function generateTeacherCode() {
  const used = new Set(teachers.value.map((r) => String(r.teacherCode || "")));
  let n = 1,
    code = `T${String(n).padStart(3, "0")}`;
  while (used.has(code)) {
    n++;
    code = `T${String(n).padStart(3, "0")}`;
  }
  return code;
}

function teacherSchedule(id) {
  return schedule.value
    .filter((e) => String(e.lessonOwnerTeacherId || e.teacherId) === String(id))
    .sort(
      (a, b) =>
        Number(a.dayOfWeek) - Number(b.dayOfWeek) ||
        String(a.startTime).localeCompare(String(b.startTime)),
    );
}
function teacherPeriodCount(id) {
  return teacherSchedule(id).length;
}
function lessonAt(id, day, p) {
  return (
    teacherSchedule(id).find(
      (e) =>
        Number(e.dayOfWeek) === Number(day) &&
        String(e.startTime).slice(0, 5) === p.start,
    ) || null
  );
}
function lessonTone(lesson) {
  const name = String(lesson?.subjectName || "");
  if (name.includes("วิทยาศาสตร์")) return "science";
  if (name.includes("การงาน")) return "work";
  if (name.includes("ภาษาไทย")) return "thai";
  if (name.includes("คณิต")) return "math";
  return "default";
}

async function load() {
  loading.value = true;
  message.value = "";
  try {
    const [t, s, settings] = await Promise.all([
      rpc("teacher_homeroom_list"),
      rpc("teacher_schedule_list"),
      rpc("teacher_school_settings_get").catch(() => null),
    ]);
    teachers.value = t || [];
    schedule.value = s || [];
    if (settings) {
      schoolReport.value = { ...schoolReport.value, ...settings };
    }
  } catch (e) {
    message.value = e.message || "ไม่สามารถโหลดข้อมูลครูได้";
  } finally {
    loading.value = false;
  }
}
function addTeacher() {
  editId.value = null;
  form.value = emptyForm();
  form.value.teacherCode = generateTeacherCode();
  editorVisible.value = true;
}
function editTeacher(r) {
  editId.value = r.id;
  form.value = {
    teacherCode: r.teacherCode || "",
    teacherName: r.teacherName || "",
    gradeLevel: r.gradeLevel || "ป.1",
    room: String(r.room || "1"),
    phone: r.phone || "",
    email: r.email || "",
    status: r.status || "active",
  };
  editorVisible.value = true;
}
async function saveTeacher() {
  const p = {
    id: editId.value,
    teacherCode: form.value.teacherCode.trim(),
    teacherName: form.value.teacherName.trim(),
    gradeLevel: form.value.gradeLevel,
    room: form.value.room,
    phone: form.value.phone.trim(),
    email: form.value.email.trim(),
    status: form.value.status,
  };
  if (!p.teacherCode) return (message.value = "กรุณาระบุรหัสครู");
  if (!p.teacherName) return (message.value = "กรุณากรอกชื่อครู");
  saving.value = true;
  try {
    await rpc("teacher_homeroom_save", { p_payload: p });
    editorVisible.value = false;
    successMessage.value = editId.value ? "แก้ไขข้อมูลครูแล้ว" : "เพิ่มครูแล้ว";
    await load();
  } catch (e) {
    message.value = e.message || "บันทึกไม่ได้";
  } finally {
    saving.value = false;
  }
}
function askDelete(r) {
  deleteTarget.value = r;
  deleteVisible.value = true;
}
async function deleteTeacher() {
  if (!deleteTarget.value?.id) return;
  deleting.value = true;
  try {
    await rpc("teacher_homeroom_delete", {
      p_homeroom_teacher_id: deleteTarget.value.id,
    });
    deleteVisible.value = false;
    successMessage.value = "ลบข้อมูลครูแล้ว";
    await load();
  } catch (e) {
    message.value = e.message || "ลบไม่ได้";
  } finally {
    deleting.value = false;
  }
}
function showSubjects(r) {
  selectedTeacher.value = r;
  subjectsVisible.value = true;
}
function showSchedule(r) {
  selectedTeacher.value = r;
  scheduleVisible.value = true;
}
function printTeacherSchedule(r) {
  printTeacher.value = r;
  const old = document.title;
  document.title = `ตารางสอน-${r.teacherName}`;
  document.body.classList.add("teacher-schedule-printing");
  const clean = () => {
    document.body.classList.remove("teacher-schedule-printing");
    printTeacher.value = null;
    document.title = old;
    window.removeEventListener("afterprint", clean);
  };
  window.addEventListener("afterprint", clean);
  setTimeout(() => window.print(), 120);
}
onMounted(load);
</script>

<template>
  <div class="homeroom-page">
    <section class="hero">
      <div>
        <span class="hero-kicker"
          ><i class="pi pi-users" /> TEACHER DIRECTORY</span
        >
        <h1>รายชื่อครู</h1>
        <p>จัดการครูประจำชั้น รายวิชา และตารางสอนในหน้าเดียว</p>
      </div>
      <Button
        label="เพิ่มครู"
        icon="pi pi-plus"
        class="add-button"
        @click="addTeacher"
      />
    </section>
    <Message v-if="message" severity="error" closable @close="message = ''">{{
      message
    }}</Message
    ><Message
      v-if="successMessage"
      severity="success"
      closable
      @close="successMessage = ''"
      >{{ successMessage }}</Message
    >
    <section class="summary-grid">
      <article class="summary blue">
        <span><i class="pi pi-users" /></span>
        <div>
          <small>ครูทั้งหมด</small><b>{{ teachers.length }}</b
          ><em>คน</em>
        </div>
      </article>
      <article class="summary green">
        <span><i class="pi pi-check-circle" /></span>
        <div>
          <small>ใช้งาน</small><b>{{ activeCount }}</b
          ><em>คน</em>
        </div>
      </article>
      <article class="summary purple">
        <span><i class="pi pi-building" /></span>
        <div>
          <small>ห้องที่ดูแล</small><b>{{ assignedRoomCount }}</b
          ><em>ห้อง</em>
        </div>
      </article>
      <article class="summary gray">
        <span><i class="pi pi-pause-circle" /></span>
        <div>
          <small>พักการใช้งาน</small><b>{{ inactiveCount }}</b
          ><em>คน</em>
        </div>
      </article>
    </section>

    <Card class="registry-card"
      ><template #content>
        <div class="registry-heading">
          <div class="registry-title">
            <span><i class="pi pi-address-book" /></span>
            <div>
              <h2>ทะเบียนครู</h2>
              <p>แสดงรายวิชาแบบย่อ และพิมพ์ตารางสอนได้รายบุคคล</p>
            </div>
          </div>
          <Button
            label="รีเฟรช"
            icon="pi pi-refresh"
            outlined
            :loading="loading"
            @click="load"
          />
        </div>
        <div class="tools">
          <div class="search">
            <i class="pi pi-search" /><InputText
              v-model="search"
              placeholder="ค้นหาชื่อครู รหัส หรือวิชาที่สอน..."
            />
          </div>
          <Select
            v-model="gradeFilter"
            :options="[{ label: 'ทุกชั้นเรียน', value: 'all' }, ...gradeLevels]"
            option-label="label"
            option-value="value"
          /><Select
            v-model="roomFilter"
            :options="[{ label: 'ทุกห้อง', value: 'all' }, ...rooms]"
            option-label="label"
            option-value="value"
          /><Select
            v-model="statusFilter"
            :options="[{ label: 'ทุกสถานะ', value: 'all' }, ...statuses]"
            option-label="label"
            option-value="value"
          />
        </div>
        <DataTable
          :value="filteredTeachers"
          striped-rows
          responsive-layout="scroll"
          :loading="loading"
          empty-message="ยังไม่มีข้อมูลครู"
          class="teacher-table"
          paginator
          :rows="8"
        >
          <Column field="teacherCode" header="รหัส" />
          <Column header="ชื่อครู"
            ><template #body="{ data, index }"
              ><div class="teacher-name">
                <span :class="`avatar a${index % 4}`">{{
                  initials(data.teacherName)
                }}</span>
                <div>
                  <b>{{ data.teacherName }}</b
                  ><small>{{ data.email || "-" }}</small>
                </div>
              </div></template
            ></Column
          >
          <Column header="ประจำชั้น"
            ><template #body="{ data }"
              ><b>{{ data.gradeLevel }}/{{ data.room }}</b></template
            ></Column
          >
          <Column header="วิชาที่สอน"
            ><template #body="{ data }"
              ><div v-if="teachingSubjects(data).length" class="subject-pills">
                <span
                  v-for="s in visibleSubjects(data)"
                  :key="`${s.subjectId}-${s.gradeLevel}-${s.room}`"
                  class="subject-pill"
                  >{{ s.subjectName }}</span
                ><button
                  v-if="hiddenSubjectCount(data)"
                  type="button"
                  class="more-subject"
                  @click="showSubjects(data)"
                >
                  +{{ hiddenSubjectCount(data) }} วิชา
                </button>
              </div>
              <span v-else class="no-subject">ยังไม่มีวิชา</span></template
            ></Column
          >
          <Column header="คาบ/สัปดาห์"
            ><template #body="{ data }"
              ><b class="period-count">{{
                teacherPeriodCount(data.id)
              }}</b></template
            ></Column
          >
          <Column header="สถานะ"
            ><template #body="{ data }"
              ><Tag
                :severity="statusSeverity(data.status)"
                :value="statusLabel(data.status)" /></template
          ></Column>
          <Column header="จัดการ"
            ><template #body="{ data }"
              ><div class="row-actions">
                <Button
                  label="ตารางสอน"
                  icon="pi pi-print"
                  outlined
                  size="small"
                  @click="showSchedule(data)"
                /><Button
                  icon="pi pi-pencil"
                  outlined
                  size="small"
                  aria-label="แก้ไข"
                  @click="editTeacher(data)"
                /><Button
                  icon="pi pi-trash"
                  severity="danger"
                  text
                  size="small"
                  aria-label="ลบ"
                  @click="askDelete(data)"
                /></div></template
          ></Column>
        </DataTable> </template
    ></Card>

    <section v-if="printTeacher" class="teacher-print-sheet">
      <div class="teacher-print-logo">
        <img :src="schoolLogo" alt="ตราโรงเรียน" />
      </div>
      <header class="teacher-print-header">
        <h1>ตารางสอน{{ schoolReport.schoolName }}</h1>
        <h2>
          ภาคเรียนที่ {{ schoolReport.semester }} ปีการศึกษา
          {{ schoolReport.academicYear }}
        </h2>
        <p>
          ประจำวันที่ ............ ที่ ............ เดือน
          ........................ พ.ศ. ............
        </p>
        <div class="teacher-print-name">{{ printTeacher.teacherName }}</div>
      </header>
      <table>
        <thead>
          <tr>
            <th>วัน / คาบ</th>
            <th v-for="p in teachingPeriods" :key="p.key">
              {{ p.label }}<small>{{ p.start }}-{{ p.end }}</small>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="d in weekDays" :key="d.key">
            <th>{{ d.label }}</th>
            <td v-for="p in teachingPeriods" :key="p.key">
              <template v-if="lessonAt(printTeacher.id, d.key, p)"
                ><b>{{ lessonAt(printTeacher.id, d.key, p).subjectName }}</b
                ><span
                  >{{ lessonAt(printTeacher.id, d.key, p).gradeLevel }}/{{
                    lessonAt(printTeacher.id, d.key, p).classRoom
                  }}</span
                ></template
              >
            </td>
          </tr>
        </tbody>
      </table>
      <footer class="teacher-print-footer">
        <div class="period-total">
          รวม {{ teacherPeriodCount(printTeacher.id) }} คาบ / สัปดาห์
        </div>
        <br><br><br>
        <div class="teacher-signatures">
          <div class="signature-block">
            <p class="signature-line">
              ลงชื่อ............................................................
            </p>
            <p>({{ printTeacher.teacherName }})</p>
            <p>ครูผู้สอน</p>
          </div>
          <div class="signature-block">
            <p class="signature-line">
              ลงชื่อ............................................................
            </p>
            <p>({{ schoolReport.academicHeadName }})</p>
            <p>{{ schoolReport.academicHeadTitle }}</p>
          </div>
          <div class="signature-block">
            <p class="signature-line">
              ลงชื่อ............................................................
            </p>
            <p>({{ schoolReport.directorName }})</p>
            <p>{{ schoolReport.directorTitle }}</p>
            <!-- <p>{{ schoolReport.schoolName }}</p> -->
          </div>
        </div>
      </footer>
    </section>

    <Dialog
      v-model:visible="subjectsVisible"
      modal
      :header="`วิชาที่สอน • ${selectedTeacher?.teacherName || ''}`"
      :style="{ width: 'min(34rem,94vw)' }"
      ><div class="subject-list">
        <div
          v-for="s in teachingSubjects(selectedTeacher || {})"
          :key="`${s.subjectId}-${s.gradeLevel}-${s.room}`"
        >
          <i class="pi pi-book" /><b>{{ s.subjectName }}</b
          ><span>{{ s.gradeLevel }} / ห้อง {{ s.room }}</span>
        </div>
      </div></Dialog
    >
    <Dialog
      v-model:visible="scheduleVisible"
      modal
      :show-header="false"
      :style="{ width: 'min(64rem,94vw)' }"
      :content-style="{ padding: '0' }"
    >
      <div v-if="selectedTeacher" class="pretty-schedule-dialog">
        <div class="pretty-dialog-header">
          <div class="dialog-title-icon"><i class="pi pi-calendar" /></div>
          <div class="dialog-title-text">
            <h2>ตารางสอนรายครู</h2>
            <p>ตรวจสอบรายวิชาและพิมพ์ตารางสอน</p>
          </div>
          <button
            type="button"
            class="dialog-close"
            aria-label="ปิด"
            @click="scheduleVisible = false"
          >
            <i class="pi pi-times" />
          </button>
        </div>
        <div class="pretty-teacher-card">
          <div class="pretty-avatar">
            {{ initials(selectedTeacher.teacherName) }}
          </div>
          <div class="pretty-teacher-info">
            <b>{{ selectedTeacher.teacherName }}</b
            ><span
              >{{ selectedTeacher.teacherCode }} • ประจำชั้น
              {{ selectedTeacher.gradeLevel }}/{{ selectedTeacher.room }}</span
            >
          </div>
          <span class="period-badge"
            >{{ teacherPeriodCount(selectedTeacher.id) }} คาบ / สัปดาห์</span
          >
        </div>
        <div class="pretty-table-wrap">
          <div class="pretty-schedule-grid">
            <div class="pretty-head first">วัน / คาบ</div>
            <div v-for="p in teachingPeriods" :key="p.key" class="pretty-head">
              <b>{{ p.label }}</b
              ><small>{{ p.start }}-{{ p.end }}</small>
            </div>
            <template v-for="d in weekDays" :key="d.key">
              <div class="pretty-day">
                <span :class="`day-dot day-dot-${d.key}`"></span>{{ d.label }}
              </div>
              <div
                v-for="p in teachingPeriods"
                :key="`${d.key}-${p.key}`"
                class="pretty-cell"
              >
                <div
                  v-if="lessonAt(selectedTeacher.id, d.key, p)"
                  class="pretty-lesson"
                  :class="`tone-${lessonTone(lessonAt(selectedTeacher.id, d.key, p))}`"
                >
                  <b>{{ lessonAt(selectedTeacher.id, d.key, p).subjectName }}</b
                  ><span
                    >{{ lessonAt(selectedTeacher.id, d.key, p).gradeLevel }}/{{
                      lessonAt(selectedTeacher.id, d.key, p).classRoom
                    }}</span
                  >
                </div>
                <span v-else class="pretty-empty">-</span>
              </div>
            </template>
          </div>
        </div>
        <div class="pretty-dialog-footer">
          <div class="subject-legend">
            <span><i class="legend-dot blue"></i>วิทยาศาสตร์</span
            ><span><i class="legend-dot green"></i>การงานอาชีพ</span>
          </div>
          <div class="footer-actions">
            <Button
              type="button"
              label="ปิด"
              severity="secondary"
              outlined
              @click="scheduleVisible = false"
            /><Button
              label="พิมพ์ / PDF"
              icon="pi pi-print"
              severity="success"
              @click="printTeacherSchedule(selectedTeacher)"
            />
          </div>
        </div>
      </div>
    </Dialog>

    <Dialog
      v-model:visible="editorVisible"
      modal
      :header="editId ? 'แก้ไขข้อมูลครู' : 'เพิ่มครู'"
      :style="{ width: 'min(36rem,94vw)' }"
      ><form class="teacher-form" @submit.prevent="saveTeacher">
        <label
          ><span>รหัสครู *</span>
          <div class="code-field">
            <InputText v-model="form.teacherCode" maxlength="20" fluid /><Button
              type="button"
              label="สร้างรหัส"
              icon="pi pi-sparkles"
              outlined
              @click="form.teacherCode = generateTeacherCode()"
            /></div></label
        ><label
          ><span>ชื่อ - นามสกุล *</span
          ><InputText v-model="form.teacherName" maxlength="120" fluid
        /></label>
        <div class="form-grid">
          <label
            ><span>ชั้นเรียน *</span
            ><Select
              v-model="form.gradeLevel"
              :options="gradeLevels"
              option-label="label"
              option-value="value"
              fluid /></label
          ><label
            ><span>ห้อง *</span
            ><Select
              v-model="form.room"
              :options="rooms"
              option-label="label"
              option-value="value"
              fluid
          /></label>
        </div>
        <div class="form-grid">
          <label
            ><span>โทรศัพท์</span
            ><InputText v-model="form.phone" fluid /></label
          ><label
            ><span>อีเมล</span
            ><InputText v-model="form.email" type="email" fluid
          /></label>
        </div>
        <label
          ><span>สถานะ</span
          ><Select
            v-model="form.status"
            :options="statuses"
            option-label="label"
            option-value="value"
            fluid
        /></label>
        <div class="dialog-actions">
          <Button
            type="button"
            label="ยกเลิก"
            text
            @click="editorVisible = false"
          /><Button
            type="submit"
            label="บันทึก"
            icon="pi pi-save"
            :loading="saving"
          />
        </div></form
    ></Dialog>
    <Dialog
      v-model:visible="deleteVisible"
      modal
      header="ยืนยันการลบ"
      :style="{ width: 'min(28rem,92vw)' }"
      ><div class="delete-confirm">
        <i class="pi pi-exclamation-triangle" />
        <div>
          <b>ลบ {{ deleteTarget?.teacherName }} ?</b>
          <p>ถ้ายังมีตารางสอน แนะนำเปลี่ยนเป็น “พักการใช้งาน” แทนการลบ</p>
        </div>
      </div>
      <div class="dialog-actions">
        <Button label="ยกเลิก" text @click="deleteVisible = false" /><Button
          label="ลบ"
          icon="pi pi-trash"
          severity="danger"
          :loading="deleting"
          @click="deleteTeacher"
        /></div
    ></Dialog>
  </div>
</template>

<style scoped>
.homeroom-page {
  --navy: #102b52;
  --blue: #167df5;
  --line: #dce7f2;
  --muted: #71839d;
  display: grid;
  gap: 16px;
}
.hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 22px 26px;
  border: 1px solid var(--line);
  border-radius: 20px;
  background: linear-gradient(110deg, #fff, #f1f8ff 60%, #effbf6);
  box-shadow: 0 12px 30px rgba(24, 57, 94, 0.06);
}
.hero-kicker {
  display: inline-flex;
  gap: 7px;
  padding: 6px 10px;
  border-radius: 999px;
  background: #e7f2ff;
  color: var(--blue);
  font-size: 9px;
  font-weight: 800;
}
.hero h1 {
  margin: 10px 0 3px;
  color: var(--navy);
  font-size: 30px;
}
.hero p {
  margin: 0;
  color: var(--muted);
}
.add-button {
  min-width: 150px;
}
.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 11px;
}
.summary {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 15px 17px;
  border: 1px solid #e1eaf3;
  border-radius: 15px;
  background: #fff;
  box-shadow: 0 7px 20px rgba(24, 57, 94, 0.04);
}
.summary > span {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  font-size: 19px;
}
.summary small,
.summary b,
.summary em {
  display: block;
}
.summary small {
  color: #425d79;
  font-size: 10px;
  font-weight: 700;
}
.summary b {
  color: var(--navy);
  font-size: 25px;
}
.summary em {
  color: var(--muted);
  font-size: 9px;
  font-style: normal;
}
.blue > span {
  color: #167df5;
  background: #e1efff;
}
.green > span {
  color: #0ca575;
  background: #ddf8ed;
}
.purple > span {
  color: #7c4dff;
  background: #eee7ff;
}
.gray > span {
  color: #536a83;
  background: #e9eef4;
}
.registry-card {
  border: 1px solid var(--line);
  border-radius: 18px;
  box-shadow: 0 10px 26px rgba(24, 57, 94, 0.05);
  overflow: hidden;
}
.registry-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 15px;
}
.registry-title {
  display: flex;
  align-items: center;
  gap: 11px;
}
.registry-title > span {
  width: 44px;
  height: 44px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: #e8f3ff;
  color: #167df5;
}
.registry-title h2 {
  margin: 0;
  color: var(--navy);
  font-size: 19px;
}
.registry-title p {
  margin: 2px 0 0;
  color: var(--muted);
  font-size: 10px;
}
.tools {
  display: grid;
  grid-template-columns: minmax(280px, 1fr) 170px 140px 165px;
  gap: 8px;
  margin-bottom: 12px;
}
.search {
  position: relative;
}
.search > i {
  position: absolute;
  left: 13px;
  top: 50%;
  transform: translateY(-50%);
  z-index: 2;
  color: #68809a;
}
.search :deep(.p-inputtext) {
  width: 100%;
  padding-left: 38px;
}
.teacher-table {
  border: 1px solid var(--line);
  border-radius: 11px;
  overflow: hidden;
}
.teacher-table :deep(.p-datatable-thead > tr > th) {
  padding: 11px;
  background: #eef4f9;
  color: #344f6d;
  font-size: 10px;
}
.teacher-table :deep(.p-datatable-tbody > tr > td) {
  padding: 10px 11px;
  vertical-align: middle;
}
.teacher-name {
  display: flex;
  align-items: center;
  gap: 9px;
}
.teacher-name b,
.teacher-name small {
  display: block;
}
.teacher-name small {
  color: var(--muted);
  font-size: 8px;
}
.avatar {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  font-weight: 800;
}
.a0 {
  color: #167df5;
  background: #dcecff;
}
.a1 {
  color: #c03478;
  background: #f9dcef;
}
.a2 {
  color: #0b9f73;
  background: #d8f6eb;
}
.a3 {
  color: #7548d6;
  background: #ece3ff;
}
.subject-pills {
  display: flex;
  align-items: center;
  gap: 5px;
  flex-wrap: wrap;
  max-width: 260px;
}
.subject-pill {
  padding: 4px 7px;
  border-radius: 6px;
  background: #eef6ff;
  color: #315e90;
  font-size: 9px;
}
.subject-pill:nth-child(2) {
  background: #e7f8ef;
  color: #287354;
}
.more-subject {
  border: 0;
  background: #e8f2ff;
  color: #2674c8;
  border-radius: 6px;
  padding: 4px 7px;
  font-size: 9px;
  cursor: pointer;
}
.no-subject {
  color: #9aa8ba;
  font-size: 9px;
}
.period-count {
  color: #294766;
}
.row-actions {
  display: flex;
  gap: 4px;
  white-space: nowrap;
}
.schedule-preview {
  padding: 16px;
  border: 1px solid #dce7f2;
  border-radius: 18px;
  background: #fff;
  box-shadow: 0 10px 28px rgba(24, 57, 94, 0.05);
}
.preview-head,
.preview-head > div {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.preview-head > div > span {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 11px;
  background: #e6f2ff;
  color: #167df5;
}
.preview-head h2 {
  margin: 0;
  color: #102b52;
  font-size: 18px;
}
.preview-head p {
  margin: 2px 0 0;
  color: #71839d;
  font-size: 10px;
}
.schedule-grid {
  display: grid;
  grid-template-columns: 80px repeat(6, minmax(100px, 1fr));
  margin-top: 13px;
  border-left: 1px solid #dce7f2;
  border-top: 1px solid #dce7f2;
}
.grid-head,
.day-cell,
.schedule-cell {
  min-height: 65px;
  border-right: 1px solid #dce7f2;
  border-bottom: 1px solid #dce7f2;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 5px;
}
.grid-head {
  min-height: 48px;
  flex-direction: column;
  background: #f6f9fc;
  color: #334f6e;
}
.grid-head small {
  font-size: 8px;
}
.day-cell {
  font-weight: 800;
  color: #294766;
  background: #fbfcfe;
}
.mini-lesson {
  width: 100%;
  padding: 6px;
  border-radius: 7px;
  background: #e9f3ff;
}
.mini-lesson b,
.mini-lesson span {
  display: block;
}
.mini-lesson b {
  font-size: 10px;
  color: #245d9b;
}
.mini-lesson span {
  font-size: 8px;
  color: #59728d;
}
.empty {
  color: #b0bcc8;
}
.teacher-print-sheet {
  display: none;
}
.subject-list {
  display: grid;
  gap: 8px;
}
.subject-list > div {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 9px;
  padding: 10px;
  border: 1px solid #e1eaf3;
  border-radius: 9px;
}
.subject-list i {
  color: #7c4dff;
}
.subject-list span {
  color: #71839d;
  font-size: 10px;
}
.teacher-form {
  display: grid;
  gap: 14px;
}
.teacher-form label {
  display: grid;
  gap: 6px;
}
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.code-field {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 8px;
}
.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 7px;
  margin-top: 10px;
}
.delete-confirm {
  display: flex;
  gap: 12px;
}
.delete-confirm > i {
  width: 44px;
  height: 44px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: #ffeded;
  color: #dc3545;
}
.delete-confirm p {
  color: #71839d;
  font-size: 10px;
}
.schedule-teacher-info {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
  padding: 12px 14px;
  border: 1px solid #dce7f2;
  border-radius: 10px;
  background: #f7fbff;
}
.schedule-teacher-info b,
.schedule-teacher-info span {
  display: block;
}
.schedule-teacher-info b {
  color: #102b52;
  font-size: 15px;
}
.schedule-teacher-info span {
  margin-top: 3px;
  color: #71839d;
  font-size: 10px;
}
.dialog-schedule-scroll {
  width: 100%;
  overflow-x: auto;
}
.dialog-schedule .schedule-grid {
  min-width: 850px;
  margin-top: 0;
}
.schedule-dialog-actions {
  margin-top: 15px;
}
.dialog-schedule .schedule-grid {
  grid-template-columns: 65px repeat(6, minmax(85px, 1fr));
  min-width: 720px;
  margin-top: 0;
}
.dialog-schedule .grid-head {
  min-height: 34px !important;
  height: 34px;
  padding: 2px 4px;
}
.dialog-schedule .day-cell,
.dialog-schedule .schedule-cell {
  min-height: 44px !important;
  height: 44px;
  padding: 3px;
}
.dialog-schedule .grid-head b {
  font-size: 10px;
}
.dialog-schedule .grid-head small {
  font-size: 7px;
}
.dialog-schedule .day-cell {
  font-size: 11px;
}
.dialog-schedule .mini-lesson {
  padding: 3px 5px;
}
.dialog-schedule .mini-lesson b {
  font-size: 9px;
  line-height: 1.1;
}
.dialog-schedule .mini-lesson span {
  margin-top: 1px;
  font-size: 7px;
}
.dialog-schedule .empty {
  font-size: 9px;
}
.dialog-schedule-scroll {
  width: 100%;
  max-height: 300px;
  overflow: auto;
}
.dialog-schedule {
  --grid-line: #dce7f2;
  --head-bg: #f1f6fb;
  --day-bg: #f8fbfe;
}
.schedule-teacher-info {
  border-color: #d9e7f4;
  background: linear-gradient(90deg, #f7fbff, #f3f9ff);
  box-shadow: 0 3px 12px rgba(29, 68, 108, 0.04);
}
.dialog-schedule-scroll {
  border: 1px solid var(--grid-line);
  border-radius: 12px;
  overflow: auto;
  background: #fff;
}
.dialog-schedule .schedule-grid {
  grid-template-columns: 76px repeat(6, minmax(92px, 1fr));
  min-width: 760px;
  margin: 0;
  border: 0;
}
.dialog-schedule .grid-head,
.dialog-schedule .day-cell,
.dialog-schedule .schedule-cell {
  border-right: 1px solid var(--grid-line);
  border-bottom: 1px solid var(--grid-line);
}
.dialog-schedule .grid-head:nth-child(7) {
  border-right: 0;
}
.dialog-schedule .grid-head {
  min-height: 42px !important;
  height: 42px;
  padding: 4px;
  background: var(--head-bg);
  color: #284868;
}
.dialog-schedule .grid-head:first-child {
  font-weight: 800;
  font-size: 11px;
}
.dialog-schedule .grid-head b {
  font-size: 10px;
}
.dialog-schedule .grid-head small {
  margin-top: 2px;
  color: #8294a7;
  font-size: 7px;
}
.dialog-schedule .day-cell {
  min-height: 46px !important;
  height: 46px;
  padding: 4px;
  background: var(--day-bg);
  color: #274664;
  font-size: 11px;
  font-weight: 800;
}
.dialog-schedule .schedule-cell {
  min-height: 46px !important;
  height: 46px;
  padding: 4px;
  background: #fff;
}
.dialog-schedule .schedule-cell:nth-child(7n) {
  border-right: 0;
}
.dialog-schedule .mini-lesson {
  width: 100%;
  min-height: 34px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 4px 6px;
  border: 1px solid #cfe2f7;
  border-radius: 8px;
  background: linear-gradient(135deg, #eaf4ff, #e2f0ff);
  box-shadow: 0 2px 5px rgba(49, 94, 145, 0.05);
}
.dialog-schedule .mini-lesson b {
  color: #16558f;
  font-size: 9px;
  line-height: 1.15;
}
.dialog-schedule .mini-lesson span {
  margin-top: 2px;
  color: #597793;
  font-size: 7px;
  line-height: 1;
}
.dialog-schedule .empty {
  color: #c4cfda;
  font-size: 9px;
}
.schedule-dialog-actions {
  padding-top: 12px;
  border-top: 1px solid #edf2f7;
}
.dialog-schedule-scroll::-webkit-scrollbar {
  width: 7px;
  height: 7px;
}
.dialog-schedule-scroll::-webkit-scrollbar-thumb {
  border-radius: 99px;
  background: #c8d4e0;
}
.dialog-schedule-scroll::-webkit-scrollbar-track {
  background: #f5f8fb;
}
.pretty-schedule-dialog {
  padding: 20px 22px 18px;
  background: #fff;
  border-radius: 18px;
  --grid: #d9e4ef;
}
.pretty-dialog-header {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
}
.dialog-title-icon {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  border-radius: 13px;
  background: #e8f3ff;
  color: #167df5;
  font-size: 20px;
}
.dialog-title-text h2,
.dialog-title-text p {
  margin: 0;
}
.dialog-title-text h2 {
  color: #102b52;
  font-size: 21px;
}
.dialog-title-text p {
  margin-top: 2px;
  color: #71839d;
  font-size: 11px;
}
.dialog-close {
  width: 38px;
  height: 38px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: transparent;
  color: #60778f;
  font-size: 16px;
  cursor: pointer;
}
.dialog-close:hover {
  background: #f2f6fa;
}
.pretty-teacher-card {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
  padding: 12px 16px;
  border: 1px solid #d7e6f5;
  border-radius: 12px;
  background: linear-gradient(100deg, #f5faff, #eef7ff);
}
.pretty-avatar {
  width: 44px;
  height: 44px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: #dcecff;
  color: #167df5;
  font-size: 16px;
  font-weight: 800;
}
.pretty-teacher-info b,
.pretty-teacher-info span {
  display: block;
}
.pretty-teacher-info b {
  color: #183b61;
  font-size: 14px;
}
.pretty-teacher-info span {
  margin-top: 2px;
  color: #6c8198;
  font-size: 10px;
}
.period-badge {
  padding: 6px 10px;
  border-radius: 9px;
  background: #e5f2ff;
  color: #27669f;
  font-size: 10px;
  font-weight: 800;
}
.pretty-table-wrap {
  overflow: auto;
  border: 1px solid var(--grid);
  border-radius: 12px;
  background: #fff;
}
.pretty-schedule-grid {
  display: grid;
  grid-template-columns: 92px repeat(6, minmax(118px, 1fr));
  min-width: 800px;
}
.pretty-head,
.pretty-day,
.pretty-cell {
  border-right: 1px solid var(--grid);
  border-bottom: 1px solid var(--grid);
}
.pretty-head {
  height: 50px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: #f1f6fb;
  color: #294967;
}
.pretty-head b {
  font-size: 11px;
}
.pretty-head small {
  margin-top: 2px;
  color: #7b90a5;
  font-size: 8px;
}
.pretty-head.first {
  font-size: 12px;
  font-weight: 800;
}
.pretty-day {
  height: 62px;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 0 14px;
  background: #fbfdff;
  color: #294967;
  font-size: 11px;
  font-weight: 800;
}
.day-dot {
  width: 11px;
  height: 11px;
  border-radius: 50%;
  flex: 0 0 11px;
}
.day-dot-1 {
  background: #ffd62e;
}
.day-dot-2 {
  background: #f58eb2;
}
.day-dot-3 {
  background: #27b86d;
}
.day-dot-4 {
  background: #ff9538;
}
.day-dot-5 {
  background: #2b86e5;
}
.pretty-cell {
  height: 62px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 5px;
  background: #fff;
}
.pretty-empty {
  color: #c1ccd7;
  font-size: 10px;
}
.pretty-lesson {
  position: relative;
  width: 100%;
  min-height: 44px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 5px 7px 5px 10px;
  border: 1px solid #d6e6f6;
  border-radius: 8px;
  background: #eaf4ff;
  overflow: hidden;
}
.pretty-lesson::before {
  content: "";
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 4px;
  background: #2a85ea;
}
.pretty-lesson b {
  color: #174f87;
  font-size: 10px;
  line-height: 1.1;
}
.pretty-lesson span {
  margin-top: 2px;
  color: #68819a;
  font-size: 8px;
}
.pretty-lesson.tone-work {
  border-color: #d3efdf;
  background: #e9f9f0;
}
.pretty-lesson.tone-work::before {
  background: #16ad58;
}
.pretty-lesson.tone-work b {
  color: #21714a;
}
.pretty-lesson.tone-thai {
  border-color: #f1dcec;
  background: #fff0fa;
}
.pretty-lesson.tone-thai::before {
  background: #d45d9d;
}
.pretty-lesson.tone-thai b {
  color: #8a3767;
}
.pretty-lesson.tone-math {
  border-color: #eadffb;
  background: #f6efff;
}
.pretty-lesson.tone-math::before {
  background: #8d62df;
}
.pretty-lesson.tone-math b {
  color: #654398;
}
.pretty-dialog-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding-top: 14px;
}
.subject-legend {
  display: flex;
  gap: 18px;
  color: #506b85;
  font-size: 10px;
}
.subject-legend span {
  display: flex;
  align-items: center;
  gap: 6px;
}
.legend-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
}
.legend-dot.blue {
  background: #2a85ea;
}
.legend-dot.green {
  background: #16ad58;
}
.footer-actions {
  display: flex;
  gap: 8px;
}
.pretty-table-wrap::-webkit-scrollbar {
  width: 7px;
  height: 7px;
}
.pretty-table-wrap::-webkit-scrollbar-thumb {
  border-radius: 99px;
  background: #c8d4e0;
}
.pretty-table-wrap::-webkit-scrollbar-track {
  background: #f5f8fb;
}
@media (max-width: 1050px) {
  .summary-grid {
    grid-template-columns: 1fr 1fr;
  }
  .tools {
    grid-template-columns: 1fr 1fr;
  }
  .search {
    grid-column: 1/-1;
  }
  .schedule-preview {
    overflow: auto;
  }
  .schedule-grid {
    min-width: 850px;
  }
}
@media (max-width: 700px) {
  .hero {
    align-items: flex-start;
    flex-direction: column;
  }
  .add-button {
    width: 100%;
  }
  .summary-grid {
    grid-template-columns: 1fr 1fr;
  }
  .tools {
    grid-template-columns: 1fr;
  }
  .search {
    grid-column: auto;
  }
  .form-grid,
  .code-field {
    grid-template-columns: 1fr;
  }
  .row-actions {
    flex-direction: column;
  }
}
</style>

<style>
@page {
  size: A4 landscape;
  margin: 8mm;
}
@media print {
  body.teacher-schedule-printing .sidebar,
  body.teacher-schedule-printing .topbar {
    display: none !important;
  }
  body.teacher-schedule-printing .main,
  body.teacher-schedule-printing .content {
    display: block !important;
    width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
  }
  body.teacher-schedule-printing .homeroom-page > * {
    display: none !important;
  }
  body.teacher-schedule-printing .teacher-print-sheet {
    display: block !important;
    width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
    color: #000;
    font-family: "TH Sarabun New", "Sarabun", Tahoma, sans-serif !important;
  }
  .teacher-print-logo {
    display: flex !important;
    align-items: center;
    justify-content: center;
    height: 12mm;
    margin-bottom: 0.5mm;
  }
  .teacher-print-logo img {
    display: block !important;
    width: 11mm !important;
    height: 11mm !important;
    object-fit: contain;
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }
  .teacher-print-header {
    text-align: center;
    margin-bottom: 2mm;
  }
  .teacher-print-header h1 {
    margin: 0 !important;
    font-size: 18px !important;
    font-weight: 700 !important;
    line-height: 1.1 !important;
  }
  .teacher-print-header h2 {
    margin: 0.5mm 0 !important;
    font-size: 16px !important;
    font-weight: 700 !important;
    line-height: 1.1 !important;
  }
  .teacher-print-header > p {
    margin: 0.5mm 0 !important;
    font-size: 14px !important;
    line-height: 1.1 !important;
  }
  .teacher-print-name {
    margin-top: 1.5mm;
    font-size: 16px !important;
    font-weight: 700 !important;
  }
  .teacher-print-sheet table {
    width: 100%;
    table-layout: fixed;
    border-collapse: collapse;
  }
  .teacher-print-sheet th,
  .teacher-print-sheet td {
    height: 11mm;
    padding: 0.7mm;
    border: 1px solid #000;
    font-size: 15px !important;
    text-align: center;
    vertical-align: middle;
  }
  .teacher-print-sheet thead th {
    height: 7mm;
    background: #f7cfad !important;
    font-weight: 700;
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }
  .teacher-print-sheet th:first-child {
    width: 22mm;
  }
  .teacher-print-sheet th small,
  .teacher-print-sheet td b,
  .teacher-print-sheet td span {
    display: block;
  }
  .teacher-print-sheet th small {
    margin-top: 1mm;
    font-size: 10px !important;
    font-weight: 400;
  }
  .teacher-print-sheet td b {
    font-size: 14px !important;
    line-height: 1 !important;
  }
  .teacher-print-sheet td span {
    margin-top: 0.3mm;
    font-size: 11px !important;
    line-height: 1 !important;
  }
  .teacher-print-footer {
    margin-top: 2mm;
  }
  .period-total {
    margin-bottom: 3mm;
    font-size: 14px !important;
    font-weight: 700;
    text-align: right;
  }
  .teacher-signatures {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8mm;
    width: 100%;
    break-inside: avoid;
    page-break-inside: avoid;
    text-align: center;
  }
  .signature-block {
    min-width: 0;
  }
  .teacher-signatures p {
    margin: 0 0 0.7mm;
    font-size: 14px !important;
    line-height: 1 !important;
  }
  .signature-line {
    margin-bottom: 1.5mm !important;
    white-space: nowrap;
  }
  body.teacher-schedule-printing .preview-head,
  body.teacher-schedule-printing .p-button,
  body.teacher-schedule-printing button,
  body.teacher-schedule-printing .p-dialog,
  body.teacher-schedule-printing .p-dialog-mask {
    display: none !important;
  }
}
</style>
