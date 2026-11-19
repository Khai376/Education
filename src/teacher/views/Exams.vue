<script setup>
import { computed, onMounted, onUnmounted, ref } from "vue";
import { useRouter } from "vue-router";
import Button from "primevue/button";
import InputText from "primevue/inputtext";
import InputNumber from "primevue/inputnumber";
import RadioButton from "primevue/radiobutton";
import Tabs from "primevue/tabs";
import TabList from "primevue/tablist";
import Tab from "primevue/tab";
import TabPanels from "primevue/tabpanels";
import TabPanel from "primevue/tabpanel";
import DataTable from "primevue/datatable";
import Column from "primevue/column";
import Tag from "primevue/tag";
import Message from "primevue/message";
import Card from "primevue/card";
import { rpc } from "../../services/supabase";

const router = useRouter();
const labels = ["ก", "ข", "ค", "ง", "จ", "ฉ"];
const activeTab = ref("control");
const title = ref("ชุดติวข้อสอบ");
const duration = ref(2);
const questions = ref([]);
const control = ref(null);
const results = ref([]);
const message = ref("");
const successMessage = ref("");
const busy = ref(false);
const loading = ref(false);
const displayRemainingSeconds = ref(0);
const resultSearch = ref("");
const resultStatus = ref("all");

const filteredResults = computed(() => {
  const term = resultSearch.value.trim().toLowerCase();
  return results.value.filter((row) => {
    const matchesSearch =
      !term ||
      String(row.studentId || "")
        .toLowerCase()
        .includes(term) ||
      String(row.studentName || "")
        .toLowerCase()
        .includes(term);
    const matchesStatus =
      resultStatus.value === "all" ||
      (resultStatus.value === "finished" ? row.finished : !row.finished);
    return matchesSearch && matchesStatus;
  });
});
const finishedCount = computed(
  () => results.value.filter((r) => r.finished).length,
);
const workingCount = computed(() => results.value.length - finishedCount.value);
const averageScore = computed(() => {
  if (!results.value.length) return "0.0";
  const avg =
    results.value.reduce((sum, r) => sum + Number(r.score || 0), 0) /
    results.value.length;
  return avg.toFixed(1);
});
const completionRate = computed(() =>
  results.value.length
    ? Math.round((finishedCount.value / results.value.length) * 100)
    : 0,
);

let pollTimer = null;
let countdownTimer = null;
let loadingPromise = null;
let lastControlKey = "";

const timeText = computed(() => {
  const value = Math.max(0, Number(displayRemainingSeconds.value || 0));
  return `${String(Math.floor(value / 60)).padStart(2, "0")}:${String(value % 60).padStart(2, "0")}`;
});

const timeDanger = computed(() => {
  return (
    control.value?.sessionStatus === "live" &&
    displayRemainingSeconds.value <= 10
  );
});

function blank() {
  return {
    text: `คำถามข้อ ${questions.value.length + 1}`,
    choices: ["ตัวเลือก ก", "ตัวเลือก ข", "ตัวเลือก ค", "ตัวเลือก ง"],
    correct: 0,
  };
}

function statusText(status) {
  return (
    {
      none: "ยังไม่มีรอบ",
      waiting: "รอเริ่ม",
      live: "กำลังติว",
      finished: "จบแล้ว",
    }[status] ||
    status ||
    "-"
  );
}

function applyControl(next) {
  if (!next) {
    control.value = null;
    displayRemainingSeconds.value = 0;
    lastControlKey = "";
    return;
  }

  const key = `${next.sessionStatus}|${next.currentPosition}|${next.answeredCount}|${next.correctCount}|${next.wrongCount}`;
  if (!control.value || key !== lastControlKey) {
    control.value = next;
    lastControlKey = key;
  } else {
    Object.assign(control.value, next);
  }

  const serverSeconds = Math.max(0, Number(next.remainingSeconds || 0));
  const drift = Math.abs(serverSeconds - displayRemainingSeconds.value);
  if (displayRemainingSeconds.value === 0 || drift >= 2) {
    displayRemainingSeconds.value = serverSeconds;
  }
}

