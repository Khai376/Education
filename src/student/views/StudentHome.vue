<script setup>
import { computed, onMounted, onUnmounted, ref } from "vue";
import { useRouter } from "vue-router";
import Button from "primevue/button";
import InputText from "primevue/inputtext";
import Card from "primevue/card";
import Message from "primevue/message";
import ProgressBar from "primevue/progressbar";
import Tag from "primevue/tag";
import { publicRpc } from "../../services/supabase";

const router = useRouter();
const labels = ["ก", "ข", "ค", "ง", "จ", "ฉ"];

const info = ref(null);
const token = ref(localStorage.getItem("examAttemptToken"));
const joinedSessionId = ref(localStorage.getItem("examSessionId"));
const studentId = ref(localStorage.getItem("examStudentId") || "");
const studentName = ref(localStorage.getItem("examStudentName") || "");
const state = ref(null);
const error = ref("");
const notice = ref("");
const loadingInfo = ref(false);
const joining = ref(false);
const answering = ref(false);
const displayRemainingSeconds = ref(0);

let poll = null;
let countdownTimer = null;
let refreshing = false;
let lastQuestionKey = "";

const progress = computed(() => {
  const total = Number(state.value?.total || 0);
  const current = Number(state.value?.currentNumber || 0);
  return total > 0
    ? Math.min(100, Math.max(0, Math.round((current / total) * 100)))
    : 0;
});

const examStatusText = computed(() => {
  if (!state.value) return "";
  if (state.value.status === "finished")
    return `จบการติว ${state.value.total || 0} ข้อ`;
  return `ข้อ ${state.value.currentNumber || 0} จาก ${state.value.total || 0}`;
});

const remainingTimeText = computed(() => {
  const value = Math.max(0, Number(displayRemainingSeconds.value || 0));
  const minutes = Math.floor(value / 60);
  const seconds = value % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
});

const hasActiveSession = computed(() => Boolean(info.value?.sessionId));
const locallyExpired = computed(() => {
  return (
    state.value?.status === "live" &&
    !state.value?.answered &&
    Number(state.value?.currentNumber || 0) > 0 &&
    displayRemainingSeconds.value <= 0
  );
});

function goHome() {
  router.push("/student");
}
function goAttendance() {
  router.push("/student/attendance");
}
function syncCountdown(seconds) {
  const next = Math.max(0, Number(seconds || 0));
  const drift = Math.abs(next - displayRemainingSeconds.value);
  if (displayRemainingSeconds.value === 0 || drift >= 2)
    displayRemainingSeconds.value = next;
}

async function loadInfo({ silent = false } = {}) {
  if (!silent) loadingInfo.value = true;
  try {
    const result = await publicRpc("student_active_session_info");
    info.value = result || null;
    return info.value;
  } catch (err) {
    info.value = null;
    const message = String(err.message || "");
    if (!message.toLowerCase().includes("no rows"))
      error.value = message || "ไม่สามารถตรวจสอบรอบการติวได้";
    return null;
  } finally {
    if (!silent) loadingInfo.value = false;
  }
}

async function loadCountdown() {
  if (!token.value) return null;
  try {
    const data = await publicRpc("student_countdown_info", {
      p_token: token.value,
    });
    if (
      data?.sessionId &&
      joinedSessionId.value &&
      String(data.sessionId) !== String(joinedSessionId.value)
    ) {
      const latest = await loadInfo({ silent: true });
      clearAttempt();
      info.value = latest;
      notice.value = "คุณครูเปิดรอบใหม่แล้ว กรุณาเข้าร่วมรอบใหม่";
      return null;
    }
    syncCountdown(data?.remainingSeconds);
    return data;
  } catch (err) {
    console.error("student_countdown_info:", err);
    return null;
  }
}

async function join() {
  error.value = "";
  notice.value = "";
  const id = studentId.value.trim();
  const name = studentName.value.trim();
  if (!id) return (error.value = "กรุณากรอกเลขประจำตัวนักเรียน");
  if (!name) return (error.value = "กรุณากรอกชื่อ - นามสกุล");
  joining.value = true;
  try {
    const active = await loadInfo({ silent: true });
    if (!active?.sessionId) throw new Error("ยังไม่มีรอบการติวที่เปิดอยู่");
    const result = await publicRpc("student_join", {
      p_student_id: id,
      p_student_name: name,
    });
    if (!result?.token) throw new Error("ระบบไม่ได้รับ Token สำหรับทำข้อสอบ");
    token.value = String(result.token);
    joinedSessionId.value = String(active.sessionId);
    localStorage.setItem("examAttemptToken", token.value);
    localStorage.setItem("examSessionId", joinedSessionId.value);
    localStorage.setItem("examStudentId", id);
    localStorage.setItem("examStudentName", name);
    await loadStudentState();
    await loadCountdown();
    startCountdown();
    startPoll();
  } catch (err) {
    error.value = err.message || "ไม่สามารถเข้าร่วมการติวได้";
  } finally {
    joining.value = false;
  }
}

