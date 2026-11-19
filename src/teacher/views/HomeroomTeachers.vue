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

const teachers = ref([]);
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
        (row.teachingSubjects || [])
          .map((subject) => subject.subjectName)
          .join(" "),
      ].some((value) =>
        String(value || "")
          .toLowerCase()
          .includes(term),
      );
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

function teachingSubjects(row) {
  return row.teachingSubjects || [];
}

const activeCount = computed(
  () => teachers.value.filter((row) => row.status === "active").length,
);
const inactiveCount = computed(() => teachers.value.length - activeCount.value);
const assignedRoomCount = computed(
  () =>
    new Set(
      teachers.value
        .filter((row) => row.gradeLevel && row.room)
        .map((row) => `${row.gradeLevel}/${row.room}`),
    ).size,
);

function initials(name) {
  return (
    String(name || "?")
      .trim()
      .charAt(0) || "?"
  );
}
function statusLabel(status) {
  return status === "active" ? "ใช้งาน" : "พักการใช้งาน";
}
function statusSeverity(status) {
  return status === "active" ? "success" : "secondary";
}

function generateTeacherCode() {
  const used = new Set(
    teachers.value.map((row) => String(row.teacherCode || "")),
  );
  let sequence = 1;
  let code = `T${String(sequence).padStart(3, "0")}`;
  while (used.has(code)) {
    sequence += 1;
    code = `T${String(sequence).padStart(3, "0")}`;
  }
  return code;
}