async function load({ silent = false } = {}) {
  if (loadingPromise) return loadingPromise;

  loadingPromise = (async () => {
    if (!silent) loading.value = true;
    try {
      const [examData, controlData, resultData] = await Promise.all([
        rpc("teacher_exam_get"),
        rpc("teacher_control_state"),
        rpc("teacher_results"),
      ]);

      if (examData) {
        title.value = examData.title || "ชุดติวข้อสอบ";
        duration.value = Number(examData.durationMinutes || 2);
        if (!questions.value.length || !silent) {
          questions.value = examData.questions || [];
        }
      } else if (!questions.value.length) {
        questions.value = [blank()];
      }

      applyControl(controlData);
      results.value = resultData || [];
      message.value = "";
    } catch (err) {
      message.value = err.message || "ไม่สามารถโหลดข้อมูลข้อสอบได้";
    } finally {
      if (!silent) loading.value = false;
      loadingPromise = null;
    }
  })();

  return loadingPromise;
}

function addQuestion() {
  questions.value.push(blank());
}

function removeQuestion(index) {
  if (questions.value.length <= 1) {
    message.value = "ต้องมีคำถามอย่างน้อย 1 ข้อ";
    return;
  }
  questions.value.splice(index, 1);
}

function addChoice(question) {
  if (question.choices.length < 6) question.choices.push("ตัวเลือกใหม่");
}

function removeChoice(question, index) {
  if (question.choices.length <= 2) return;
  question.choices.splice(index, 1);
  if (question.correct >= question.choices.length) question.correct = 0;
}

function validateExam() {
  if (!title.value.trim()) return "กรุณากรอกชื่อชุดข้อสอบ";
  if (!Number(duration.value) || duration.value < 1 || duration.value > 60)
    return "เวลาต่อข้อต้องอยู่ระหว่าง 1-60 นาที";
  if (!questions.value.length) return "ต้องมีคำถามอย่างน้อย 1 ข้อ";

  for (let i = 0; i < questions.value.length; i += 1) {
    const q = questions.value[i];
    if (!q.text?.trim()) return `กรุณากรอกคำถามข้อ ${i + 1}`;
    if (!Array.isArray(q.choices) || q.choices.length < 2)
      return `ข้อ ${i + 1} ต้องมีอย่างน้อย 2 ตัวเลือก`;
    if (q.choices.some((choice) => !String(choice).trim()))
      return `ข้อ ${i + 1} มีตัวเลือกว่าง`;
  }
  return "";
}

async function action(functionName, args = {}, success = "") {
  if (busy.value) return;
  busy.value = true;
  message.value = "";
  successMessage.value = "";
  try {
    await rpc(functionName, args);
    await load({ silent: true });
    successMessage.value = success;
  } catch (err) {
    message.value = err.message || "ไม่สามารถดำเนินการได้";
  } finally {
    busy.value = false;
  }
}

async function save() {
  const validation = validateExam();
  if (validation) {
    message.value = validation;
    return;
  }

  await action(
    "teacher_exam_save",
    {
      payload: {
        title: title.value.trim(),
        durationMinutes: Number(duration.value),
        questions: questions.value.map((q, index) => ({
          text: q.text.trim(),
          choices: q.choices.map((choice) => String(choice).trim()),
          correct: Number(q.correct),
          position: index,
        })),
      },
    },
    "บันทึกชุดข้อสอบเรียบร้อยแล้ว",
  );
}

function openStudentExam() {
  const route = router.resolve("/student/exam");
  window.open(route.href, "_blank", "noopener,noreferrer");
}

function startCountdown() {
  stopCountdown();
  countdownTimer = window.setInterval(() => {
    if (
      control.value?.sessionStatus === "live" &&
      displayRemainingSeconds.value > 0
    ) {
      displayRemainingSeconds.value -= 1;
    }
  }, 1000);
}