function applyState(result) {
  if (!result) return;
  const nextKey = `${result.status}|${result.currentNumber}|${result.answered}|${result.score}`;
  if (nextKey !== lastQuestionKey) {
    state.value = result;
    lastQuestionKey = nextKey;
  } else if (state.value) {
    Object.assign(state.value, result);
  }
}

async function loadStudentState() {
  if (!token.value) return null;
  try {
    const result = await publicRpc("student_state", { p_token: token.value });
    applyState(result);
    if (result?.sessionId && !joinedSessionId.value) {
      joinedSessionId.value = String(result.sessionId);
      localStorage.setItem("examSessionId", joinedSessionId.value);
    }
    return result;
  } catch (err) {
    if (/ไม่พบ|invalid token|token.*invalid|expired/i.test(err.message || "")) {
      clearAttempt();
      await loadInfo();
      notice.value = "รอบเดิมสิ้นสุดแล้ว กรุณาเข้าร่วมรอบใหม่";
      return null;
    }
    throw err;
  }
}

async function refresh() {
  if (refreshing || !token.value) return;
  refreshing = true;
  try {
    const active = await loadInfo({ silent: true });
    if (
      active?.sessionId &&
      joinedSessionId.value &&
      String(active.sessionId) !== String(joinedSessionId.value)
    ) {
      clearAttempt();
      info.value = active;
      notice.value = "คุณครูเปิดรอบใหม่แล้ว กรุณาเข้าร่วมรอบใหม่";
      return;
    }
    const result = await loadStudentState();
    if (!result) return;
    await loadCountdown();
    error.value = "";
  } catch (err) {
    error.value = err.message || "ไม่สามารถโหลดสถานะข้อสอบได้";
  } finally {
    refreshing = false;
  }
}

async function answer(index) {
  if (answering.value || state.value?.answered || locallyExpired.value) return;
  answering.value = true;
  error.value = "";
  try {
    await publicRpc("student_answer", {
      p_token: token.value,
      p_choice: index,
    });
    await refresh();
  } catch (err) {
    error.value = err.message || "ไม่สามารถส่งคำตอบได้";
  } finally {
    answering.value = false;
  }
}

function startPoll() {
  stopPoll();
  poll = window.setInterval(refresh, 2000);
}
function stopPoll() {
  if (poll) window.clearInterval(poll);
  poll = null;
}
function startCountdown() {
  stopCountdown();
  countdownTimer = window.setInterval(() => {
    if (
      state.value?.status === "live" &&
      !state.value?.answered &&
      displayRemainingSeconds.value > 0
    ) {
      displayRemainingSeconds.value--;
    }
  }, 1000);
}
function stopCountdown() {
  if (countdownTimer) window.clearInterval(countdownTimer);
  countdownTimer = null;
}
function clearAttempt() {
  stopPoll();
  stopCountdown();
  localStorage.removeItem("examAttemptToken");
  localStorage.removeItem("examSessionId");
  token.value = null;
  joinedSessionId.value = null;
  state.value = null;
  answering.value = false;
  lastQuestionKey = "";
  displayRemainingSeconds.value = 0;
}
async function reset() {
  clearAttempt();
  error.value = "";
  notice.value = "";
  await loadInfo();
}

onMounted(async () => {
  await loadInfo();
  startCountdown();
  if (token.value) {
    await refresh();
    if (token.value) startPoll();
  }
});
onUnmounted(() => {
  stopPoll();
  stopCountdown();
});
</script>

