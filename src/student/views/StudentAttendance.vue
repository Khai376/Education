<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'

import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'
import Card from 'primevue/card'
import Tag from 'primevue/tag'

import { publicRpc } from '../../services/supabase'

const router = useRouter()

const code = ref('')
const studentCode = ref('')
const studentName = ref('')

const result = ref(null)
const error = ref('')
const loading = ref(false)

/* =========================
   Navigation
========================= */

function goHome() {
  router.push('/student')
}

function goExam() {
  router.push('/student/exam')
}

/* =========================
   Attendance Code
========================= */

function numeric() {
  code.value = code.value
    .replace(/\D/g, '')
    .slice(0, 6)
}

/* =========================
   Submit
========================= */

async function submit() {
  error.value = ''

  const normalizedCode =
    code.value.trim()

  const normalizedStudentCode =
    studentCode.value.trim()

  const normalizedStudentName =
    studentName.value.trim()

  if (!/^\d{6}$/.test(normalizedCode)) {
    error.value =
      'กรุณากรอกรหัสเช็คชื่อเป็นตัวเลข 6 หลัก'
    return
  }

  if (!normalizedStudentCode) {
    error.value =
      'กรุณากรอกเลขประจำตัวนักเรียน'
    return
  }

  if (normalizedStudentCode.length > 50) {
    error.value =
      'เลขประจำตัวนักเรียนต้องไม่เกิน 50 ตัวอักษร'
    return
  }

  if (!normalizedStudentName) {
    error.value =
      'กรุณากรอกชื่อ - นามสกุล'
    return
  }

  if (normalizedStudentName.length > 120) {
    error.value =
      'ชื่อ - นามสกุลต้องไม่เกิน 120 ตัวอักษร'
    return
  }

  loading.value = true

  try {
    result.value = await publicRpc(
      'student_attendance_checkin',
      {
        p_code:
          normalizedCode,

        p_student_code:
          normalizedStudentCode,

        p_student_name:
          normalizedStudentName
      }
    )
  } catch (err) {
    console.error(
      'student_attendance_checkin:',
      err
    )

    error.value =
      err.message ||
      'ไม่สามารถเช็คชื่อได้'
  } finally {
    loading.value = false
  }
}

/* =========================
   Reset
========================= */

function reset() {
  code.value = ''
  studentCode.value = ''
  studentName.value = ''

  result.value = null
  error.value = ''
}
</script>