async function load() {
  loading.value = true;
  message.value = "";
  try {
    teachers.value = (await rpc("teacher_homeroom_list")) || [];
  } catch (error) {
    message.value = error.message || "ไม่สามารถโหลดข้อมูลครูประจำชั้นได้";
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

function editTeacher(row) {
  editId.value = row.id;
  form.value = {
    teacherCode: row.teacherCode || "",
    teacherName: row.teacherName || "",
    gradeLevel: row.gradeLevel || "ป.1",
    room: String(row.room || "1"),
    phone: row.phone || "",
    email: row.email || "",
    status: row.status || "active",
  };
  editorVisible.value = true;
}

async function saveTeacher() {
  const payload = {
    id: editId.value,
    teacherCode: form.value.teacherCode.trim(),
    teacherName: form.value.teacherName.trim(),
    gradeLevel: form.value.gradeLevel,
    room: form.value.room,
    phone: form.value.phone.trim(),
    email: form.value.email.trim(),
    status: form.value.status,
  };
  if (!payload.teacherCode) return (message.value = "กรุณาระบุรหัสครู");
  if (!payload.teacherName)
    return (message.value = "กรุณากรอกชื่อครูประจำชั้น");

  saving.value = true;
  message.value = "";
  successMessage.value = "";
  try {
    await rpc("teacher_homeroom_save", { p_payload: payload });
    editorVisible.value = false;
    successMessage.value = editId.value
      ? "แก้ไขข้อมูลครูประจำชั้นแล้ว"
      : "เพิ่มครูประจำชั้นแล้ว";
    await load();
  } catch (error) {
    message.value = error.message || "ไม่สามารถบันทึกข้อมูลครูประจำชั้นได้";
  } finally {
    saving.value = false;
  }
}

function askDelete(row) {
  deleteTarget.value = row;
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
    successMessage.value = "ลบข้อมูลครูประจำชั้นแล้ว";
    await load();
  } catch (error) {
    message.value = error.message || "ไม่สามารถลบข้อมูลครูประจำชั้นได้";
  } finally {
    deleting.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="homeroom-page">
    <section class="hero">
      <div>
        <span class="hero-kicker"
          ><i class="pi pi-id-card"></i> HOMEROOM MANAGEMENT</span
        >
        <h1>ครูประจำชั้น</h1>
        <p>จัดการครูประจำชั้นและการดูแลห้องเรียนตั้งแต่ ป.1 ถึง ม.3</p>
      </div>
      <div class="hero-side">
        <div class="hero-art" aria-hidden="true">
          <span class="teacher-card"
            ><i class="pi pi-user"></i><b></b><b></b></span
          ><span class="school"><i class="pi pi-building"></i></span
          ><span class="leaf l1"></span><span class="leaf l2"></span>
        </div>
        <Button
          label="เพิ่มครูประจำชั้น"
          icon="pi pi-plus"
          class="add-button"
          @click="addTeacher"
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
      <article class="summary blue">
        <span><i class="pi pi-users"></i></span>
        <div>
          <small>ครูประจำชั้นทั้งหมด</small><b>{{ teachers.length }}</b
          ><em>คน</em>
        </div>
      </article>
      <article class="summary green">
        <span><i class="pi pi-check-circle"></i></span>
        <div>
          <small>ใช้งาน</small><b>{{ activeCount }}</b
          ><em>คน</em>
        </div>
      </article>
      <article class="summary purple">
        <span><i class="pi pi-building"></i></span>
        <div>
          <small>ห้องที่มีครูดูแล</small><b>{{ assignedRoomCount }}</b
          ><em>ห้อง</em>
        </div>
      </article>
      <article class="summary gray">
        <span><i class="pi pi-pause-circle"></i></span>
        <div>
          <small>พักการใช้งาน</small><b>{{ inactiveCount }}</b
          ><em>คน</em>
        </div>
      </article>
    </section>

    <Card class="registry-card">
      <template #content>
        <div class="registry-heading">
          <div class="registry-title">
            <span><i class="pi pi-briefcase"></i></span>
            <div>
              <h2>ทะเบียนครูประจำชั้น</h2>
              <p>
                กำหนดครูผู้ดูแลแต่ละชั้นและห้องเรียน
                พร้อมแสดงรายวิชาที่สอนจากเมนูวิชาและชั้นเรียน
              </p>
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
            <i class="pi pi-search"></i
            ><InputText
              v-model="search"
              placeholder="ค้นหาชื่อ รหัส โทรศัพท์ หรืออีเมล..."
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
          :empty-message="'ยังไม่มีข้อมูลครูประจำชั้น'"
          class="teacher-table"
        >
          <Column field="teacherCode" header="รหัสครู" />
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
          <Column header="ประจำชั้น / ห้อง"
            ><template #body="{ data }"
              ><b>{{ data.gradeLevel }} / {{ data.room }}</b></template
            ></Column
          >
          <Column header="วิชาที่สอน">
            <template #body="{ data }">
              <div
                v-if="teachingSubjects(data).length"
                class="teaching-subjects"
              >
                <div
                  v-for="subject in teachingSubjects(data)"
                  :key="`${subject.subjectId}-${subject.gradeLevel}-${subject.room}`"
                  class="teaching-subject-item"
                >
                  <div class="teaching-subject-name">
                    <i class="pi pi-book"></i>
                    <b>{{ subject.subjectName }}</b>
                  </div>
                  <div class="teaching-class">
                    <span>{{ subject.gradeLevel }}</span>
                    <span class="dot">•</span>
                    <span>ห้อง {{ subject.room }}</span>
                  </div>
                </div>
              </div>
              <span v-else class="no-subject">ยังไม่มีวิชาที่สอน</span>
            </template>
          </Column>
          <Column field="phone" header="โทรศัพท์"
            ><template #body="{ data }">{{
              data.phone || "-"
            }}</template></Column
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
                  label="แก้ไข"
                  icon="pi pi-pencil"
                  outlined
                  size="small"
                  @click="editTeacher(data)"
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
      </template>
    </Card>

    <Dialog
      v-model:visible="editorVisible"
      modal
      :header="editId ? 'แก้ไขครูประจำชั้น' : 'เพิ่มครูประจำชั้น'"
      :style="{ width: 'min(36rem,94vw)' }"
    >
      <form class="teacher-form" @submit.prevent="saveTeacher">
        <label
          ><span>รหัสครู *</span>
          <div class="code-field">
            <InputText v-model="form.teacherCode" maxlength="20" fluid /><Button
              type="button"
              label="สร้างรหัส"
              icon="pi pi-sparkles"
              outlined
              @click="form.teacherCode = generateTeacherCode()"
            /></div
        ></label>
        <label
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
            ><InputText
              v-model="form.phone"
              inputmode="tel"
              maxlength="30"
              fluid /></label
          ><label
            ><span>อีเมล</span
            ><InputText v-model="form.email" type="email" maxlength="160" fluid
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
      header="ยืนยันการลบ"
      :style="{ width: 'min(28rem,92vw)' }"
    >
      <div class="delete-confirm">
        <i class="pi pi-exclamation-triangle"></i>
        <div>
          <b>ลบ {{ deleteTarget?.teacherName }} ?</b>
          <p>
            ถ้าครูยังดูแลห้องเรียนอยู่ แนะนำเปลี่ยนสถานะเป็น “พักการใช้งาน”
            แทนการลบ
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
          @click="deleteTeacher"
        />
      </div>
    </Dialog>
  </div>
</template>

<style scoped>
.homeroom-page {
  --navy: #102b52;
  --blue: #167df5;
  --green: #16b884;
  --line: #dce7f2;
  --muted: #71839d;
  display: grid;
  gap: 18px;
}
.hero {
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
.hero h1 {
  margin: 12px 0 5px;
  color: var(--navy);
  font-size: 34px;
}
.hero p {
  margin: 0;
  color: var(--muted);
  font-size: 14px;
}
.hero-side {
  display: flex;
  align-items: center;
  gap: 24px;
}
.hero-art {
  position: relative;
  width: 270px;
  height: 120px;
}
.teacher-card {
  position: absolute;
  left: 75px;
  top: 5px;
  width: 118px;
  height: 110px;
  display: grid;
  grid-template-columns: 40px 1fr;
  align-content: center;
  gap: 9px;
  padding: 15px;
  border-radius: 13px;
  background: #fff;
  box-shadow: 0 14px 30px rgba(36, 91, 145, 0.16);
}
.teacher-card i {
  grid-row: 1/3;
  width: 40px;
  height: 40px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--blue);
  background: #e3f1ff;
  font-size: 20px;
}
.teacher-card b {
  height: 7px;
  border-radius: 999px;
  background: #dce9f5;
}
.school {
  position: absolute;
  left: 15px;
  bottom: 7px;
  width: 78px;
  height: 72px;
  display: grid;
  place-items: center;
  border-radius: 18px;
  color: #fff;
  background: linear-gradient(145deg, #7b5beb, #a78cff);
  font-size: 29px;
}
.leaf {
  position: absolute;
  width: 32px;
  height: 70px;
  border-radius: 100% 0 100% 0;
  background: #58c8a0;
}
.l1 {
  left: 3px;
  top: 2px;
  transform: rotate(-28deg);
}
.l2 {
  right: 13px;
  bottom: 4px;
  transform: rotate(22deg);
}
.add-button {
  min-width: 205px;
  height: 50px;
  box-shadow: 0 10px 22px rgba(22, 184, 132, 0.2);
}
.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}
.summary {
  min-height: 112px;
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 18px;
  border: 1px solid #e1eaf3;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 9px 25px rgba(24, 57, 94, 0.05);
}
.summary > span {
  width: 54px;
  height: 54px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  font-size: 21px;
}
.summary small,
.summary b,
.summary em {
  display: block;
}
.summary small {
  color: #425d79;
  font-size: 11px;
  font-weight: 700;
}
.summary b {
  margin-top: 2px;
  color: var(--navy);
  font-size: 28px;
}
.summary em {
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
.gray > span {
  color: #536a83;
  background: #e9eef4;
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
  color: #7c4dff;
  background: #eee7ff;
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
  grid-template-columns: minmax(300px, 1fr) 190px 160px 180px;
  gap: 10px;
  margin-bottom: 14px;
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
  border-radius: 12px;
  overflow: hidden;
}
.teacher-table :deep(.p-datatable-thead > tr > th) {
  padding: 13px;
  background: #eef4f9;
  color: #344f6d;
  font-size: 11px;
}
.teacher-table :deep(.p-datatable-tbody > tr > td) {
  padding: 12px 13px;
}
.teacher-name {
  display: flex;
  align-items: center;
  gap: 10px;
}
.teacher-name small,
.teacher-name b {
  display: block;
}
.teacher-name small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 9px;
}
.avatar {
  width: 38px;
  height: 38px;
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
.teaching-subjects {
  display: grid;
  gap: 7px;
  min-width: 170px;
}
.teaching-subject-item {
  padding: 8px 10px;
  border: 1px solid #e2eaf3;
  border-radius: 9px;
  background: #f8fbfe;
}
.teaching-subject-name {
  display: flex;
  align-items: center;
  gap: 7px;
}
.teaching-subject-name i {
  color: #7c4dff;
  font-size: 12px;
}
.teaching-subject-name b {
  color: #294766;
  font-size: 11px;
}
.teaching-class {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 4px;
  padding-left: 19px;
  color: #71839d;
  font-size: 9px;
}
.teaching-class .dot {
  color: #b1becb;
}
.no-subject {
  color: #9aa8ba;
  font-size: 10px;
}
.row-actions {
  display: flex;
  gap: 4px;
}
.teacher-form {
  display: grid;
  gap: 15px;
}
.teacher-form label {
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
  grid-template-columns: 1fr auto;
  gap: 8px;
}
.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
.delete-confirm {
  display: flex;
  gap: 13px;
  padding-bottom: 18px;
}
.delete-confirm > i {
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
  .search {
    grid-column: 1/-1;
  }
}
@media (max-width: 700px) {
  .hero {
    align-items: flex-start;
    flex-direction: column;
    padding: 20px;
  }
  .hero h1 {
    font-size: 26px;
  }
  .hero-side,
  .add-button {
    width: 100%;
  }
  .summary-grid {
    grid-template-columns: 1fr 1fr;
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
  .search {
    grid-column: auto;
  }
  .teacher-table {
    margin: 0 -16px;
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
