<script setup>
import { computed, onMounted, ref } from "vue";
import Button from "primevue/button";
import Card from "primevue/card";
import Column from "primevue/column";
import DataTable from "primevue/datatable";
import Dialog from "primevue/dialog";
import InputNumber from "primevue/inputnumber";
import InputText from "primevue/inputtext";
import Message from "primevue/message";
import Tag from "primevue/tag";
import Select from "primevue/select";
import { rpc } from "../../services/supabase";

const students = ref([]);
const homeroomTeachers = ref([]);
const loading = ref(false);
const saving = ref(false);
const deleting = ref(false);
const message = ref("");
const successMessage = ref("");
const search = ref("");
const gradeFilter = ref("all");
const roomFilter = ref("all");
const statusFilter = ref("all");
const editorVisible = ref(false);
const deleteVisible = ref(false);
const editId = ref(null);
const deleteTarget = ref(null);
const gradeLevels = [
  { label: "ป.1", value: "ป.1" },
  { label: "ป.2", value: "ป.2" },
  { label: "ป.3", value: "ป.3" },
  { label: "ป.4", value: "ป.4" },
  { label: "ป.5", value: "ป.5" },
  { label: "ป.6", value: "ป.6" },
  { label: "ม.1", value: "ม.1" },
  { label: "ม.2", value: "ม.2" },
  { label: "ม.3", value: "ม.3" },
];
const rooms = [1, 2, 3, 4, 5, 6].map((value) => ({
  label: `ห้อง ${value}`,
  value: String(value),
}));
const statusOptions = [
  { label: "กำลังศึกษา", value: "active" },
  { label: "ย้ายออก", value: "moved" },
  { label: "จบการศึกษา", value: "graduated" },
];
const form = ref(emptyForm());

function emptyForm() {
  return {
    studentCode: "",
    studentName: "",
    gradeLevel: "ป.1",
    room: "1",
    numberInRoom: 1,
    homeroomTeacherId: null,
    status: "active",
  };
}

const filteredStudents = computed(() => {
  const term = search.value.trim().toLowerCase();
  return students.value.filter((row) => {
    const matchesSearch =
      !term ||
      String(row.studentCode || "")
        .toLowerCase()
        .includes(term) ||
      String(row.studentName || "")
        .toLowerCase()
        .includes(term) ||
      teacherNameById(row.homeroomTeacherId).toLowerCase().includes(term);
    const matchesGrade =
      gradeFilter.value === "all" || row.gradeLevel === gradeFilter.value;
    const matchesRoom =
      roomFilter.value === "all" ||
      String(row.room) === String(roomFilter.value);
    const matchesStatus =
      statusFilter.value === "all" || row.status === statusFilter.value;
    return matchesSearch && matchesGrade && matchesRoom && matchesStatus;
  });
});
const availableHomeroomTeachers = computed(() => {
  return homeroomTeachers.value
    .filter((teacher) => teacher.status === "active")
    .filter(
      (teacher) =>
        teacher.gradeLevel === form.value.gradeLevel &&
        String(teacher.room) === String(form.value.room),
    )
    .map((teacher) => ({
      label: `${teacher.teacherName} (${teacher.teacherCode})`,
      value: teacher.id,
    }));
});

const homeroomTeacherMap = computed(() => {
  return new Map(
    homeroomTeachers.value.map((teacher) => [teacher.id, teacher]),
  );
});

function teacherNameById(id) {
  return homeroomTeacherMap.value.get(id)?.teacherName || "-";
}

function syncTeacherForRoom() {
  const options = availableHomeroomTeachers.value;
  const stillValid = options.some(
    (option) => option.value === form.value.homeroomTeacherId,
  );
  if (!stillValid)
    form.value.homeroomTeacherId =
      options.length === 1 ? options[0].value : null;
}

const activeCount = computed(
  () => students.value.filter((s) => s.status === "active").length,
);
const inactiveCount = computed(() => students.value.length - activeCount.value);
const gradeOptions = computed(() =>
  [...new Set(students.value.map((s) => s.gradeLevel).filter(Boolean))].sort(),
);
const roomOptions = computed(() =>
  [
    ...new Set(students.value.map((s) => String(s.room)).filter(Boolean)),
  ].sort(),
);
const roomCount = computed(
  () =>
    new Set(
      students.value
        .filter((s) => s.gradeLevel && s.room)
        .map((s) => `${s.gradeLevel}/${s.room}`),
    ).size,
);