<template>
  <main class="exam-public">
    <header class="student-topbar">
      <button type="button" class="topbar-brand" @click="goHome">
        <span class="topbar-logo"><i class="pi pi-graduation-cap"></i></span>
        <span class="brand-copy"
          ><b>Education Hub</b><small>Student Portal</small></span
        >
      </button>
      <nav class="topbar-actions">
        <button type="button" class="topbar-link" @click="goHome">
          <i class="pi pi-home"></i><span>หน้าหลัก</span>
        </button>
        <button type="button" class="topbar-link" @click="goAttendance">
          <i class="pi pi-check-circle"></i><span>เช็คชื่อ</span>
        </button>
      </nav>
    </header>

    <section class="exam-container">
      <Card class="exam-card">
        <template #title>
          <div class="exam-title">
            <div>
              <h2>ทำข้อสอบ</h2>
              <small>Exam Tutor</small>
            </div>
            <Tag value="STUDENT" severity="info" />
          </div>
        </template>
        <template #content>
          <Message
            v-if="notice"
            severity="info"
            closable
            @close="notice = ''"
            >{{ notice }}</Message
          >
          <Message v-if="error" severity="error" closable @close="error = ''">{{
            error
          }}</Message>

          <section v-if="!token" class="join-exam">
            <div class="join-icon"><i class="pi pi-file-edit"></i></div>
            <h1>เข้าร่วมทำข้อสอบ</h1>
            <template v-if="info">
              <p class="exam-name">{{ info.title }}</p>
              <div class="exam-info">
                <span
                  ><i class="pi pi-list"></i>
                  {{ info.questionCount || 0 }} ข้อ</span
                ><span
                  ><i class="pi pi-clock"></i>
                  {{
                    info.status === "live" ? "กำลังติว" : "รอเริ่มการติว"
                  }}</span
                >
              </div>
            </template>
            <p v-else-if="loadingInfo" class="muted">
              กำลังตรวจสอบรอบการติว...
            </p>
            <Message v-else severity="warn" :closable="false"
              >ยังไม่มีรอบการติวที่เปิดอยู่</Message
            >
            <form class="exam-form" @submit.prevent="join">
              <label
                ><span>เลขประจำตัวนักเรียน</span
                ><InputText v-model="studentId" maxlength="50" fluid
              /></label>
              <label
                ><span>ชื่อ - นามสกุล</span
                ><InputText v-model="studentName" maxlength="120" fluid
              /></label>
              <Button
                type="submit"
                label="เริ่มทำข้อสอบ"
                icon="pi pi-arrow-right"
                icon-pos="right"
                :loading="joining"
                :disabled="!hasActiveSession"
                fluid
              />
            </form>
          </section>

          <section v-else-if="state" class="play-exam">
            <div class="play-head">
              <div>
                <small>ความคืบหน้า</small><b>{{ examStatusText }}</b>
              </div>
              <Tag
                :severity="
                  state.status === 'finished' ? 'secondary' : 'success'
                "
                :value="state.status === 'finished' ? 'FINISHED' : 'LIVE'"
              />
            </div>
            <ProgressBar :value="progress" :show-value="false" />

            <div
              v-if="state.status === 'waiting' || state.currentNumber === 0"
              class="exam-state"
            >
              <div class="state-icon">
                <i class="pi pi-spin pi-spinner"></i>
              </div>
              <h2>เข้าร่วมแล้ว</h2>
              <p>รอคุณครูเริ่มข้อ 1...</p>
            </div>
            <div
              v-else-if="state.status === 'finished'"
              class="exam-state success"
            >
              <div class="state-icon success"><i class="pi pi-trophy"></i></div>
              <h2>จบการติวแล้ว</h2>
              <p>คะแนนของคุณ</p>
              <strong class="final-score"
                >{{ state.score || 0 }} / {{ state.total || 0 }}</strong
              ><Button label="ออกจากรอบ" outlined @click="reset" />
            </div>
            <div
              v-else-if="state.answered"
              class="exam-state"
              :class="state.correct ? 'success' : 'wrong'"
            >
              <div
                class="state-icon"
                :class="state.correct ? 'success' : 'wrong'"
              >
                <i
                  :class="[
                    'pi',
                    state.correct ? 'pi-check-circle' : 'pi-times-circle',
                  ]"
                ></i>
              </div>
              <h2>
                {{
                  state.correct
                    ? "ถูกต้อง! เก่งมาก 🎉"
                    : "ยังไม่ถูก ลุยข้อต่อไปนะ"
                }}
              </h2>
              <p class="correct-answer">
                เฉลย
                <b
                  >{{ labels[Number(state.correctChoice)] || "-" }}
                  {{ state.correctText || "" }}</b
                >
              </p>
              <small>รอคุณครูส่งข้อถัดไป...</small>
            </div>
            <div v-else-if="locallyExpired" class="exam-state wrong">
              <div class="state-icon wrong"><i class="pi pi-clock"></i></div>
              <h2>หมดเวลาข้อนี้แล้ว</h2>
              <p>รอคุณครูส่งข้อถัดไป...</p>
            </div>
            <div v-else class="question-play">
              <div
                class="timer"
                :class="{ warning: displayRemainingSeconds <= 10 }"
              >
                <span><i class="pi pi-clock"></i> เวลาที่เหลือ</span
                ><b>{{ remainingTimeText }}</b>
              </div>
              <div class="question-number">ข้อ {{ state.currentNumber }}</div>
              <h2 class="question-text">{{ state.text }}</h2>
              <div class="answers">
                <Button
                  v-for="(choice, index) in state.choices"
                  :key="index"
                  type="button"
                  outlined
                  severity="secondary"
                  :disabled="answering"
                  @click="answer(index)"
                  ><b class="answer-label">{{ labels[index] }}</b
                  ><span>{{ choice }}</span></Button
                >
              </div>
            </div>
          </section>

          <section v-else class="exam-state">
            <div class="state-icon"><i class="pi pi-spin pi-spinner"></i></div>
            <p>กำลังโหลดข้อสอบ...</p>
          </section>
        </template>
      </Card>
    </section>

    <footer class="student-footer">
      <div class="footer-brand">
        <i class="pi pi-graduation-cap"></i><b>Education Hub</b>
      </div>
      <div class="footer-links">
        <button type="button" @click="goHome">
          <i class="pi pi-home"></i> หน้าหลัก</button
        ><button type="button" @click="goAttendance">
          <i class="pi pi-check-circle"></i> เช็คชื่อ
        </button>
      </div>
      <small>Teach • Learn • Grow</small>
    </footer>
  </main>