<template>
  <main class="attendance-page">

    <!-- =========================
         HEADER
    ========================== -->

    <header class="student-topbar">
      <button
        type="button"
        class="topbar-brand"
        @click="goHome"
      >
        <span class="topbar-logo">
          <i class="pi pi-graduation-cap"></i>
        </span>

        <span class="brand-copy">
          <b>Education Hub</b>
          <small>Student Portal</small>
        </span>
      </button>

      <nav class="topbar-actions">
        <button
          type="button"
          class="topbar-link"
          @click="goHome"
        >
          <i class="pi pi-home"></i>
          <span>หน้าหลัก</span>
        </button>

        <button
          type="button"
          class="topbar-link"
          @click="goExam"
        >
          <i class="pi pi-file-edit"></i>
          <span>ทำข้อสอบ</span>
        </button>
      </nav>
    </header>

    <!-- =========================
         CONTENT
    ========================== -->

    <section class="attendance-container">
      <Card class="attendance-card">

        <!-- Title -->

        <template #title>
          <div class="attendance-title">
            <div>
              <h2>เช็คชื่อ</h2>
              <small>Student Attendance</small>
            </div>

            <Tag
              value="STUDENT"
              severity="info"
            />
          </div>
        </template>

        <!-- Content -->

        <template #content>

          <!-- =========================
               FORM
          ========================== -->

          <section
            v-if="!result"
            class="attendance-form-section"
          >
            <div class="attendance-icon">
              <i class="pi pi-check-circle"></i>
            </div>

            <h1>เช็คชื่อเข้าเรียน</h1>

            <p class="attendance-description">
              ใส่รหัสเช็คชื่อ 6 หลัก
              ที่ได้รับจากคุณครู
            </p>

            <form
              class="attendance-form"
              @submit.prevent="submit"
            >

              <!-- Code -->

              <label class="field">
                <span>
                  รหัสเช็คชื่อ
                </span>

                <div class="code-wrapper">
                  <InputText
                    v-model="code"
                    inputmode="numeric"
                    pattern="[0-9]*"
                    maxlength="6"
                    autocomplete="one-time-code"
                    placeholder="000000"
                    class="code-input"
                    fluid
                    @input="numeric"
                  />

                  <div class="code-length">
                    {{ code.length }}/6
                  </div>
                </div>

                <small>
                  กรอกรหัสตัวเลข
                  6 หลักที่แสดงบนหน้าจอคุณครู
                </small>
              </label>

              <!-- Student ID -->

              <label class="field">
                <span>
                  เลขประจำตัวนักเรียน
                </span>

                <InputText
                  v-model="studentCode"
                  maxlength="50"
                  autocomplete="username"
                  placeholder="เช่น 65001"
                  fluid
                />
              </label>

              <!-- Name -->

              <label class="field">
                <span>
                  ชื่อ - นามสกุล
                </span>

                <InputText
                  v-model="studentName"
                  maxlength="120"
                  autocomplete="name"
                  placeholder="กรอกชื่อ - นามสกุล"
                  fluid
                />
              </label>

              <!-- Error -->

              <Message
                v-if="error"
                severity="error"
                :closable="true"
                @close="error = ''"
              >
                {{ error }}
              </Message>

              <!-- Submit -->

              <Button
                type="submit"
                label="เช็คชื่อเข้าเรียน"
                icon="pi pi-check"
                :loading="loading"
                :disabled="
                  loading ||
                  code.length !== 6
                "
                fluid
              />
            </form>

            <!-- Help -->

            <div class="help-box">
              <i class="pi pi-info-circle"></i>

              <div>
                <b>วิธีเช็คชื่อ</b>

                <span>
                  ขอรหัส 6 หลักจากคุณครู
                  จากนั้นกรอกรหัสนักเรียนและชื่อให้ถูกต้อง
                </span>
              </div>
            </div>
          </section>

          <!-- =========================
               SUCCESS
          ========================== -->

          <section
            v-else
            class="success-section"
          >
            <div class="success-icon">
              <i class="pi pi-check"></i>
            </div>

            <Tag
              :severity="
                result.status === 'late'
                  ? 'warn'
                  : 'success'
              "
              :value="
                result.status === 'late'
                  ? 'มาสาย'
                  : 'มาเรียน'
              "
            />

            <h1>
              เช็คชื่อสำเร็จ
            </h1>

            <p class="success-description">
              ระบบบันทึกการเข้าเรียนแล้ว
            </p>

            <!-- Student -->

            <div class="success-student">
              <div class="student-avatar">
                <i class="pi pi-user"></i>
              </div>

              <div>
                <small>
                  นักเรียน
                </small>

                <strong>
                  {{ result.studentName }}
                </strong>

                <span>
                  รหัส {{ studentCode }}
                </span>
              </div>
            </div>

            <!-- Details -->

            <div class="result-grid">
              <article>
                <span class="result-icon blue">
                  <i class="pi pi-book"></i>
                </span>

                <div>
                  <small>
                    วิชา / ห้องเรียน
                  </small>

                  <b>
                    {{ result.title || '-' }}
                  </b>
                </div>
              </article>

              <article>
                <span class="result-icon purple">
                  <i class="pi pi-calendar"></i>
                </span>

                <div>
                  <small>
                    วันที่
                  </small>

                  <b>
                    {{
                      result.sessionDate ||
                      '-'
                    }}
                  </b>
                </div>
              </article>

              <article>
                <span
                  class="result-icon"
                  :class="
                    result.status === 'late'
                      ? 'orange'
                      : 'green'
                  "
                >
                  <i class="pi pi-clock"></i>
                </span>

                <div>
                  <small>
                    สถานะ
                  </small>

                  <b>
                    {{
                      result.status === 'late'
                        ? 'มาสาย'
                        : 'มาเรียน'
                    }}
                  </b>
                </div>
              </article>
            </div>

            <!-- Confirmation -->

            <Message
              :severity="
                result.status === 'late'
                  ? 'warn'
                  : 'success'
              "
              :closable="false"
            >
              {{
                result.status === 'late'
                  ? 'บันทึกการเช็คชื่อเรียบร้อยแล้ว สถานะมาสาย'
                  : 'บันทึกการเช็คชื่อเรียบร้อยแล้ว'
              }}
            </Message>

            <!-- Actions -->

            <div class="success-actions">
              <Button
                type="button"
                label="กลับหน้าหลัก"
                icon="pi pi-home"
                outlined
                @click="goHome"
              />

              <Button
                type="button"
                label="ทำข้อสอบ"
                icon="pi pi-file-edit"
                @click="goExam"
              />

              <Button
                type="button"
                label="เช็คชื่อใหม่"
                icon="pi pi-refresh"
                severity="secondary"
                text
                @click="reset"
              />
            </div>
          </section>

        </template>
      </Card>
    </section>

    <!-- =========================
         FOOTER
    ========================== -->

    <footer class="student-footer">
      <div class="footer-brand">
        <i class="pi pi-graduation-cap"></i>
        <b>Education Hub</b>
      </div>

      <div class="footer-links">
        <button
          type="button"
          @click="goHome"
        >
          <i class="pi pi-home"></i>
          หน้าหลัก
        </button>

        <button
          type="button"
          @click="goExam"
        >
          <i class="pi pi-file-edit"></i>
          ทำข้อสอบ
        </button>
      </div>

      <small>
        Teach • Learn • Grow
      </small>
    </footer>

  </main>
