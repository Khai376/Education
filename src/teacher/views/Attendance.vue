<script setup>
import { computed, onMounted, ref } from "vue";
import Button from "primevue/button";
import Card from "primevue/card";
import Column from "primevue/column";
import DataTable from "primevue/datatable";
import DatePicker from "primevue/datepicker";
import Dialog from "primevue/dialog";
import InputNumber from "primevue/inputnumber";
import InputText from "primevue/inputtext";
import Message from "primevue/message";
import Tag from "primevue/tag";
import { rpc } from "../../services/supabase";

const dashboard = ref({ active: null, sessions: [] });
const loading = ref(false);
const creating = ref(false);
const message = ref("");
const successMessage = ref("");
const createDialog = ref(false);
const detailDialog = ref(false);
const selectedSession = ref(null);
const search = ref("");
const statusFilter = ref("all");
const dateFilter = ref(null);

const form = ref({
  title: "วิทยาศาสตร์ ว301/1",
  sessionDate: new Date(),
  graceMinutes: 15,
});

const sessions = computed(() => dashboard.value?.sessions || []);
const totalSessions = computed(() => sessions.value.length);
const openSessions = computed(
  () => sessions.value.filter((item) => item.status === "open").length,
);
const closedSessions = computed(
  () => sessions.value.filter((item) => item.status !== "open").length,
);
const totalCheckins = computed(() =>
  sessions.value.reduce(
    (sum, item) => sum + Number(item.attendeeCount || 0),
    0,
  ),
);

const filteredSessions = computed(() => {
  const term = search.value.trim().toLowerCase();
  const selectedDate = dateFilter.value ? toDateKey(dateFilter.value) : "";

  return sessions.value.filter((item) => {
    const matchesSearch =
      !term ||
      String(item.title || "")
        .toLowerCase()
        .includes(term) ||
      String(item.code || "").includes(term);

    const matchesStatus =
      statusFilter.value === "all" || item.status === statusFilter.value;
    const matchesDate =
      !selectedDate || toDateKey(item.sessionDate) === selectedDate;

    return matchesSearch && matchesStatus && matchesDate;
  });
});

function toDateKey(value) {
  if (!value) return "";
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return String(value).slice(0, 10);
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
  ].join("-");
}