function statusLabel(status) {
  return (
    { active: "กำลังศึกษา", moved: "ย้ายออก", graduated: "จบการศึกษา" }[
      status
    ] || status
  );
}
function statusSeverity(status) {
  return status === "active" ? "success" : "secondary";
}
function initials(name) {
  return (
    String(name || "?")
      .trim()
      .charAt(0) || "?"
  );
}

async function load() {
  loading.value = true;
  message.value = "";
  try {
    const [studentRows, teacherRows] = await Promise.all([
      rpc("teacher_students_list"),
      rpc("teacher_homeroom_list"),
    ]);
    students.value = studentRows || [];
    homeroomTeachers.value = teacherRows || [];
  } catch (error) {
    message.value = error.message || "ไม่สามารถโหลดรายชื่อนักเรียนได้";
  } finally {
    loading.value = false;
  }
}

function generateStudentCode() {
  const year = String(new Date().getFullYear() + 543).slice(-2);
  const used = new Set(
    students.value.map((row) => String(row.studentCode || "")),
  );
  let maxSeq = 0;
  for (const code of used) {
    if (code.startsWith(year) && /^\d{5}$/.test(code))
      maxSeq = Math.max(maxSeq, Number(code.slice(2)));
  }
  let seq = maxSeq + 1;
  let code = `${year}${String(seq).padStart(3, "0")}`;
  while (used.has(code)) {
    seq += 1;
    code = `${year}${String(seq).padStart(3, "0")}`;
  }
  return code;
}

function addStudent() {
  editId.value = null;
  form.value = emptyForm();
  form.value.studentCode = generateStudentCode();
  editorVisible.value = true;
}

function editStudent(row) {
  editId.value = row.id;
  form.value = {
    studentCode: row.studentCode || "",
    studentName: row.studentName || "",
    gradeLevel: row.gradeLevel || "ป.1",
    room: String(row.room || "1"),
    numberInRoom: Number(row.numberInRoom || 1),
    homeroomTeacherId: row.homeroomTeacherId || null,
    status: row.status || "active",
  };
  editorVisible.value = true;
}

async function saveStudent() {
  const payload = {
    id: editId.value,
    studentCode: form.value.studentCode.trim(),
    studentName: form.value.studentName.trim(),
    gradeLevel: form.value.gradeLevel.trim(),
    room: form.value.room.trim(),
    numberInRoom: Number(form.value.numberInRoom || 1),
    homeroomTeacherId: form.value.homeroomTeacherId,
    status: form.value.status,
  };
  if (!payload.studentCode) return (message.value = "กรุณากรอกรหัสนักเรียน");
  if (!payload.studentName) return (message.value = "กรุณากรอกชื่อ - นามสกุล");
  if (!payload.gradeLevel || !payload.room)
    return (message.value = "กรุณาระบุชั้นเรียนและห้อง");

  saving.value = true;
  message.value = "";
  successMessage.value = "";
  try {
    await rpc("teacher_student_save", { p_payload: payload });
    editorVisible.value = false;
    successMessage.value = editId.value
      ? "แก้ไขข้อมูลนักเรียนเรียบร้อยแล้ว"
      : "เพิ่มนักเรียนเรียบร้อยแล้ว";
    await load();
  } catch (error) {
    message.value = error.message || "ไม่สามารถบันทึกข้อมูลนักเรียนได้";
  } finally {
    saving.value = false;
  }
}