</template>

<style scoped>
/* =========================
   PAGE
========================= */

.attendance-page {
  min-height: 100vh;

  background:
    radial-gradient(
      circle at top left,
      #e5f2ff,
      transparent 38%
    ),
    linear-gradient(
      180deg,
      #f7faff,
      #eef5fb
    );
}

/* =========================
   HEADER
========================= */

.student-topbar {
  width: 100%;
  height: 68px;

  display: flex;
  align-items: center;
  justify-content: space-between;

  padding: 0 28px;

  border-bottom:
    1px solid #dce7f2;

  background:
    rgba(255, 255, 255, 0.96);

  box-shadow:
    0 2px 12px
    rgba(30, 60, 95, 0.04);
}

.topbar-brand {
  display: flex;
  align-items: center;

  gap: 10px;

  padding: 0;

  border: 0;

  background: transparent;

  color: #10264b;

  text-align: left;

  cursor: pointer;
}

.topbar-logo {
  width: 40px;
  height: 40px;

  display: grid;
  place-items: center;

  border-radius: 11px;

  color: #ffffff;

  background:
    linear-gradient(
      135deg,
      #1683ff,
      #1769d7
    );
}

.topbar-logo i {
  font-size: 19px;
}

.brand-copy b,
.brand-copy small {
  display: block;
}

.brand-copy b {
  font-size: 15px;
}

.brand-copy small {
  margin-top: 1px;

  color: #8392a8;

  font-size: 9px;
}

.topbar-actions {
  display: flex;
  align-items: center;

  gap: 7px;
}

.topbar-link {
  display: inline-flex;
  align-items: center;

  gap: 7px;

  padding: 8px 12px;

  border:
    1px solid #d7e4f0;

  border-radius: 9px;

  color: #45617f;

  background: #ffffff;

  font-size: 11px;
  font-weight: 700;

  cursor: pointer;
}

.topbar-link:hover {
  color: #167df5;

  border-color: #91c5ff;

  background: #f3f8ff;
}