function formatDate(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("th-TH", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
}

function statusLabel(status) {
  return status === "open" ? "เปิดอยู่" : "ปิดแล้ว";
}

function statusSeverity(status) {
  return status === "open" ? "success" : "secondary";
}

async function load() {
  loading.value = true;
  message.value = "";

  try {
    dashboard.value = (await rpc("teacher_attendance_dashboard")) || {
      active: null,
      sessions: [],
    };
  } catch (error) {
    message.value = error.message || "ไม่สามารถโหลดข้อมูลเช็คชื่อได้";
  } finally {
    loading.value = false;
  }
}

function openCreateDialog() {
  form.value = {
    title: "วิทยาศาสตร์ ว301/1",
    sessionDate: new Date(),
    graceMinutes: 15,
  };

  createDialog.value = true;
}

async function createSession() {
  message.value = "";
  successMessage.value = "";

  const normalizedTitle = form.value.title.trim();

  if (!normalizedTitle) {
    message.value = "กรุณากรอกชื่อวิชา / ห้องเรียน";
    return;
  }

  if (!form.value.sessionDate) {
    message.value = "กรุณาเลือกวันที่";
    return;
  }

  creating.value = true;

  try {
    const result = await rpc("teacher_attendance_create", {
      p_title: normalizedTitle,
      p_session_date: toDateKey(form.value.sessionDate),
      p_grace_minutes: Number(form.value.graceMinutes || 0),
    });

    createDialog.value = false;
    successMessage.value = `สร้างรหัสเช็คชื่อ ${result?.code || ""} เรียบร้อยแล้ว`;
    await load();
  } catch (error) {
    message.value = error.message || "ไม่สามารถสร้างรหัสเช็คชื่อได้";
  } finally {
    creating.value = false;
  }
}

async function closeActiveSession() {
  if (!dashboard.value?.active?.id) return;

  message.value = "";
  successMessage.value = "";

  try {
    await rpc("teacher_attendance_close", {
      p_session_id: dashboard.value.active.id,
    });

    successMessage.value = "ปิดรอบเช็คชื่อเรียบร้อยแล้ว";
    await load();
  } catch (error) {
    message.value = error.message || "ไม่สามารถปิดรอบเช็คชื่อได้";
  }
}

async function copyCode(code) {
  try {
    await navigator.clipboard.writeText(String(code));
    successMessage.value = `คัดลอกรหัส ${code} แล้ว`;
  } catch {
    message.value = "ไม่สามารถคัดลอกรหัสได้";
  }
}

function showDetails(session) {
  selectedSession.value = session;
  detailDialog.value = true;
}

onMounted(load);
</script>

<template>
  <div class="attendance-page">
    <section class="attendance-hero">
      <div class="hero-copy">
        <span class="hero-kicker">
          <i class="pi pi-users"></i>
          ATTENDANCE MANAGEMENT
        </span>

        <h1>เช็คชื่อเข้าเรียน</h1>
        <p>สร้างรหัสเช็คชื่อและติดตามการเข้าเรียนในที่เดียว</p>
      </div>

      <div class="hero-actions">
        <div class="hero-visual" aria-hidden="true">
          <span class="hero-blob blob-one"></span>
          <span class="hero-blob blob-two"></span>
          <span class="hero-leaf leaf-one"></span>
          <span class="hero-leaf leaf-two"></span>
          <span class="calendar-board">
            <i class="calendar-ring ring-one"></i>
            <i class="calendar-ring ring-two"></i>
            <i class="calendar-ring ring-three"></i>
            <span class="calendar-row"><i class="pi pi-check"></i><b></b></span>
            <span class="calendar-row"><i class="pi pi-check"></i><b></b></span>
            <span class="calendar-row"><i class="pi pi-check"></i><b></b></span>
          </span>
          <span class="check-badge"><i class="pi pi-check"></i></span>
          <span class="paper-card"
            ><i class="pi pi-check-square"></i><i class="pi pi-check-square"></i
          ></span>
        </div>

        <Button
          label="สร้างรหัสเช็คชื่อ"
          icon="pi pi-plus"
          class="create-button"
          @click="openCreateDialog"
        />
      </div>
    </section>

    <Message v-if="message" severity="error" closable @close="message = ''">
      {{ message }}
    </Message>

    <Message
      v-if="successMessage"
      severity="success"
      closable
      @close="successMessage = ''"
    >
      {{ successMessage }}
    </Message>

    <section v-if="dashboard.active" class="active-session-card">
      <div class="active-state">
        <span class="pulse"></span>
        กำลังเปิดรับเช็คชื่อ
      </div>

      <div class="active-main">
        <div>
          <small>วิชา / ห้องเรียน</small>
          <h2>{{ dashboard.active.title }}</h2>
        </div>

        <button
          type="button"
          class="active-code"
          title="คัดลอกรหัส"
          @click="copyCode(dashboard.active.code)"
        >
          <small>รหัสเช็คชื่อ</small>
          <strong>{{ dashboard.active.code }}</strong>
          <i class="pi pi-copy"></i>
        </button>

        <div class="active-count">
          <small>เช็คชื่อแล้ว</small>
          <b>{{ dashboard.active.records?.length || 0 }}</b>
          <span>คน</span>
        </div>

        <Button
          label="ปิดรอบเช็คชื่อ"
          icon="pi pi-stop-circle"
          severity="danger"
          outlined
          @click="closeActiveSession"
        />
      </div>
    </section>

    <section class="summary-grid">
      <article class="summary-card blue">
        <span class="summary-icon"><i class="pi pi-list"></i></span>
        <div>
          <small>รอบเช็คชื่อทั้งหมด</small><b>{{ totalSessions }}</b
          ><em>รอบ</em>
        </div>
      </article>

      <article class="summary-card green">
        <span class="summary-icon"><i class="pi pi-play"></i></span>
        <div>
          <small>เปิดรับเช็คชื่อ</small><b>{{ openSessions }}</b
          ><em>รอบ</em>
        </div>
      </article>

      <article class="summary-card gray">
        <span class="summary-icon"><i class="pi pi-stop"></i></span>
        <div>
          <small>ปิดแล้ว</small><b>{{ closedSessions }}</b
          ><em>รอบ</em>
        </div>
      </article>

      <article class="summary-card purple">
        <span class="summary-icon"><i class="pi pi-users"></i></span>
        <div>
          <small>เช็คชื่อสะสม</small><b>{{ totalCheckins }}</b
          ><em>ครั้ง</em>
        </div>
      </article>
    </section>

    <Card class="history-card">
      <template #content>
        <div class="history-heading">
          <div class="history-title">
            <span><i class="pi pi-history"></i></span>
            <div>
              <h2>ประวัติการเช็คชื่อ</h2>
              <p>จัดการรอบเรียนและตรวจสอบรายชื่อ</p>
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

        <div class="history-tools">
          <div class="search-box">
            <i class="pi pi-search"></i>
            <InputText
              v-model="search"
              placeholder="ค้นหาวิชา / ห้องเรียน หรือรหัส..."
            />
          </div>

          <div class="date-box">
            <i class="pi pi-calendar"></i>
            <DatePicker
              v-model="dateFilter"
              date-format="dd/mm/yy"
              placeholder="ทุกวันที่"
              show-button-bar
            />
          </div>

          <div class="select-box">
            <i class="pi pi-filter"></i>
            <select v-model="statusFilter">
              <option value="all">ทุกสถานะ</option>
              <option value="open">เปิดอยู่</option>
              <option value="closed">ปิดแล้ว</option>
            </select>
          </div>
        </div>

        <DataTable
          :value="filteredSessions"
          striped-rows
          responsive-layout="scroll"
          :loading="loading"
          :empty-message="'ไม่พบประวัติการเช็คชื่อ'"
          class="attendance-table"
        >
          <Column header="วันที่">
            <template #body="{ data }">
              <span class="date-cell">{{ formatDate(data.sessionDate) }}</span>
            </template>
          </Column>

          <Column field="title" header="วิชา / ห้องเรียน" />

          <Column header="รหัสเช็คชื่อ">
            <template #body="{ data }">
              <button
                type="button"
                class="code-chip"
                title="คัดลอกรหัส"
                @click="copyCode(data.code)"
              >
                <span>{{ data.code }}</span>
                <i class="pi pi-copy"></i>
              </button>
            </template>
          </Column>

          <Column header="สถานะ">
            <template #body="{ data }">
              <Tag
                :severity="statusSeverity(data.status)"
                :value="statusLabel(data.status)"
              />
            </template>
          </Column>

          <Column header="เช็คชื่อแล้ว">
            <template #body="{ data }">
              <span class="student-count">
                <i class="pi pi-users"></i>
                {{ data.attendeeCount || 0 }} คน
              </span>
            </template>
          </Column>

          <Column header="จัดการ">
            <template #body="{ data }">
              <Button
                label="ดูรายชื่อ"
                icon="pi pi-chevron-right"
                icon-pos="right"
                outlined
                size="small"
                @click="showDetails(data)"
              />
            </template>
          </Column>
        </DataTable>

        <div class="table-footer">
          <span>
            แสดง {{ filteredSessions.length ? 1 : 0 }} -
            {{ filteredSessions.length }} จาก
            {{ filteredSessions.length }} รายการ
          </span>

          <div class="pagination">
            <button type="button" disabled>
              <i class="pi pi-chevron-left"></i>
            </button>
            <b>1</b>
            <button type="button" disabled>
              <i class="pi pi-chevron-right"></i>
            </button>
          </div>
        </div>
      </template>
    </Card>

    <footer class="page-footer">
      <div><i class="pi pi-graduation-cap"></i><b>Education Hub</b></div>
      <small>Teach • Learn • Grow</small>
    </footer>

    <Dialog
      v-model:visible="createDialog"
      modal
      header="สร้างรหัสเช็คชื่อ"
      :style="{ width: 'min(32rem, 92vw)' }"
    >
      <form class="dialog-form" @submit.prevent="createSession">
        <label>
          <span>วิชา / ห้องเรียน</span>
          <InputText v-model="form.title" maxlength="120" fluid />
        </label>

        <label>
          <span>วันที่</span>
          <DatePicker v-model="form.sessionDate" date-format="dd/mm/yy" fluid />
        </label>

        <label>
          <span>ถือว่าสายหลัง (นาที)</span>
          <InputNumber v-model="form.graceMinutes" :min="0" :max="180" fluid />
        </label>

        <div class="dialog-note">
          <i class="pi pi-info-circle"></i>
          ระบบจะสร้างรหัสตัวเลข 6 หลักให้อัตโนมัติ
        </div>

        <div class="dialog-actions">
          <Button
            type="button"
            label="ยกเลิก"
            severity="secondary"
            text
            @click="createDialog = false"
          />

          <Button
            type="submit"
            label="สร้างรหัสเช็คชื่อ"
            icon="pi pi-plus"
            :loading="creating"
          />
        </div>
      </form>
    </Dialog>

    <Dialog
      v-model:visible="detailDialog"
      modal
      header="รายละเอียดรอบเช็คชื่อ"
      :style="{ width: 'min(34rem, 92vw)' }"
    >
      <div v-if="selectedSession" class="session-detail">
        <div class="session-detail-code">
          <small>รหัสเช็คชื่อ</small>
          <strong>{{ selectedSession.code }}</strong>
          <Button
            icon="pi pi-copy"
            text
            rounded
            @click="copyCode(selectedSession.code)"
          />
        </div>

        <div class="session-detail-grid">
          <div>
            <small>วิชา / ห้องเรียน</small><b>{{ selectedSession.title }}</b>
          </div>
          <div>
            <small>วันที่</small
            ><b>{{ formatDate(selectedSession.sessionDate) }}</b>
          </div>
          <div>
            <small>สถานะ</small><b>{{ statusLabel(selectedSession.status) }}</b>
          </div>
          <div>
            <small>เช็คชื่อแล้ว</small
            ><b>{{ selectedSession.attendeeCount || 0 }} คน</b>
          </div>
        </div>
      </div>
    </Dialog>
  </div>
</template>

<style scoped>
.attendance-page {
  --navy: #102b52;
  --blue: #167df5;
  --green: #16b884;
  --line: #dce7f2;
  --muted: #71839d;

  display: grid;
  gap: 18px;
}

.attendance-hero {
  min-height: 174px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  padding: 26px 30px;
  border: 1px solid var(--line);
  border-radius: 20px;
  background:
    radial-gradient(
      circle at 75% 35%,
      rgba(85, 174, 255, 0.17),
      transparent 23%
    ),
    linear-gradient(120deg, #ffffff 0%, #f1f8ff 58%, #edf9f5 100%);
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

.hero-copy h1 {
  margin: 12px 0 5px;
  color: var(--navy);
  font-size: 32px;
}

.hero-copy p {
  margin: 0;
  color: var(--muted);
  font-size: 14px;
}

.hero-actions {
  display: flex;
  align-items: center;
  gap: 28px;
}

.hero-visual {
  position: relative;
  width: 150px;
  height: 105px;
}

.calendar-icon {
  position: absolute;
  top: 4px;
  left: 12px;
  width: 94px;
  height: 90px;
  display: grid;
  place-items: center;
  border-radius: 24px;
  color: #ffffff;
  background: linear-gradient(145deg, #5eaaff, #167df5);
  box-shadow: 0 13px 28px rgba(22, 125, 245, 0.23);
}

.calendar-icon i {
  font-size: 42px;
}

.check-icon {
  position: absolute;
  right: 7px;
  bottom: 3px;
  width: 62px;
  height: 62px;
  display: grid;
  place-items: center;
  border: 7px solid #effaf6;
  border-radius: 50%;
  color: #ffffff;
  background: var(--green);
  box-shadow: 0 9px 20px rgba(22, 184, 132, 0.24);
}

.check-icon i {
  font-size: 23px;
}

.create-button {
  box-shadow: 0 10px 22px rgba(22, 184, 132, 0.2);
}

.active-session-card {
  padding: 19px 22px;
  border: 1px solid #bdebdc;
  border-radius: 16px;
  background: linear-gradient(100deg, #f3fcf8, #ffffff);
  box-shadow: 0 9px 24px rgba(22, 184, 132, 0.07);
}

.active-state {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 13px;
  color: #0d956a;
  font-size: 11px;
  font-weight: 800;
}

.pulse {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--green);
  box-shadow: 0 0 0 5px rgba(22, 184, 132, 0.13);
}

.active-main {
  display: grid;
  grid-template-columns: 1.5fr 1fr 0.7fr auto;
  align-items: center;
  gap: 20px;
}

.active-main small,
.active-main h2,
.active-main b,
.active-main span {
  display: block;
}

.active-main small {
  color: var(--muted);
  font-size: 9px;
}

.active-main h2 {
  margin: 3px 0 0;
  color: var(--navy);
  font-size: 18px;
}

.active-code {
  position: relative;
  padding: 12px 42px 12px 15px;
  border: 1px solid #cde0f1;
  border-radius: 12px;
  color: var(--navy);
  background: #ffffff;
  text-align: left;
  cursor: pointer;
}

.active-code strong {
  margin-top: 2px;
  font-size: 24px;
  letter-spacing: 0.12em;
}

.active-code i {
  position: absolute;
  right: 15px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--blue);
}

.active-count b {
  margin-top: 2px;
  color: var(--navy);
  font-size: 26px;
}

.active-count span {
  color: var(--muted);
  font-size: 9px;
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
  background: #ffffff;
  box-shadow: 0 9px 25px rgba(24, 57, 94, 0.05);
}

.summary-icon {
  width: 54px;
  height: 54px;
  flex: 0 0 54px;
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

.summary-card.blue .summary-icon {
  color: var(--blue);
  background: #e1efff;
}
.summary-card.green .summary-icon {
  color: #0ca575;
  background: #ddf8ed;
}
.summary-card.gray .summary-icon {
  color: #50667f;
  background: #e9eef4;
}
.summary-card.purple .summary-icon {
  color: #7c4dff;
  background: #eee7ff;
}

.history-card {
  border: 1px solid var(--line);
  border-radius: 18px;
  box-shadow: 0 12px 30px rgba(24, 57, 94, 0.06);
  overflow: hidden;
}

.history-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}

.history-title {
  display: flex;
  align-items: center;
  gap: 13px;
}

.history-title > span {
  width: 51px;
  height: 51px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--blue);
  background: #e7f2ff;
  font-size: 20px;
}

.history-title h2 {
  margin: 0;
  color: var(--navy);
  font-size: 21px;
}

.history-title p {
  margin: 3px 0 0;
  color: var(--muted);
  font-size: 11px;
}

.history-tools {
  display: grid;
  grid-template-columns: minmax(280px, 1fr) 255px 255px;
  gap: 12px;
  margin-bottom: 15px;
}

.search-box,
.date-box,
.select-box {
  position: relative;
}

.search-box > i,
.date-box > i,
.select-box > i {
  position: absolute;
  top: 50%;
  left: 14px;
  transform: translateY(-50%);
  z-index: 2;
  color: #5d7692;
}

.search-box :deep(.p-inputtext),
.date-box :deep(.p-datepicker),
.date-box :deep(.p-inputtext) {
  width: 100%;
}

.search-box :deep(.p-inputtext),
.date-box :deep(.p-inputtext) {
  padding-left: 40px;
}

.select-box select {
  width: 100%;
  height: 42px;
  padding: 0 12px 0 40px;
  border: 1px solid #d3dfeb;
  border-radius: 9px;
  color: #294766;
  background: #ffffff;
}

.attendance-table :deep(.p-datatable-thead > tr > th) {
  padding: 14px;
  color: #344f6d;
  background: #eef4f9;
  font-size: 11px;
}

.attendance-table :deep(.p-datatable-tbody > tr > td) {
  padding: 14px;
}

.attendance-table :deep(.p-datatable-tbody > tr:hover) {
  background: #f7fbff;
}

.date-cell {
  color: #294766;
  font-weight: 700;
}

.code-chip {
  display: inline-flex;
  align-items: center;
  gap: 14px;
  padding: 7px 11px;
  border: 0;
  border-radius: 9px;
  color: #294766;
  background: #eaf2fa;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-weight: 700;
  cursor: pointer;
}

.code-chip i {
  color: #567390;
}

.student-count {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: #294766;
  font-weight: 700;
}

.student-count i {
  color: #4d6b8d;
}

.table-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 18px 4px 2px;
  color: var(--muted);
  font-size: 10px;
}

.pagination {
  display: flex;
  align-items: center;
  gap: 8px;
}

.pagination button,
.pagination b {
  width: 37px;
  height: 37px;
  display: grid;
  place-items: center;
  border-radius: 9px;
}

.pagination button {
  border: 1px solid #dde6ef;
  color: #95a5b6;
  background: #f8fafc;
}

.pagination b {
  color: #ffffff;
  background: var(--green);
}

.page-footer {
  padding: 2px 0 12px;
  text-align: center;
  color: #70839d;
}

.page-footer div {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  font-size: 11px;
}

.page-footer small {
  display: block;
  margin-top: 3px;
  font-size: 9px;
}

.dialog-form {
  display: grid;
  gap: 15px;
}

.dialog-form label {
  display: grid;
  gap: 7px;
  color: #294766;
  font-size: 12px;
  font-weight: 700;
}

.dialog-note {
  display: flex;
  gap: 8px;
  padding: 11px 13px;
  border-radius: 9px;
  color: #4f6f90;
  background: #eff6fd;
  font-size: 10px;
}

.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.session-detail-code {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  border-radius: 13px;
  background: #edf6ff;
}

.session-detail-code small {
  color: var(--muted);
}

.session-detail-code strong {
  margin-left: auto;
  color: var(--navy);
  font-size: 25px;
  letter-spacing: 0.12em;
}

.session-detail-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-top: 13px;
}