function stopCountdown() {
  if (countdownTimer) window.clearInterval(countdownTimer);
  countdownTimer = null;
}

function startPoll() {
  stopPoll();
  pollTimer = window.setInterval(() => load({ silent: true }), 2500);
}

function stopPoll() {
  if (pollTimer) window.clearInterval(pollTimer);
  pollTimer = null;
}

onMounted(async () => {
  await load();
  startCountdown();
  startPoll();
});

onUnmounted(() => {
  stopCountdown();
  stopPoll();
});
</script>

<template>
  <div class="exam-page">
    <section class="exam-hero">
      <div>
        <span class="hero-kicker"
          ><i class="pi pi-sparkles"></i> EXAM MANAGEMENT</span
        >
        <h1>จัดการข้อสอบ</h1>
        <p>
          สร้างข้อสอบ ควบคุมการติวแบบเรียลไทม์ และติดตามผลนักเรียนในที่เดียว
        </p>
      </div>
      <Button
        label="เปิดหน้าทำข้อสอบ"
        icon="pi pi-external-link"
        class="hero-button"
        @click="openStudentExam"
      />
    </section>
    <div class="pageHead legacy-head">
      <div>
        <h1>จัดการข้อสอบ</h1>
        <p>สร้างข้อสอบ ควบคุมการติว และตรวจผลนักเรียน</p>
      </div>
      <Button
        label="เปิดหน้าทำข้อสอบ"
        icon="pi pi-external-link"
        outlined
        @click="openStudentExam"
      />
    </div>

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

    <Tabs v-model:value="activeTab">
      <TabList>
        <Tab value="control">ควบคุมการติว</Tab>
        <Tab value="builder">สร้างข้อสอบ</Tab>
        <Tab value="results">ผลนักเรียน</Tab>
      </TabList>

      <TabPanels>
        <TabPanel value="control">
          <Card>
            <template #content>
              <div v-if="loading && !control" class="empty">
                <i class="pi pi-spin pi-spinner"></i>
                <h2>กำลังโหลดข้อมูล...</h2>
              </div>

              <div v-else-if="!control" class="empty">
                <i class="pi pi-file-edit"></i>
                <h2>ยังไม่มีชุดข้อสอบ</h2>
                <p>เลือกแท็บ “สร้างข้อสอบ” ก่อน</p>
              </div>

              <div v-else class="examControl">
                <div class="controlHeader">
                  <div>
                    <h2>{{ control.title }}</h2>
                    <p>
                      {{ control.total }} ข้อ •
                      {{ statusText(control.sessionStatus) }}
                    </p>
                  </div>
                  <Tag
                    :severity="
                      control.sessionStatus === 'live'
                        ? 'success'
                        : control.sessionStatus === 'finished'
                          ? 'secondary'
                          : 'info'
                    "
                    :value="statusText(control.sessionStatus)"
                  />
                </div>

                <div class="controlActions">
                  <Button
                    v-if="['none', 'finished'].includes(control.sessionStatus)"
                    label="เริ่มรอบใหม่"
                    icon="pi pi-play"
                    :loading="busy"
                    @click="
                      action('teacher_round_start', {}, 'เริ่มรอบใหม่แล้ว')
                    "
                  />
                  <Button
                    v-if="control.sessionStatus === 'waiting'"
                    label="ส่งข้อ 1"
                    icon="pi pi-send"
                    :loading="busy"
                    @click="action('teacher_release_next', {}, 'ส่งข้อ 1 แล้ว')"
                  />
                  <Button
                    v-if="
                      control.sessionStatus === 'live' &&
                      control.currentPosition + 1 < control.total
                    "
                    :label="`ส่งข้อ ${control.currentPosition + 2}`"
                    icon="pi pi-send"
                    :loading="busy"
                    @click="
                      action(
                        'teacher_release_next',
                        {},
                        `ส่งข้อ ${control.currentPosition + 2} แล้ว`,
                      )
                    "
                  />
                  <Button
                    v-if="control.sessionStatus === 'live'"
                    label="จบการติว"
                    icon="pi pi-stop-circle"
                    severity="danger"
                    outlined
                    :loading="busy"
                    @click="action('teacher_round_finish', {}, 'จบการติวแล้ว')"
                  />
                </div>

                <div
                  v-if="control.sessionStatus === 'live'"
                  class="controlStats"
                >
                  <article>
                    <small>ข้อปัจจุบัน</small
                    ><b>{{ control.currentPosition + 1 }}</b>
                  </article>
                  <article>
                    <small>ตอบแล้ว</small
                    ><b
                      >{{ control.answeredCount || 0 }}/{{
                        control.studentCount || 0
                      }}</b
                    >
                  </article>
                  <article>
                    <small>ถูก</small><b>{{ control.correctCount || 0 }}</b>
                  </article>
                  <article>
                    <small>ผิด</small><b>{{ control.wrongCount || 0 }}</b>
                  </article>
                  <article class="timeStat" :class="{ danger: timeDanger }">
                    <small>เวลาที่เหลือ</small><b>{{ timeText }}</b>
                  </article>
                </div>
              </div>
            </template>
          </Card>
        </TabPanel>

        <TabPanel value="builder">
          <div class="examMeta">
            <label>ชื่อชุดข้อสอบ<InputText v-model="title" fluid /></label>
            <label
              >เวลาต่อข้อ (นาที)<InputNumber
                v-model="duration"
                :min="1"
                :max="60"
                fluid
            /></label>
          </div>

          <Card v-for="(q, qi) in questions" :key="qi" class="questionEdit">
            <template #title>
              <div class="questionHead">
                <span>ข้อ {{ qi + 1 }}</span>
                <Button
                  icon="pi pi-trash"
                  severity="danger"
                  text
                  aria-label="ลบคำถาม"
                  @click="removeQuestion(qi)"
                />
              </div>
            </template>
            <template #content>
              <InputText v-model="q.text" class="wideInput" fluid />
              <div
                v-for="(choice, ci) in q.choices"
                :key="ci"
                class="choiceEdit"
              >
                <RadioButton
                  v-model="q.correct"
                  :input-id="`q${qi}c${ci}`"
                  :value="ci"
                />
                <label :for="`q${qi}c${ci}`">{{ labels[ci] }}</label>
                <InputText v-model="q.choices[ci]" fluid />
                <Button
                  icon="pi pi-times"
                  text
                  severity="danger"
                  aria-label="ลบตัวเลือก"
                  @click="removeChoice(q, ci)"
                />
              </div>
              <Button
                label="เพิ่มตัวเลือก"
                icon="pi pi-plus"
                text
                :disabled="q.choices.length >= 6"
                @click="addChoice(q)"
              />
            </template>
          </Card>

          <div class="builderActions">
            <Button
              label="เพิ่มข้อ"
              icon="pi pi-plus"
              outlined
              @click="addQuestion"
            />
            <Button
              label="บันทึกชุดข้อสอบ"
              icon="pi pi-save"
              :loading="busy"
              @click="save"
            />
          </div>
        </TabPanel>

        <TabPanel value="results">
          <section class="results-shell">
            <div class="results-titlebar">
              <div class="results-heading">
                <span class="results-heading-icon"
                  ><i class="pi pi-users"></i
                ></span>
                <div>
                  <h2>ผลนักเรียน</h2>
                  <p>ตรวจสอบคะแนนและสถานะของนักเรียนแบบเรียลไทม์</p>
                </div>
              </div>
              <div class="results-actions">
                <Button
                  label="รีเฟรช"
                  icon="pi pi-refresh"
                  outlined
                  @click="load({ silent: true })"
                /><Button
                  label="เคลียร์ทั้งหมด"
                  icon="pi pi-trash"
                  severity="danger"
                  outlined
                  :disabled="!results.length"
                  @click="
                    action('teacher_clear_results', {}, 'เคลียร์ผลนักเรียนแล้ว')
                  "
                />
              </div>
            </div>

            <div class="result-summary">
              <article class="summary-card blue">
                <span><i class="pi pi-users"></i></span>
                <div>
                  <small>นักเรียนทั้งหมด</small><b>{{ results.length }}</b
                  ><em>คน</em>
                </div>
              </article>
              <article class="summary-card green">
                <span><i class="pi pi-check-circle"></i></span>
                <div>
                  <small>ทำเสร็จแล้ว</small><b>{{ finishedCount }}</b
                  ><em>คน</em>
                </div>
              </article>
              <article class="summary-card orange">
                <span><i class="pi pi-clock"></i></span>
                <div>
                  <small>กำลังทำ</small><b>{{ workingCount }}</b
                  ><em>คน</em>
                </div>
              </article>
              <article class="summary-card purple">
                <span><i class="pi pi-trophy"></i></span>
                <div>
                  <small>คะแนนเฉลี่ย</small><b>{{ averageScore }}</b
                  ><em>คะแนน</em>
                </div>
              </article>
              <article class="summary-card cyan">
                <span><i class="pi pi-chart-bar"></i></span>
                <div>
                  <small>อัตราทำเสร็จ</small><b>{{ completionRate }}%</b>
                  <div class="mini-progress">
                    <i :style="{ width: completionRate + '%' }"></i>
                  </div>
                </div>
              </article>
            </div>

            <div class="result-tools">
              <div class="search-box">
                <i class="pi pi-search"></i
                ><InputText
                  v-model="resultSearch"
                  placeholder="ค้นหาชื่อนักเรียน หรือรหัส..."
                />
              </div>
              <select v-model="resultStatus" class="status-select">
                <option value="all">ทุกสถานะ</option>
                <option value="working">กำลังทำ</option>
                <option value="finished">เสร็จแล้ว</option>
              </select>
              <span class="result-count"
                >แสดง {{ filteredResults.length }} รายการ</span
              >
            </div>

            <DataTable
              :value="filteredResults"
              striped-rows
              responsive-layout="scroll"
              :empty-message="'ยังไม่มีนักเรียนเข้าร่วม'"
              class="result-table"
            >
              <Column header="#"
                ><template #body="{ index }">{{ index + 1 }}</template></Column
              >
              <Column field="studentId" header="รหัสนักเรียน" />
              <Column field="studentName" header="ชื่อ - นามสกุล" />
              <Column header="คะแนน"
                ><template #body="{ data }"
                  ><b>{{ data.score }} / {{ data.total }}</b></template
                ></Column
              >
              <Column header="สถานะ"
                ><template #body="{ data }"
                  ><Tag
                    :severity="data.finished ? 'success' : 'info'"
                    :value="
                      data.finished ? 'เสร็จแล้ว' : 'กำลังทำ'
                    " /></template
              ></Column>
              <Column header="จัดการ"
                ><template #body="{ data }"
                  ><Button
                    label="รีเซ็ต"
                    icon="pi pi-refresh"
                    severity="danger"
                    text
                    @click="
                      action(
                        'teacher_reset_attempt',
                        { p_attempt_id: data.attemptId },
                        'รีเซ็ตนักเรียนแล้ว',
                      )
                    " /></template
              ></Column>
            </DataTable>
            <div class="result-footer">
              <span
                >แสดง {{ filteredResults.length ? 1 : 0 }} -
                {{ filteredResults.length }} จาก
                {{ filteredResults.length }} รายการ</span
              ><span class="page-chip">1</span>
            </div>
          </section>
        </TabPanel>
      </TabPanels>
    </Tabs>
  </div>