/* =========================
   CONTENT
========================= */

.attendance-container {
  width: min(
    620px,
    100%
  );

  margin: 0 auto;

  padding:
    35px
    20px
    45px;
}

.attendance-card {
  width: 100%;
}

.attendance-title {
  display: flex;
  align-items: center;
  justify-content: space-between;

  gap: 12px;
}

.attendance-title h2 {
  margin: 0;

  color: #10264b;

  font-size: 22px;
}

.attendance-title small {
  color: #8291a8;

  font-size: 11px;
}

/* =========================
   FORM
========================= */

.attendance-form-section {
  padding:
    20px
    0
    8px;

  text-align: center;
}

.attendance-icon {
  width: 72px;
  height: 72px;

  display: grid;
  place-items: center;

  margin:
    0
    auto
    16px;

  border-radius: 20px;

  color: #0aa575;

  background: #e5faf2;
}

.attendance-icon i {
  font-size: 35px;
}

.attendance-form-section h1 {
  margin:
    0
    0
    5px;

  color: #10264b;

  font-size: 26px;
}

.attendance-description {
  margin: 0;

  color: #7789a2;

  font-size: 13px;
}

.attendance-form {
  display: grid;

  gap: 16px;

  margin-top: 27px;

  text-align: left;
}

.field {
  display: grid;

  gap: 7px;
}

.field > span {
  color: #294766;

  font-size: 13px;
  font-weight: 700;
}

.field > small {
  color: #8a99ad;

  font-size: 10px;
}

/* Code */

.code-wrapper {
  position: relative;
}

.code-input {
  width: 100%;

  padding-right:
    52px !important;

  text-align: center;

  color:
    #10264b !important;

  font-size:
    28px !important;

  font-weight:
    800 !important;

  letter-spacing:
    0.28em;
}

.code-length {
  position: absolute;
  top: 50%;
  right: 12px;

  transform:
    translateY(-50%);

  padding:
    3px
    6px;

  border-radius: 6px;

  color: #8291a8;

  background: #f2f6fa;

  font-size: 9px;
}

/* Help */

.help-box {
  display: flex;

  gap: 10px;

  margin-top: 20px;

  padding: 12px 14px;

  border-radius: 10px;

  color: #56718f;

  background: #f1f7fd;

  text-align: left;
}

.help-box > i {
  color: #167df5;

  margin-top: 2px;
}

.help-box b,
.help-box span {
  display: block;
}

.help-box b {
  font-size: 11px;
}

.help-box span {
  margin-top: 2px;

  font-size: 9px;

  line-height: 1.5;
}

/* =========================
   SUCCESS
========================= */

.success-section {
  min-height: 480px;

  display: flex;
  flex-direction: column;
  align-items: center;

  padding:
    28px
    0
    10px;

  text-align: center;
}

.success-icon {
  width: 86px;
  height: 86px;

  display: grid;
  place-items: center;

  margin-bottom: 14px;

  border-radius: 50%;

  color: #10a978;

  background: #e4faf1;
}

.success-icon i {
  font-size: 43px;
}

.success-section h1 {
  margin:
    13px
    0
    3px;

  color: #10264b;
}

.success-description {
  margin:
    0
    0
    20px;

  color: #8090a5;

  font-size: 11px;
}

/* Student */

.success-student {
  width: 100%;

  display: flex;
  align-items: center;

  gap: 12px;

  padding: 14px;

  margin-bottom: 12px;

  border:
    1px solid #dbe7f2;

  border-radius: 12px;

  background: #ffffff;

  text-align: left;
}

.student-avatar {
  width: 46px;
  height: 46px;

  flex: 0 0 46px;

  display: grid;
  place-items: center;

  border-radius: 50%;

  color: #167df5;

  background: #e7f2ff;
}

.success-student small,
.success-student strong,
.success-student span {
  display: block;
}

.success-student small {
  color: #8a99ad;

  font-size: 9px;
}