function askDelete(row) {
  deleteTarget.value = row;
  deleteVisible.value = true;
}
async function deleteStudent() {
  if (!deleteTarget.value?.id) return;
  deleting.value = true;
  message.value = "";
  successMessage.value = "";
  try {
    await rpc("teacher_student_delete", {
      p_student_id: deleteTarget.value.id,
    });
    deleteVisible.value = false;
    successMessage.value = "ลบนักเรียนเรียบร้อยแล้ว";
    await load();
  } catch (error) {
    message.value = error.message || "ไม่สามารถลบนักเรียนได้";
  } finally {
    deleting.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="students-page">
    <section class="students-hero">
      <div>
        <span class="hero-kicker"
          ><i class="pi pi-users"></i> STUDENT MANAGEMENT</span
        >
        <h1>รายชื่อนักเรียน</h1>
        <p>จัดการทะเบียนนักเรียน ชั้นเรียน ห้องเรียน และสถานะการศึกษา</p>
      </div>
      <div class="hero-side">
        <div class="hero-art">
          <span class="book b1"></span><span class="book b2"></span
          ><span class="profile-sheet"
            ><i class="pi pi-user"></i><b></b><b></b><b></b></span
          ><span class="leaf l1"></span><span class="leaf l2"></span>
        </div>
        <Button
          label="เพิ่มนักเรียน"
          icon="pi pi-plus"
          class="add-button"
          @click="addStudent"
        />
      </div>
    </section>

    <Message v-if="message" severity="error" closable @close="message = ''">{{
      message
    }}</Message>
    <Message
      v-if="successMessage"
      severity="success"
      closable
      @close="successMessage = ''"
      >{{ successMessage }}</Message
    >

    <section class="summary-grid">
      <article class="summary-card blue">
        <span><i class="pi pi-users"></i></span>
        <div>
          <small>นักเรียนทั้งหมด</small><b>{{ students.length }}</b
          ><em>คน</em>
        </div>
      </article>
      <article class="summary-card green">
        <span><i class="pi pi-graduation-cap"></i></span>
        <div>
          <small>กำลังศึกษา</small><b>{{ activeCount }}</b
          ><em>คน</em>
        </div>
      </article>
      <article class="summary-card purple">
        <span><i class="pi pi-building"></i></span>
        <div>
          <small>ห้องเรียน</small><b>{{ roomCount }}</b
          ><em>ห้อง</em>
        </div>
      </article>
      <article class="summary-card orange">
        <span><i class="pi pi-user-minus"></i></span>
        <div>
          <small>ย้ายออก / จบการศึกษา</small><b>{{ inactiveCount }}</b
          ><em>คน</em>
        </div>
      </article>
    </section>

    <Card class="registry-card">
      <template #content>
        <div class="registry-heading">
          <div class="registry-title">
            <span><i class="pi pi-id-card"></i></span>
            <div>
              <h2>ทะเบียนนักเรียน</h2>
              <p>ข้อมูลทะเบียนหลัก แยกจากประวัติการเช็คชื่อ</p>
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
          <div class="search-box">
            <i class="pi pi-search"></i
            ><InputText
              v-model="search"
              placeholder="ค้นหาชื่อหรือรหัสนักเรียน..."
            />
          </div>
          <Select
            v-model="gradeFilter"
            :options="[{ label: 'ทุกชั้นเรียน', value: 'all' }, ...gradeLevels]"
            option-label="label"
            option-value="value"
          />
          <Select
            v-model="roomFilter"
            :options="[{ label: 'ทุกห้อง', value: 'all' }, ...rooms]"
            option-label="label"
            option-value="value"
          />
          <Select
            v-model="statusFilter"
            :options="[{ label: 'ทุกสถานะ', value: 'all' }, ...statusOptions]"
            option-label="label"
            option-value="value"
          />
        </div>

        <DataTable
          :value="filteredStudents"
          striped-rows
          responsive-layout="scroll"
          :loading="loading"
          :empty-message="'ยังไม่มีข้อมูลนักเรียน'"
          class="student-table"
        >
          <Column field="studentCode" header="รหัสนักเรียน" />
          <Column header="ชื่อ - นามสกุล"
            ><template #body="{ data, index }"
              ><div class="student-name">
                <span :class="`avatar a${index % 4}`">{{
                  initials(data.studentName)
                }}</span
                ><b>{{ data.studentName }}</b>
              </div></template
            ></Column
          >
          <Column header="ชั้น / ห้อง"
            ><template #body="{ data }"
              >{{ data.gradeLevel }} / {{ data.room }}</template
            ></Column
          >
          <Column header="ครูประจำชั้น"
            ><template #body="{ data }"
              ><span class="teacher-cell"
                ><i class="pi pi-id-card"></i
                >{{
                  data.homeroomTeacherName ||
                  teacherNameById(data.homeroomTeacherId)
                }}</span
              ></template
            ></Column
          >
          <Column field="numberInRoom" header="เลขที่" />
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
                  label="แก้ไข"
                  icon="pi pi-pencil"
                  outlined
                  size="small"
                  @click="editStudent(data)"
                /><Button
                  label="ลบ"
                  icon="pi pi-trash"
                  severity="danger"
                  text
                  size="small"
                  @click="askDelete(data)"
                /></div></template
          ></Column>
        </DataTable>

        <div class="table-footer">
          <span
            >แสดง {{ filteredStudents.length ? 1 : 0 }} -
            {{ filteredStudents.length }} จาก
            {{ filteredStudents.length }} รายการ</span
          ><span class="page-chip">1</span>
        </div>
      </template>
    </Card>

    <footer class="page-footer">
      <div><i class="pi pi-graduation-cap"></i><b>Education Hub</b></div>
      <small>Teach • Learn • Grow</small>
    </footer>

    <Dialog
      v-model:visible="editorVisible"
      modal
      :header="editId ? 'แก้ไขนักเรียน' : 'เพิ่มนักเรียน'"
      :style="{ width: 'min(34rem,94vw)' }"
    >
      <form class="student-form" @submit.prevent="saveStudent">
        <label
          ><span>รหัสนักเรียน *</span>
          <div class="code-field">
            <InputText v-model="form.studentCode" maxlength="30" fluid /><Button
              type="button"
              label="สร้างรหัส"
              icon="pi pi-sparkles"
              outlined
              @click="form.studentCode = generateStudentCode()"
            />
          </div>
          <small
            >ระบบสร้างรูปแบบ YYxxx เช่น 69001
            และตรวจไม่ให้ซ้ำกับรายการปัจจุบัน</small
          ></label
        >
        <label
          ><span>ชื่อ - นามสกุล *</span
          ><InputText v-model="form.studentName" maxlength="120" fluid
        /></label>
        <div class="form-grid">
          <label
            ><span>ชั้นเรียน *</span
            ><Select
              v-model="form.gradeLevel"
              :options="gradeLevels"
              option-label="label"
              option-value="value"
              fluid
              @change="syncTeacherForRoom" /></label
          ><label
            ><span>ห้อง *</span
            ><Select
              v-model="form.room"
              :options="rooms"
              option-label="label"
              option-value="value"
              fluid
              @change="syncTeacherForRoom"
          /></label>
        </div>
        <label
          ><span>ครูประจำชั้น</span
          ><Select
            v-model="form.homeroomTeacherId"
            :options="availableHomeroomTeachers"
            option-label="label"
            option-value="value"
            :placeholder="
              availableHomeroomTeachers.length
                ? 'เลือกครูประจำชั้น'
                : 'ยังไม่มีครูประจำชั้นสำหรับห้องนี้'
            "
            :disabled="!availableHomeroomTeachers.length"
            show-clear
            fluid
          /><small
            >รายการครูจะกรองตามชั้นเรียนและห้องที่เลือกอัตโนมัติ</small
          ></label
        >
        <div class="form-grid">
          <label
            ><span>เลขที่ *</span
            ><InputNumber
              v-model="form.numberInRoom"
              :min="1"
              :max="999"
              fluid /></label
          ><label
            ><span>สถานะ *</span
            ><Select
              v-model="form.status"
              :options="statusOptions"
              option-label="label"
              option-value="value"
              fluid
          /></label>
        </div>
        <div class="dialog-actions">
          <Button
            type="button"
            label="ยกเลิก"
            severity="secondary"
            text
            @click="editorVisible = false"
          /><Button
            type="submit"
            label="บันทึก"
            icon="pi pi-save"
            :loading="saving"
          />
        </div>
      </form>
    </Dialog>

    <Dialog
      v-model:visible="deleteVisible"
      modal
      header="ยืนยันการลบนักเรียน"
      :style="{ width: 'min(28rem,92vw)' }"
    >
      <div class="delete-confirm">
        <span><i class="pi pi-exclamation-triangle"></i></span>
        <div>
          <b>ลบ {{ deleteTarget?.studentName }} ?</b>
          <p>
            รายการนี้จะถูกนำออกจากทะเบียนนักเรียน การลบไม่ควรใช้แทนสถานะ
            “ย้ายออก” หรือ “จบการศึกษา” หากต้องการเก็บประวัติ
          </p>
        </div>
      </div>
      <div class="dialog-actions">
        <Button
          label="ยกเลิก"
          severity="secondary"
          text
          @click="deleteVisible = false"
        /><Button
          label="ลบ"
          icon="pi pi-trash"
          severity="danger"
          :loading="deleting"
          @click="deleteStudent"
        />
      </div>
    </Dialog>
  </div>
</template>

<style scoped>
.students-page {
  --navy: #102b52;
  --blue: #167df5;
  --green: #16b884;
  --line: #dce7f2;
  --muted: #71839d;
  display: grid;
  gap: 18px;
}
.students-hero {
  min-height: 174px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  padding: 26px 30px;
  border: 1px solid var(--line);
  border-radius: 20px;
  background: linear-gradient(110deg, #fff, #f2f8ff 58%, #effbf6);
  box-shadow: 0 14px 36px rgba(24, 57, 94, 0.07);
  overflow: hidden;
}
.hero-kicker {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 6px 10px;
  border-radius: 999px;
  color: var(--blue);
  background: #e7f2ff;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.08em;
}
.students-hero h1 {
  margin: 12px 0 5px;
  color: var(--navy);
  font-size: 34px;
}
.students-hero p {
  margin: 0;
  color: var(--muted);
  font-size: 14px;
}
.hero-side {
  display: flex;
  align-items: center;
  gap: 28px;
}
.hero-art {
  position: relative;
  width: 275px;
  height: 125px;
}
.book {
  position: absolute;
  left: 25px;
  width: 115px;
  height: 18px;
  border-radius: 9px;
}
.b1 {
  bottom: 23px;
  background: #3b91ec;
}
.b2 {
  bottom: 3px;
  background: #72b9fb;
}
.profile-sheet {
  position: absolute;
  left: 115px;
  top: 8px;
  width: 116px;
  height: 112px;
  display: grid;
  grid-template-columns: 40px 1fr;
  align-content: center;
  gap: 8px;
  padding: 16px;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 13px 29px rgba(36, 91, 145, 0.15);
}
.profile-sheet i {
  grid-row: 1/4;
  width: 38px;
  height: 38px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #167df5;
  background: #e3f1ff;
  font-size: 18px;
}
.profile-sheet b {
  height: 7px;
  border-radius: 99px;
  background: #dce9f5;
}
.leaf {
  position: absolute;
  width: 34px;
  height: 72px;
  border-radius: 100% 0 100% 0;
  background: #53c59c;
}
.l1 {
  left: 4px;
  top: 4px;
  transform: rotate(-28deg);
}
.l2 {
  right: 2px;
  bottom: 2px;
  transform: rotate(25deg);
}
.add-button {
  min-width: 185px;
  height: 50px;
  box-shadow: 0 10px 22px rgba(22, 184, 132, 0.2);
}
.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}
.summary-card {
  min-height: 116px;
  display: flex;
  align-items: center;
  gap: 15px;
  padding: 18px;
  border: 1px solid #e1eaf3;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 9px 25px rgba(24, 57, 94, 0.05);
}
.summary-card > span {
  width: 54px;
  height: 54px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  font-size: 21px;
}
.summary-card small,
.summary-card b,
.summary-card em {
  display: block;
}
.summary-card small {
  color: #425d79;
  font-size: 11px;
  font-weight: 700;
}
.summary-card b {
  margin-top: 2px;
  color: var(--navy);
  font-size: 28px;
}
.summary-card em {
  color: var(--muted);
  font-size: 9px;
  font-style: normal;
}
.blue > span {
  color: var(--blue);
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
.orange > span {
  color: #e99309;
  background: #fff0d6;
}
.registry-card {
  border: 1px solid var(--line);
  border-radius: 18px;
  box-shadow: 0 12px 30px rgba(24, 57, 94, 0.06);
  overflow: hidden;
}
.registry-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}
.registry-title {
  display: flex;
  align-items: center;
  gap: 13px;
}
.registry-title > span {
  width: 51px;
  height: 51px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--blue);
  background: #e7f2ff;
  font-size: 20px;
}
.registry-title h2 {
  margin: 0;
  color: var(--navy);
  font-size: 21px;
}
.registry-title p {
  margin: 3px 0 0;
  color: var(--muted);
  font-size: 11px;
}
.tools {
  display: grid;
  grid-template-columns: minmax(300px, 1fr) 180px 160px 180px;
  gap: 10px;
  margin-bottom: 14px;
}
.search-box {
  position: relative;
}
.search-box > i {
  position: absolute;
  left: 13px;
  top: 50%;
  transform: translateY(-50%);
  z-index: 2;
  color: #68809a;
}
.search-box :deep(.p-inputtext) {
  width: 100%;
  padding-left: 38px;
}
.tools select,
.student-form select {
  height: 42px;
  border: 1px solid #d3dfeb;
  border-radius: 9px;
  padding: 0 12px;
  background: #fff;
  color: #294766;
}
.student-table {
  border: 1px solid var(--line);
  border-radius: 12px;
  overflow: hidden;
}
.student-table :deep(.p-datatable-thead > tr > th) {
  padding: 13px;
  background: #eef4f9;
  color: #344f6d;
  font-size: 11px;
}
.student-table :deep(.p-datatable-tbody > tr > td) {
  padding: 12px 13px;
}
.student-name {
  display: flex;
  align-items: center;
  gap: 10px;
}
.student-name b {
  color: #294766;
}
.avatar {
  width: 36px;
  height: 36px;
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
.teacher-cell {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: #294766;
}
.teacher-cell i {
  color: #7c4dff;
}
.row-actions {
  display: flex;
  gap: 4px;
}
.table-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 17px 3px 2px;
  color: var(--muted);
  font-size: 10px;
}
.page-chip {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 9px;
  background: var(--green);
  color: #fff;
  font-weight: 800;
}
.page-footer {
  text-align: center;
  color: #70839d;
}
.page-footer div {
  display: flex;
  justify-content: center;
  gap: 6px;
  font-size: 11px;
}
.page-footer small {
  display: block;
  margin-top: 3px;
  font-size: 9px;
}
.student-form {
  display: grid;
  gap: 15px;
}
.student-form label {
  display: grid;
  gap: 7px;
  color: #294766;
  font-size: 12px;
  font-weight: 700;
}
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.code-field {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 8px;
}
.student-form label > small {
  color: #8291a8;
  font-size: 9px;
  font-weight: 400;
}
.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 3px;
}
.delete-confirm {
  display: flex;
  gap: 14px;
  padding: 5px 0 18px;
}
.delete-confirm > span {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  flex: 0 0 48px;
  border-radius: 50%;
  color: #dc3545;
  background: #ffeded;
}
.delete-confirm b {
  color: var(--navy);
}
.delete-confirm p {
  margin: 5px 0 0;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.6;
}
@media (max-width: 1050px) {
  .summary-grid {
    grid-template-columns: 1fr 1fr;
  }
  .hero-art {
    display: none;
  }
  .tools {
    grid-template-columns: 1fr 1fr;
  }
  .search-box {
    grid-column: 1/-1;
  }
}
@media (max-width: 700px) {
  .code-field {
    grid-template-columns: 1fr;
  }
  .code-field :deep(.p-button) {
    width: 100%;
  }
  .students-hero {
    align-items: flex-start;
    flex-direction: column;
    padding: 20px;
  }
  .students-hero h1 {
    font-size: 26px;
  }
  .hero-side,
  .add-button {
    width: 100%;
  }
  .summary-grid {
    grid-template-columns: 1fr 1fr;
  }
  .summary-card {
    min-height: 98px;
    padding: 13px;
  }
  .registry-heading {
    align-items: flex-start;
    flex-direction: column;
  }
  .registry-heading :deep(.p-button) {
    width: 100%;
  }
  .tools {
    grid-template-columns: 1fr;
  }
  .search-box {
    grid-column: auto;
  }
  .student-table {
    margin: 0 -16px;
  }
  .form-grid {
    grid-template-columns: 1fr;
  }
  .row-actions {
    flex-direction: column;
  }
}
</style>