</template>

<style scoped>
.exam-page {
  display: grid;
  gap: 16px;
}
.pageHead {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}
.pageHead h1 {
  margin: 0;
  color: #10264b;
}
.pageHead p {
  margin: 3px 0 0;
  color: #71839d;
}
.empty {
  min-height: 280px;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 9px;
  text-align: center;
  color: #71839d;
}
.empty > i {
  font-size: 46px;
  color: #1683ff;
}
.empty h2,
.empty p {
  margin: 0;
}
.examControl {
  display: grid;
  gap: 22px;
}
.controlHeader {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}
.controlHeader h2 {
  margin: 0;
  color: #10264b;
}
.controlHeader p {
  margin: 5px 0 0;
  color: #71839d;
}
.controlActions,
.builderActions,
.resultActions,
.resultActions > div {
  display: flex;
  align-items: center;
  gap: 9px;
}
.controlActions,
.builderActions {
  justify-content: flex-end;
  flex-wrap: wrap;
}
.controlStats {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 10px;
}
.controlStats article {
  padding: 16px;
  border-radius: 12px;
  background: #f4f8fc;
  border: 1px solid #e4edf6;
}
.controlStats small,
.controlStats b {
  display: block;
}
.controlStats small {
  color: #6f819b;
  font-size: 11px;
}
.controlStats b {
  margin-top: 4px;
  color: #10264b;
  font-size: 24px;
}
.timeStat b {
  font-variant-numeric: tabular-nums;
}
.timeStat.danger {
  background: #fff0f0;
  border-color: #ffc8c8;
}
.timeStat.danger b {
  color: #e53935;
}
.examMeta {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 14px;
  margin-bottom: 15px;
}
.examMeta label {
  display: grid;
  gap: 7px;
  font-weight: 700;
  color: #294766;
}
.questionEdit {
  margin-bottom: 12px;
}
.questionHead {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.wideInput {
  margin-bottom: 12px;
}
.choiceEdit {
  display: grid;
  grid-template-columns: auto 24px minmax(0, 1fr) auto;
  gap: 9px;
  align-items: center;
  margin: 9px 0;
}
.builderActions {
  position: sticky;
  bottom: 12px;
  padding: 12px;
  border: 1px solid #dce7f2;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.94);
  box-shadow: 0 8px 24px rgba(20, 50, 90, 0.09);
}
.resultActions {
  justify-content: space-between;
  margin-bottom: 12px;
}
@media (max-width: 900px) {
  .controlStats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .timeStat {
    grid-column: 1/-1;
  }
  .examMeta {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 640px) {
  .pageHead {
    align-items: stretch;
    flex-direction: column;
  }
  .pageHead :deep(.p-button) {
    width: 100%;
  }
  .controlHeader {
    flex-direction: column;
  }
  .controlActions {
    display: grid;
    grid-template-columns: 1fr;
  }
  .controlActions :deep(.p-button) {
    width: 100%;
  }
  .controlStats {
    grid-template-columns: 1fr 1fr;
  }
  .choiceEdit {
    grid-template-columns: auto 22px minmax(0, 1fr) auto;
  }
  .builderActions {
    display: grid;
    grid-template-columns: 1fr;
  }
  .builderActions :deep(.p-button) {
    width: 100%;
  }
  .resultActions {
    align-items: flex-start;
    flex-direction: column;
  }
  .resultActions > div {
    width: 100%;
    flex-wrap: wrap;
  }
}

/* Polished exam workspace */
.exam-page {
  --exam-navy: #102b52;
  --exam-blue: #167df5;
  --exam-green: #16b884;
  --exam-line: #dce7f2;
  --exam-muted: #71839d;
  gap: 20px;
}
.exam-hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  padding: 22px 24px;
  border: 1px solid #dce7f2;
  border-radius: 18px;
  background: linear-gradient(120deg, #ffffff 0%, #f2f8ff 58%, #edf9f5 100%);
  box-shadow: 0 12px 30px rgba(25, 57, 94, 0.07);
}
.exam-hero h1 {
  margin: 8px 0 4px;
  color: var(--exam-navy);
  font-size: 28px;
}
.exam-hero p {
  margin: 0;
  color: var(--exam-muted);
  font-size: 13px;
}
.hero-kicker {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 9px;
  border-radius: 999px;
  background: #e7f2ff;
  color: #167df5;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.08em;
}
.hero-button {
  box-shadow: 0 8px 18px rgba(22, 125, 245, 0.18);
}
.legacy-head {
  display: none;
}
:deep(.p-tabs) {
  border: 1px solid var(--exam-line);
  border-radius: 16px;
  background: #fff;
  overflow: hidden;
  box-shadow: 0 10px 26px rgba(25, 57, 94, 0.05);
}
:deep(.p-tablist-tab-list) {
  padding: 0 16px;
  border-bottom: 1px solid var(--exam-line);
  background: #fbfdff;
}
:deep(.p-tab) {
  padding: 16px 18px;
  font-weight: 700;
  font-size: 13px;
}
:deep(.p-tab-active) {
  color: var(--exam-green);
}
:deep(.p-tabpanels) {
  padding: 20px;
  background: #f8fbfe;
}
:deep(.p-card) {
  border: 1px solid #e0eaf4;
  border-radius: 16px;
  box-shadow: 0 8px 22px rgba(26, 62, 99, 0.05);
}
.controlHeader {
  padding: 2px 2px 4px;
}
.controlHeader h2 {
  font-size: 22px;
}
.controlActions {
  padding: 14px 0;
  border-top: 1px dashed #dce7f2;
  border-bottom: 1px dashed #dce7f2;
}
.controlStats article {
  position: relative;
  overflow: hidden;
  padding: 18px;
  background: #fff;
  border: 1px solid #e1ebf4;
}
.controlStats article:before {
  content: "";
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 4px;
  background: #c7d8ea;
}
.controlStats article:nth-child(2):before {
  background: #3b82f6;
}
.controlStats article:nth-child(3):before {
  background: #10b981;
}
.controlStats article:nth-child(4):before {
  background: #ef4444;
}
.controlStats .timeStat:before {
  background: #7c4dff;
}
.controlStats b {
  font-size: 26px;
}
.examMeta {
  padding: 18px;
  border: 1px solid var(--exam-line);
  border-radius: 14px;
  background: #fff;
}
.questionEdit {
  overflow: hidden;
}
.questionHead {
  padding-bottom: 2px;
}
.questionHead span {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-weight: 800;
  color: var(--exam-navy);
}
.questionHead span:before {
  content: "?";
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: #e7f2ff;
  color: #167df5;
}
.choiceEdit {
  padding: 7px 9px;
  border: 1px solid #e6edf5;
  border-radius: 10px;
  background: #fbfdff;
}
.choiceEdit:focus-within {
  border-color: #8fc4ff;
  background: #fff;
  box-shadow: 0 0 0 3px rgba(22, 125, 245, 0.07);
}
.builderActions {
  z-index: 3;
}
.resultActions {
  padding: 14px 16px;
  border: 1px solid var(--exam-line);
  border-radius: 12px;
  background: #fff;
}
:deep(.p-datatable) {
  border: 1px solid var(--exam-line);
  border-radius: 12px;
  overflow: hidden;
}
:deep(.p-datatable-header-cell) {
  background: #f2f6fb;
  color: #405b78;
  font-size: 12px;
}
:deep(.p-datatable-tbody > tr:hover) {
  background: #f7fbff;
}
@media (max-width: 640px) {
  .exam-hero {
    align-items: stretch;
    flex-direction: column;
    padding: 18px;
  }
  .exam-hero h1 {
    font-size: 23px;
  }
  .hero-button {
    width: 100%;
  }
  :deep(.p-tabpanels) {
    padding: 12px;
  }
  :deep(.p-tab) {
    padding: 13px 10px;
    font-size: 11px;
  }
  .controlStats article {
    padding: 14px;
  }
  .controlStats b {
    font-size: 22px;
  }
  .examMeta {
    padding: 14px;
  }
  .choiceEdit {
    grid-template-columns: auto 20px minmax(0, 1fr) auto;
  }
}

/* Results redesign */
.results-shell {
  padding: 2px;
}
.results-titlebar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  margin-bottom: 18px;
}
.results-heading {
  display: flex;
  align-items: center;
  gap: 13px;
}
.results-heading-icon {
  width: 52px;
  height: 52px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: #e4faf1;
  color: #10aa78;
  font-size: 22px;
}
.results-heading h2 {
  margin: 0;
  color: #102b52;
  font-size: 21px;
}
.results-heading p {
  margin: 3px 0 0;
  color: #71839d;
  font-size: 11px;
}
.results-actions {
  display: flex;
  gap: 9px;
}
.result-summary {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 10px;
  margin-bottom: 16px;
}
.summary-card {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 104px;
  padding: 15px;
  border: 1px solid #e2ebf4;
  border-radius: 13px;
  background: #fff;
}
.summary-card > span {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  font-size: 18px;
}
.summary-card small,
.summary-card b,
.summary-card em {
  display: block;
}
.summary-card small {
  color: #526b87;
  font-size: 10px;
  font-weight: 700;
}
.summary-card b {
  margin-top: 2px;
  color: #102b52;
  font-size: 24px;
}
.summary-card em {
  color: #71839d;
  font-size: 9px;
  font-style: normal;
}
.summary-card.blue {
  background: #f6faff;
}
.summary-card.blue > span {
  background: #dcecff;
  color: #167df5;
}
.summary-card.green {
  background: #f4fcf8;
}
.summary-card.green > span {
  background: #dff8ee;
  color: #10aa78;
}
.summary-card.orange {
  background: #fffaf2;
}
.summary-card.orange > span {
  background: #ffefcb;
  color: #ef9317;
}
.summary-card.purple {
  background: #faf8ff;
}
.summary-card.purple > span {
  background: #eee7ff;
  color: #7c4dff;
}
.summary-card.cyan {
  background: #f5fbff;
}
.summary-card.cyan > span {
  background: #dff3ff;
  color: #1596d2;
}
.mini-progress {
  width: 100%;
  height: 7px;
  margin-top: 7px;
  border-radius: 99px;
  background: #dce5ef;
  overflow: hidden;
}
.mini-progress i {
  display: block;
  height: 100%;
  background: #16b884;
  border-radius: 99px;
}
.result-tools {
  display: grid;
  grid-template-columns: 1fr 240px auto;
  gap: 12px;
  align-items: center;
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
  z-index: 1;
  color: #68809a;
}
.search-box :deep(.p-inputtext) {
  width: 100%;
  padding-left: 38px;
}
.status-select {
  height: 42px;
  border: 1px solid #d3dfeb;
  border-radius: 9px;
  padding: 0 12px;
  background: #fff;
  color: #294766;
}
.result-count {
  color: #71839d;
  font-size: 10px;
  text-align: right;
}
.result-table :deep(.p-datatable-thead > tr > th) {
  padding: 13px;
  background: #eff4f9;
  color: #344f6d;
}
.result-table :deep(.p-datatable-tbody > tr > td) {
  padding: 14px 13px;
}
.result-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 4px 5px;
  color: #71839d;
  font-size: 10px;
}
.page-chip {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 9px;
  background: #16b884;
  color: #fff;
  font-size: 13px;
  font-weight: 800;
}
@media (max-width: 1050px) {
  .result-summary {
    grid-template-columns: repeat(2, 1fr);
  }
  .summary-card.cyan {
    grid-column: 1/-1;
  }
  .result-tools {
    grid-template-columns: 1fr 180px;
  }
  .result-count {
    grid-column: 1/-1;
    text-align: left;
  }
}
@media (max-width: 640px) {
  .results-titlebar {
    align-items: flex-start;
    flex-direction: column;
  }
  .results-actions {
    width: 100%;
  }
  .results-actions :deep(.p-button) {
    flex: 1;
  }
  .result-summary {
    grid-template-columns: 1fr 1fr;
  }
  .summary-card {
    min-height: 90px;
    padding: 12px;
  }
  .summary-card b {
    font-size: 20px;
  }
  .result-tools {
    grid-template-columns: 1fr;
  }
  .status-select {
    width: 100%;
  }
  .result-table {
    margin: 0 -12px;
  }
  .result-footer {
    padding-inline: 0;
  }
}
</style>