.session-detail-grid > div {
  padding: 13px;
  border-radius: 10px;
  background: #f7f9fc;
}

.session-detail-grid small,
.session-detail-grid b {
  display: block;
}

.session-detail-grid small {
  color: var(--muted);
  font-size: 9px;
}

.session-detail-grid b {
  margin-top: 3px;
  color: #294766;
  font-size: 12px;
}

@media (max-width: 1050px) {
  .summary-grid {
    grid-template-columns: 1fr 1fr;
  }
  .history-tools {
    grid-template-columns: 1fr 1fr;
  }
  .search-box {
    grid-column: 1 / -1;
  }
  .active-main {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 720px) {
  .attendance-hero {
    align-items: flex-start;
    flex-direction: column;
    min-height: auto;
    padding: 20px;
  }

  .hero-copy h1 {
    font-size: 25px;
  }
  .hero-visual {
    display: none;
  }
  .hero-actions,
  .create-button {
    width: 100%;
  }
  .summary-grid {
    grid-template-columns: 1fr 1fr;
  }
  .summary-card {
    min-height: 100px;
    padding: 13px;
  }
  .summary-icon {
    width: 44px;
    height: 44px;
    flex-basis: 44px;
  }
  .summary-card b {
    font-size: 23px;
  }
  .active-main {
    grid-template-columns: 1fr;
  }
  .history-heading {
    align-items: flex-start;
    flex-direction: column;
  }
  .history-heading :deep(.p-button) {
    width: 100%;
  }
  .history-tools {
    grid-template-columns: 1fr;
  }
  .search-box {
    grid-column: auto;
  }
  .attendance-table {
    margin: 0 -16px;
  }
  .session-detail-grid {
    grid-template-columns: 1fr;
  }
}

/* Exact visual refinements matching the supplied target */
.attendance-page {
  gap: 20px;
}
.attendance-hero {
  min-height: 184px;
  padding: 26px 32px;
  background: linear-gradient(105deg, #fff 0%, #f4f9ff 52%, #effbf6 100%);
}
.hero-copy {
  flex: 1;
  min-width: 360px;
}
.hero-copy h1 {
  font-size: 34px;
  letter-spacing: -0.02em;
}
.hero-actions {
  min-width: 540px;
  justify-content: flex-end;
}
.create-button {
  min-width: 225px;
  height: 56px;
  font-size: 15px;
}
.hero-visual {
  width: 285px;
  height: 128px;
  flex: 0 0 285px;
  isolation: isolate;
}
.hero-blob {
  position: absolute;
  border-radius: 50%;
  background: #ddecff;
  z-index: -2;
}
.blob-one {
  width: 116px;
  height: 116px;
  left: 60px;
  top: 4px;
}
.blob-two {
  width: 89px;
  height: 89px;
  right: 25px;
  top: 24px;
  background: #dff7ee;
}
.hero-leaf {
  position: absolute;
  width: 42px;
  height: 74px;
  border-radius: 100% 0 100% 0;
  background: linear-gradient(145deg, #8de2c3, #42bd91);
  z-index: -1;
}
.leaf-one {
  left: 35px;
  bottom: 3px;
  transform: rotate(-28deg);
}
.leaf-two {
  right: 36px;
  top: 9px;
  transform: rotate(24deg);
}
.calendar-board {
  position: absolute;
  left: 78px;
  top: 19px;
  width: 112px;
  height: 100px;
  padding: 27px 13px 10px;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 14px 32px rgba(30, 91, 150, 0.18);
}
.calendar-board:before {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 25px;
  border-radius: 12px 12px 0 0;
  background: linear-gradient(90deg, #5faeff, #2d84ec);
}
.calendar-ring {
  position: absolute;
  top: -9px;
  width: 9px;
  height: 23px;
  border-radius: 8px;
  background: #397ecf;
  box-shadow: inset 0 -4px 0 rgba(255, 255, 255, 0.22);
}
.ring-one {
  left: 22px;
}
.ring-two {
  left: 52px;
}
.ring-three {
  right: 22px;
}
.calendar-row {
  height: 19px;
  display: grid;
  grid-template-columns: 18px 1fr;
  align-items: center;
  gap: 7px;
}
.calendar-row i {
  width: 16px;
  height: 16px;
  display: grid;
  place-items: center;
  border-radius: 4px;
  color: #fff;
  background: #3d91ed;
  font-size: 9px;
}
.calendar-row b {
  height: 6px;
  border-radius: 9px;
  background: #d9e9f8;
}
.check-badge {
  position: absolute;
  left: 166px;
  bottom: 0;
  width: 65px;
  height: 65px;
  display: grid;
  place-items: center;
  border: 8px solid #edf9f5;
  border-radius: 50%;
  color: #fff;
  background: #28b77f;
  box-shadow: 0 10px 24px rgba(22, 184, 132, 0.24);
  font-size: 25px;
}
.paper-card {
  position: absolute;
  right: 2px;
  bottom: 12px;
  width: 68px;
  height: 50px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 10px;
  border-radius: 10px;
  background: #fff;
  box-shadow: 0 10px 22px rgba(55, 95, 135, 0.13);
  color: #4a9cf2;
  font-size: 11px;
}
.summary-grid {
  gap: 14px;
}
.summary-card {
  min-height: 130px;
  padding: 20px 21px;
}
.summary-icon {
  width: 62px;
  height: 62px;
  flex-basis: 62px;
  font-size: 24px;
}
.summary-card small {
  font-size: 12px;
}
.summary-card b {
  font-size: 31px;
}
.history-card :deep(.p-card-body) {
  padding: 23px;
}
.history-tools {
  grid-template-columns: minmax(300px, 1fr) 255px 255px;
}
.attendance-table {
  border: 1px solid #dce7f2;
  border-radius: 12px;
  overflow: hidden;
}
.attendance-table :deep(.p-datatable-tbody > tr > td) {
  height: 59px;
}
.attendance-table :deep(.p-tag-secondary) {
  background: #e8edf2;
  color: #435a72;
}
.page-footer {
  padding-top: 8px;
}
@media (max-width: 1200px) {
  .hero-actions {
    min-width: 430px;
  }
  .hero-visual {
    width: 220px;
    flex-basis: 220px;
    transform: scale(0.85);
    transform-origin: right center;
  }
}
@media (max-width: 900px) {
  .hero-actions {
    min-width: auto;
  }
  .hero-visual {
    display: none;
  }
  .hero-copy {
    min-width: 0;
  }
  .create-button {
    min-width: 190px;
  }
}
@media (max-width: 720px) {
  .attendance-hero {
    padding: 20px;
  }
  .create-button {
    min-width: 0;
    height: 46px;
  }
  .summary-card {
    min-height: 105px;
  }
  .summary-icon {
    width: 46px;
    height: 46px;
    flex-basis: 46px;
  }
  .history-card :deep(.p-card-body) {
    padding: 16px;
  }
}
</style>