.success-student strong {
  margin-top: 1px;

  color: #173757;

  font-size: 16px;
}

.success-student span {
  margin-top: 2px;

  color: #7588a1;

  font-size: 10px;
}

/* Result */

.result-grid {
  width: 100%;

  display: grid;

  gap: 8px;

  margin-bottom: 15px;
}

.result-grid article {
  display: flex;
  align-items: center;

  gap: 11px;

  padding: 12px 13px;

  border-radius: 10px;

  background: #f7f9fc;

  text-align: left;
}

.result-icon {
  width: 36px;
  height: 36px;

  flex: 0 0 36px;

  display: grid;
  place-items: center;

  border-radius: 9px;
}

.result-icon.blue {
  color: #1683ff;
  background: #e6f2ff;
}

.result-icon.purple {
  color: #7c4dff;
  background: #f0eaff;
}

.result-icon.green {
  color: #0aa575;
  background: #e5faf2;
}

.result-icon.orange {
  color: #ef8b00;
  background: #fff1df;
}

.result-grid small,
.result-grid b {
  display: block;
}

.result-grid small {
  color: #8998ab;

  font-size: 9px;
}

.result-grid b {
  margin-top: 2px;

  color: #294766;

  font-size: 12px;
}

.success-section
:deep(.p-message) {
  width: 100%;
}

/* Actions */

.success-actions {
  width: 100%;

  display: grid;

  grid-template-columns:
    1fr
    1fr;

  gap: 8px;

  margin-top: 18px;
}

.success-actions
:deep(.p-button) {
  width: 100%;
}

.success-actions
:deep(.p-button:last-child) {
  grid-column:
    1 / -1;
}

/* =========================
   FOOTER
========================= */

.student-footer {
  width: min(
    620px,
    calc(100% - 40px)
  );

  margin: 0 auto;

  padding:
    22px
    0
    26px;

  border-top:
    1px solid #dce7f2;

  text-align: center;

  color: #7b8ba0;
}

.footer-brand {
  display: flex;
  align-items: center;
  justify-content: center;

  gap: 7px;

  color: #45617f;

  font-size: 13px;
}

.footer-brand i {
  color: #1683ff;

  font-size: 16px;
}

.footer-links {
  display: flex;
  justify-content: center;

  gap: 8px;

  margin:
    12px
    0;
}

.footer-links button {
  display: inline-flex;
  align-items: center;

  gap: 6px;

  padding:
    7px
    11px;

  border: 0;

  border-radius: 8px;

  color: #607590;

  background: transparent;

  font-size: 11px;
  font-weight: 700;

  cursor: pointer;
}

.footer-links button:hover {
  color: #167df5;

  background: #eaf4ff;
}

.student-footer > small {
  display: block;

  color: #9aa8ba;

  font-size: 9px;

  letter-spacing: 0.04em;
}

/* =========================
   MOBILE
========================= */

@media (max-width: 640px) {
  .student-topbar {
    height: 60px;

    padding:
      0
      14px;
  }

  .topbar-logo {
    width: 36px;
    height: 36px;
  }

  .brand-copy b {
    font-size: 13px;
  }

  .topbar-actions {
    gap: 3px;
  }

  .topbar-link {
    width: 38px;
    height: 38px;

    justify-content: center;

    padding: 0;
  }

  .topbar-link span {
    display: none;
  }

  .attendance-container {
    padding:
      16px
      12px
      28px;
  }

  .attendance-title h2 {
    font-size: 19px;
  }

  .attendance-form-section h1 {
    font-size: 22px;
  }

  .code-input {
    font-size:
      24px !important;

    letter-spacing:
      0.2em;
  }

  .success-actions {
    grid-template-columns: 1fr;
  }

  .success-actions
  :deep(.p-button:last-child) {
    grid-column: auto;
  }

  .student-footer {
    width:
      calc(100% - 28px);

    padding:
      18px
      0
      22px;
  }
}
</style>