</template>

<style scoped>
.exam-public {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, #e5f2ff, transparent 38%),
    linear-gradient(180deg, #f7faff, #eef5fb);
}
.student-topbar {
  height: 68px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 28px;
  border-bottom: 1px solid #dce7f2;
  background: #fffffff5;
}
.topbar-brand,
.topbar-link {
  display: flex;
  align-items: center;
  gap: 10px;
  border: 0;
  background: transparent;
  color: #10264b;
  cursor: pointer;
}
.topbar-logo {
  width: 40px;
  height: 40px;
  display: grid;
  place-items: center;
  border-radius: 11px;
  color: #fff;
  background: linear-gradient(135deg, #1683ff, #1769d7);
}
.brand-copy b,
.brand-copy small {
  display: block;
  text-align: left;
}
.brand-copy small {
  font-size: 9px;
  color: #8392a8;
}
.topbar-actions {
  display: flex;
  gap: 7px;
}
.topbar-link {
  padding: 8px 12px;
  border: 1px solid #d7e4f0;
  border-radius: 9px;
  background: #fff;
  font-size: 11px;
  font-weight: 700;
}
.exam-container {
  width: min(800px, 100%);
  margin: auto;
  padding: 35px 20px 45px;
}
.exam-title,
.play-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.exam-title h2 {
  margin: 0;
  color: #10264b;
}
.exam-title small,
.play-head small {
  color: #8291a8;
}
.join-exam {
  text-align: center;
  padding: 24px 0;
}
.join-icon {
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
  margin: 0 auto 15px;
  border-radius: 18px;
  color: #1683ff;
  background: #e6f2ff;
}
.exam-info {
  display: flex;
  justify-content: center;
  gap: 8px;
  margin: 12px;
}
.exam-info span {
  padding: 6px 10px;
  border-radius: 999px;
  background: #f1f6fb;
  font-size: 10px;
}
.exam-form {
  width: min(460px, 100%);
  display: grid;
  gap: 15px;
  margin: 25px auto 0;
  text-align: left;
}
.exam-form label {
  display: grid;
  gap: 7px;
  font-weight: 700;
}
.exam-state {
  min-height: 380px;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 11px;
  text-align: center;
}
.state-icon {
  width: 80px;
  height: 80px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #1683ff;
  background: #e8f3ff;
}
.state-icon i {
  font-size: 40px;
}
.state-icon.success {
  color: #10a978;
  background: #e4faf1;
}
.state-icon.wrong {
  color: #ef4444;
  background: #ffeded;
}
.final-score {
  font-size: 45px;
  color: #10264b;
}
.question-play {
  padding-top: 20px;
}
.timer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 13px 16px;
  border-radius: 11px;
  color: #fff;
  background: #102b52;
}
.timer.warning {
  background: #dc2626;
}
.question-number {
  display: inline-block;
  margin-top: 22px;
  padding: 5px 10px;
  border-radius: 999px;
  color: #167df5;
  background: #e7f2ff;
  font-weight: 800;
}
.question-text {
  margin: 12px 0 23px;
  color: #10264b;
}
.answers {
  display: grid;
  gap: 11px;
}
.answers :deep(.p-button) {
  width: 100%;
  justify-content: flex-start;
  padding: 15px 16px;
  text-align: left;
}
.answer-label {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  margin-right: 12px;
  border-radius: 9px;
  color: #167df5;
  background: #e7f2ff;
}
.student-footer {
  width: min(800px, calc(100% - 40px));
  margin: auto;
  padding: 22px 0 26px;
  border-top: 1px solid #dce7f2;
  text-align: center;
}
.footer-brand,
.footer-links {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
}
.footer-links {
  margin: 12px;
}
.footer-links button {
  border: 0;
  background: transparent;
  color: #607590;
  cursor: pointer;
}
@media (max-width: 640px) {
  .student-topbar {
    height: 60px;
    padding: 0 14px;
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
  .exam-container {
    padding: 16px 12px 30px;
  }
  .exam-state {
    min-height: 330px;
  }
  .question-text {
    font-size: 19px;
  }
}
</style>
