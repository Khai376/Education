<script setup>
import { computed, onMounted, ref, watch } from "vue";
import Button from "primevue/button";
import Card from "primevue/card";
import Dialog from "primevue/dialog";
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
  { key: 1, label: "คาบที่ 1", start: "08:30", end: "09:30" },
  { key: 2, label: "คาบที่ 2", start: "09:30", end: "10:30" },
  { key: 3, label: "คาบที่ 3", start: "10:30", end: "11:30" },
  { key: 4, label: "คาบที่ 4", start: "12:30", end: "13:30" },
  { key: 5, label: "คาบที่ 5", start: "13:30", end: "14:30" },
  { key: 6, label: "คาบที่ 6", start: "14:30", end: "15:30" },
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

const schedule = ref([]),
  offerings = ref([]),
  teachers = ref([]);
const buildingChoices = ref([]),
  classroomChoices = ref([]);
const saving = ref(false),
  message = ref(""),
  success = ref("");
const editorVisible = ref(false),
  draggingId = ref(null);
function getTodayDayOfWeek() {
  const day = new Date().getDay();
  return day >= 1 && day <= 5 ? day : "all";
}

const filterDay = ref(getTodayDayOfWeek()),
  filterSubject = ref("all"),
  filterGrade = ref("all");
const filterTeacher = ref("all"),
  filterPeriod = ref("all"),
  filterType = ref("all");
const filterOwnerTeacher = ref("all");

function emptyForm() {
  return {
    id: null,
    offeringId: null,
    teacherId: null,
    lessonOwnerTeacherId: null,
    dayOfWeek: 1,
    startTime: "08:30",
    endTime: "09:30",
    buildingId: null,
    classroomId: null,
    originalBuilding: "",
    originalRoomName: "",
    substitute: false,
    originalSubstitute: false,
    substituteStartDate: null,
    substituteEndDate: null,
  };
}
const form = ref(emptyForm());

function toMinutes(t) {
  const [h, m] = String(t || "00:00")
    .split(":")
    .map(Number);
  return h * 60 + m;
}
function localDateKey(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function effectiveTeacherId(e, date = localDateKey()) {
  return e.substituteConfigured &&
    e.substituteStartDate <= date &&
    date <= e.substituteEndDate
    ? e.substituteTeacherId || e.teacherId
    : e.lessonOwnerTeacherId || e.teacherId;
}
function teacherDisplayName(id) {
  const t = teachers.value.find((x) => String(x.id) === String(id));
  return t
    ? `${t.teacherName}${t.teacherCode ? ` (${t.teacherCode})` : ""}`
    : "-";
}
function periodLabelFromTime(time) {
  return (
    teachingPeriods.find((p) => p.start === String(time || "").slice(0, 5))
      ?.label || `เวลา ${String(time || "-").slice(0, 5)}`
  );
}
function teacherInitial(name) {
  return (
    String(name || "?")
      .trim()
      .charAt(0) || "?"
  );
}

const sheetTeachers = computed(() =>
  teachers.value.filter((t) => t.status === "active"),
);
const visibleDays = computed(() =>
  filterDay.value === "all"
    ? weekDays
    : weekDays.filter((d) => d.key === Number(filterDay.value)),
);
const teacherOptions = computed(() =>
  sheetTeachers.value.map((t) => ({
    label: `${t.teacherName} (${t.teacherCode})`,
    value: t.id,
  })),
);
const ownerTeacherOptions = computed(() => teacherOptions.value);
const offeringOptions = computed(() =>
  offerings.value.map((o) => ({
    label: `${o.subjectName} • ${o.gradeLevel}/${o.room}`,
    value: o.id,
  })),
);
const selectedOffering = computed(
  () => offerings.value.find((o) => o.id === form.value.offeringId) || null,
);
const selectedBuilding = computed(
  () =>
    buildingChoices.value.find((b) => b.id === form.value.buildingId) || null,
);
const selectedClassroom = computed(
  () =>
    classroomChoices.value.find((r) => r.id === form.value.classroomId) || null,
);
const autoLocationText = computed(() =>
  selectedOffering.value
    ? `${selectedOffering.value.gradeLevel} → ${selectedBuilding.value?.name || form.value.originalBuilding || "-"} • ${selectedClassroom.value?.name || form.value.originalRoomName || "-"}`
    : "เลือกวิชา / ชั้น / ห้องก่อน",
);
const gradeOptions = computed(() =>
  [...new Set(offerings.value.map((o) => o.gradeLevel).filter(Boolean))]
    .sort()
    .map((v) => ({ label: v, value: v })),
);
const subjectOptions = computed(() => {
  const m = new Map();
  offerings.value.forEach((o) => {
    if (o.subjectId && !m.has(o.subjectId)) m.set(o.subjectId, o.subjectName);
  });
  return [...m]
    .map(([value, label]) => ({ label, value }))
    .sort((a, b) => a.label.localeCompare(b.label, "th"));
});
const periodOptions = computed(() => [
  { label: "ทุกเวลา", value: "all" },
  ...teachingPeriods.map((p) => ({
    label: `${p.label} • ${p.start}-${p.end}`,
    value: p.start,
  })),
]);

const filteredSchedule = computed(() =>
  schedule.value.filter((e) => {
    if (
      filterDay.value !== "all" &&
      Number(e.dayOfWeek) !== Number(filterDay.value)
    )
      return false;
    if (filterSubject.value !== "all" && e.subjectId !== filterSubject.value)
      return false;
    if (filterGrade.value !== "all" && e.gradeLevel !== filterGrade.value)
      return false;
    if (
      filterTeacher.value !== "all" &&
      effectiveTeacherId(e) !== filterTeacher.value &&
      (e.lessonOwnerTeacherId || e.teacherId) !== filterTeacher.value
    )
      return false;
    if (
      filterPeriod.value !== "all" &&
      String(e.startTime).slice(0, 5) !== filterPeriod.value
    )
      return false;
    if (filterType.value === "normal" && e.substitute) return false;
    if (filterType.value === "substitute" && !e.substitute) return false;
    if (
      filterOwnerTeacher.value !== "all" &&
      e.lessonOwnerTeacherId !== filterOwnerTeacher.value
    )
      return false;
    return true;
  }),
);
function clearFilters() {
  filterDay.value = getTodayDayOfWeek();
  filterSubject.value = "all";
  filterGrade.value = "all";
  filterTeacher.value = "all";
  filterPeriod.value = "all";
  filterType.value = "all";
  filterOwnerTeacher.value = "all";
}
function eventAt(day, teacherId, p) {
  return (
    filteredSchedule.value.find(
      (e) =>
        (e.lessonOwnerTeacherId || e.teacherId) === teacherId &&
        Number(e.dayOfWeek) === Number(day) &&
        String(e.startTime).slice(0, 5) === p.start,
    ) || null
  );
}

const palette = [
  ["#dcedff", "#72aef2", "#174b7a"],
  ["#f9e2ee", "#df9abe", "#7b3458"],
  ["#e2f5e9", "#7ccc9c", "#286548"],
  ["#eee7ff", "#ad96e9", "#51417c"],
  ["#fff1cf", "#e6c25e", "#725d1f"],
  ["#dff2f5", "#7bc4ca", "#285d62"],
  ["#ffead7", "#e8aa70", "#78502b"],
  ["#f2e2f7", "#d092da", "#693b70"],
];
function teacherColor(id) {
  const i = Math.max(
    0,
    teachers.value.findIndex((t) => t.id === id),
  );
  const [background, border, color] = palette[i % palette.length];
  return { background, borderColor: border, color };
}
function lessonStyle(e) {
  return e?.substitute
    ? { background: "#fff0c2", borderColor: "#ef9a22", color: "#754a00" }
    : teacherColor(e?.lessonOwnerTeacherId || e?.teacherId);
}
function todaysSubstituteCount(id) {
  const today = localDateKey();
  return schedule.value.filter(
    (e) =>
      effectiveTeacherId(e, today) === id &&
      e.substituteConfigured &&
      e.substituteStartDate <= today &&
      today <= e.substituteEndDate,
  ).length;
}
function teacherAvailability(t) {
  const day = Number(form.value.dayOfWeek),
    start = form.value.startTime,
    end = form.value.endTime;
  const dayName = weekDays.find((d) => d.key === day)?.label || "-",
    period = periodLabelFromTime(start);
  const c = schedule.value.find(
    (e) =>
      e.id !== form.value.id &&
      effectiveTeacherId(e) === t.id &&
      Number(e.dayOfWeek) === day &&
      toMinutes(e.startTime) < toMinutes(end) &&
      toMinutes(e.endTime) > toMinutes(start),
  );
  return c
    ? {
        available: false,
        reason: `ไม่ว่าง • วัน${dayName} • ${period} • ${c.subjectName || "-"} • ${c.gradeLevel || "-"}/${c.classRoom || "-"}`,
      }
    : {
        available: true,
        reason: `ว่าง • วัน${dayName} • ${period} ${start}-${end} • สอนแทนวันนี้ ${todaysSubstituteCount(t.id)} คาบ`,
      };
}
const substituteTeacherOptions = computed(() =>
  teachers.value
    .filter(
      (t) => t.status === "active" && t.id !== form.value.lessonOwnerTeacherId,
    )
    .map((t) => {
      const a = teacherAvailability(t),
        allowed = t.canSubstitute !== false;
      return {
        label: `${t.teacherName} (${t.teacherCode}) • ${allowed ? a.reason : "ไม่อนุญาตสอนแทน"}`,
        value: t.id,
        disabled: !allowed || !a.available,
        available: allowed && a.available,
        name: t.teacherName,
      };
    })
    .sort((a, b) =>
      a.available !== b.available
        ? a.available
          ? -1
          : 1
        : a.name.localeCompare(b.name, "th"),
    ),
);
function isOwnerPeriodFree(day, p) {
  const owner = form.value.lessonOwnerTeacherId || form.value.teacherId;
  if (!owner) return true;
  return !schedule.value.some(
    (e) =>
      e.id !== form.value.id &&
      (e.lessonOwnerTeacherId || e.teacherId) === owner &&
      Number(e.dayOfWeek) === Number(day) &&
      toMinutes(e.startTime) < toMinutes(p.end) &&
      toMinutes(e.endTime) > toMinutes(p.start),
  );
}
const freeTimeOptions = computed(() =>
  teachingPeriods
    .filter((p) => isOwnerPeriodFree(form.value.dayOfWeek, p))
    .map((p) => ({
      label: `${p.label} • ${p.start}-${p.end}`,
      value: p.start,
      end: p.end,
    })),
);
const freeDayOptions = computed(() =>
  weekDays.filter((d) =>
    teachingPeriods.some((p) => isOwnerPeriodFree(d.key, p)),
  ),
);
function onFreeTimeChange() {
  const p = freeTimeOptions.value.find((x) => x.value === form.value.startTime);
  if (p) form.value.endTime = p.end;
}

const exportSchedule = computed(() =>
  schedule.value.filter((e) => {
    if (
      filterDay.value !== "all" &&
      Number(e.dayOfWeek) !== Number(filterDay.value)
    )
      return false;
    if (filterSubject.value !== "all" && e.subjectId !== filterSubject.value)
      return false;
    if (filterGrade.value !== "all" && e.gradeLevel !== filterGrade.value)
      return false;

    // ให้ Export ตารางตรงกับตัวกรองครูบนหน้าจอด้วย
    if (
      filterTeacher.value !== "all" &&
      effectiveTeacherId(e) !== filterTeacher.value &&
      (e.lessonOwnerTeacherId || e.teacherId) !== filterTeacher.value
    )
      return false;

    if (
      filterPeriod.value !== "all" &&
      String(e.startTime).slice(0, 5) !== filterPeriod.value
    )
      return false;
    if (filterType.value === "normal" && e.substitute) return false;
    if (filterType.value === "substitute" && !e.substitute) return false;

    // ให้ Export ตารางตรงกับตัวกรองเจ้าของคาบด้วย
    if (
      filterOwnerTeacher.value !== "all" &&
      e.lessonOwnerTeacherId !== filterOwnerTeacher.value
    )
      return false;

    return true;
  }),
);
const exportGroups = computed(() => {
  const m = new Map();
  exportSchedule.value.forEach((e) => {
    const grade = e.gradeLevel || "-",
      room = e.classRoom || "-",
      key = `${grade}::${room}`;
    if (!m.has(key)) m.set(key, { key, grade, room, events: [] });
    m.get(key).events.push(e);
  });
  return [...m.values()].sort(
    (a, b) =>
      String(a.grade).localeCompare(String(b.grade), "th", { numeric: true }) ||
      String(a.room).localeCompare(String(b.room), "th", { numeric: true }),
  );
});
const exportDays = computed(() =>
  filterDay.value === "all"
    ? weekDays
    : weekDays.filter((d) => d.key === Number(filterDay.value)),
);
const exportPeriods = computed(() =>
  filterPeriod.value === "all"
    ? teachingPeriods
    : teachingPeriods.filter((p) => p.start === filterPeriod.value),
);
const exportMorningPeriods = computed(() =>
  exportPeriods.value.filter((p) => p.key <= 3),
);
const exportAfternoonPeriods = computed(() =>
  exportPeriods.value.filter((p) => p.key >= 4),
);
const showExportLunch = computed(
  () =>
    filterPeriod.value === "all" ||
    (exportMorningPeriods.value.length && exportAfternoonPeriods.value.length),
);
function groupEventAt(group, day, p) {
  return (
    group.events.find(
      (e) =>
        Number(e.dayOfWeek) === Number(day) &&
        String(e.startTime).slice(0, 5) === p.start,
    ) || null
  );
}
function exportTeacherName(e) {
  if (!e) return "";
  return e.teacherName || teacherDisplayName(effectiveTeacherId(e));
}
function exportFilterSummary() {
  const a = [];
  if (filterDay.value !== "all")
    a.push(
      `วัน${weekDays.find((d) => d.key === Number(filterDay.value))?.label || "-"}`,
    );
  if (filterSubject.value !== "all")
    a.push(
      `วิชา ${subjectOptions.value.find((x) => x.value === filterSubject.value)?.label || "-"}`,
    );
  if (filterGrade.value !== "all") a.push(`ชั้น ${filterGrade.value}`);
  if (filterTeacher.value !== "all")
    a.push(`ครู ${teacherDisplayName(filterTeacher.value)}`);
  if (filterPeriod.value !== "all")
    a.push(
      periodOptions.value.find((x) => x.value === filterPeriod.value)?.label ||
        "-",
    );
  if (filterType.value === "normal") a.push("คาบปกติ");
  if (filterType.value === "substitute") a.push("คาบสอนแทน");
  if (filterOwnerTeacher.value !== "all")
    a.push(`เจ้าของคาบ ${teacherDisplayName(filterOwnerTeacher.value)}`);
  return a.length ? a.join(" • ") : "ตารางสอนตามข้อมูลทั้งหมด";
}

const substituteReportRows = computed(() =>
  schedule.value
    .filter((e) => e.substituteConfigured || e.substitute)
    .filter(
      (e) =>
        filterDay.value === "all" ||
        Number(e.dayOfWeek) === Number(filterDay.value),
    )
    .filter(
      (e) =>
        filterSubject.value === "all" || e.subjectId === filterSubject.value,
    )
    .filter(
      (e) => filterGrade.value === "all" || e.gradeLevel === filterGrade.value,
    )
    .filter(
      (e) =>
        filterPeriod.value === "all" ||
        String(e.startTime).slice(0, 5) === filterPeriod.value,
    )
    .filter(
      (e) =>
        filterTeacher.value === "all" ||
        effectiveTeacherId(e) === filterTeacher.value ||
        (e.lessonOwnerTeacherId || e.teacherId) === filterTeacher.value,
    )
    .filter(
      (e) =>
        filterOwnerTeacher.value === "all" ||
        (e.lessonOwnerTeacherId || e.teacherId) === filterOwnerTeacher.value,
    )
    .sort(
      (a, b) =>
        Number(a.dayOfWeek) - Number(b.dayOfWeek) ||
        String(a.startTime).localeCompare(String(b.startTime)),
    ),
);
function reportOwnerName(e) {
  return e.lessonOwnerTeacherName || teacherDisplayName(e.lessonOwnerTeacherId);
}
function reportSubstituteName(e) {
  return (
    e.substituteTeacherName ||
    teacherDisplayName(e.substituteTeacherId || e.teacherId)
  );
}
function reportClassName(e) {
  return `${e.gradeLevel || "-"}/${e.classRoom || "-"}`;
}
function reportPeriodNumber(e) {
  return (
    teachingPeriods.find((p) => p.start === String(e.startTime).slice(0, 5))
      ?.key || "-"
  );
}

async function loadSchoolSettings() {
  try {
    const data = await rpc("teacher_school_settings_get");
    if (!data) return;
    schoolReport.value = {
      schoolName: data.schoolName || "โรงเรียนบ้านบ่อ",
      semester: String(data.semester || "2"),
      academicYear: String(data.academicYear || "2569"),
      academicHeadTitle: data.academicHeadTitle || "หัวหน้าฝ่ายวิชาการ",
      academicHeadName: data.academicHeadName || "",
      directorTitle: data.directorTitle || "ผู้อำนวยการ",
      directorName: data.directorName || "",
    };
  } catch (error) {
    console.error("loadSchoolSettings:", error);
  }
}
async function load() {
  message.value = "";
  try {
    await rpc("teacher_building_master_ensure");
    const [s, o, t] = await Promise.all([
      rpc("teacher_schedule_list"),
      rpc("teacher_schedule_offerings"),
      rpc("teacher_homeroom_list"),
      loadSchoolSettings(),
    ]);
    schedule.value = s || [];
    offerings.value = o || [];
    teachers.value = t || [];
  } catch (e) {
    message.value = e.message || "ไม่สามารถโหลดตารางเรียนได้";
  }
}
async function loadClassrooms(id) {
  classroomChoices.value = [];
  form.value.classroomId = null;
  if (!id) return;
  classroomChoices.value =
    (await rpc("teacher_classrooms_for_building", { p_building_id: id })) || [];
  const r =
    classroomChoices.value.find((x) => String(x.code) === "1") ||
    classroomChoices.value[0];
  if (r) form.value.classroomId = r.id;
}
async function loadBuildingsForOffering() {
  buildingChoices.value = [];
  classroomChoices.value = [];
  form.value.buildingId = null;
  form.value.classroomId = null;
  if (!selectedOffering.value?.gradeLevel) return;
  buildingChoices.value =
    (await rpc("teacher_buildings_for_grade", {
      p_grade_level: selectedOffering.value.gradeLevel,
    })) || [];
  if (buildingChoices.value[0]) {
    form.value.buildingId = buildingChoices.value[0].id;
    await loadClassrooms(form.value.buildingId);
  }
}
async function addEvent(day = 1, time = "08:30", owner = null) {
  form.value = emptyForm();
  form.value.dayOfWeek = Number(day);
  form.value.teacherId = owner;
  form.value.lessonOwnerTeacherId = owner;
  const p = teachingPeriods.find((x) => x.start === time) || teachingPeriods[0];
  form.value.startTime = p.start;
  form.value.endTime = p.end;
  editorVisible.value = true;
}
function openTeacherPeriod(day, t, p) {
  const e = eventAt(day, t.id, p);
  e ? editEvent(e) : addEvent(day, p.start, t.id);
}
async function editEvent(e) {
  const sub = !!(e.substitute || e.substituteConfigured);
  form.value = {
    id: e.id,
    offeringId: e.offeringId,
    teacherId: e.substituteTeacherId || e.teacherId,
    lessonOwnerTeacherId: e.lessonOwnerTeacherId || e.teacherId,
    dayOfWeek: Number(e.dayOfWeek),
    startTime: String(e.startTime).slice(0, 5),
    endTime: String(e.endTime).slice(0, 5),
    buildingId: null,
    classroomId: null,
    originalBuilding: e.buildingName || e.building || "",
    originalRoomName: e.classroomName || e.roomName || e.classRoom || "",
    substitute: sub,
    originalSubstitute: sub,
    substituteStartDate: e.substituteStartDate || null,
    substituteEndDate: e.substituteEndDate || null,
  };
  editorVisible.value = true;
}
watch(
  () => form.value.substitute,
  (v) => {
    if (!editorVisible.value || !form.value.id) return;

    if (v) {
      // ถ้าเป็นคาบสอนแทนที่มีอยู่แล้ว ห้ามล้างครู/วันที่ตอนเปิด Dialog
      if (!form.value.originalSubstitute) {
        form.value.teacherId = null;
        form.value.substituteStartDate = null;
        form.value.substituteEndDate = null;
      }
    } else {
      form.value.teacherId = form.value.lessonOwnerTeacherId;
    }
  },
);

async function saveEvent() {
  message.value = "";
  if (!form.value.offeringId)
    return (message.value = "กรุณาเลือกวิชา / ชั้น / ห้อง");
  if (!form.value.lessonOwnerTeacherId)
    form.value.lessonOwnerTeacherId = form.value.teacherId;
  const p = teachingPeriods.find((x) => x.start === form.value.startTime);
  if (!p) return (message.value = "กรุณาเลือกคาบเรียน");
  form.value.endTime = p.end;
  if (form.value.id && form.value.originalSubstitute && !form.value.substitute)
    return cancelSubstitute();
  if (form.value.id && form.value.substitute) {
    if (!form.value.teacherId)
      return (message.value = "กรุณาเลือกครูผู้สอนแทน");
    if (!form.value.substituteStartDate || !form.value.substituteEndDate)
      return (message.value = "กรุณาระบุช่วงวันที่สอนแทน");
    const t = teachers.value.find((x) => x.id === form.value.teacherId),
      a = t && teacherAvailability(t);
    if (!t || !a.available) return (message.value = a?.reason || "ครูไม่ว่าง");
  } else {
    form.value.teacherId = form.value.lessonOwnerTeacherId;
    form.value.substitute = false;
    if (!form.value.buildingId)
      return (message.value = "ไม่พบอาคารสำหรับชั้นเรียนนี้");
    if (!form.value.classroomId)
      return (message.value = "ไม่พบห้องสอนสำหรับชั้นเรียนนี้");
  }
  if (!window.confirm("ยืนยันการบันทึกข้อมูล?")) return;
  saving.value = true;
  try {
    if (form.value.id && form.value.substitute)
      await rpc("teacher_schedule_set_substitute", {
        p_schedule_id: form.value.id,
        p_teacher_id: form.value.teacherId,
        p_start_date: form.value.substituteStartDate,
        p_end_date: form.value.substituteEndDate,
      });
    else await rpc("teacher_schedule_save", { p_payload: form.value });
    editorVisible.value = false;
    success.value = "บันทึกเรียบร้อยแล้ว";
    await load();
  } catch (e) {
    message.value = e.message || "บันทึกไม่ได้";
    window.alert(message.value);
  } finally {
    saving.value = false;
  }
}
async function cancelSubstitute() {
  if (!form.value.id || !form.value.lessonOwnerTeacherId) return;
  if (!window.confirm("ยืนยันยกเลิกการสอนแทน?")) return;
  saving.value = true;
  try {
    await rpc("teacher_schedule_set_substitute", {
      p_schedule_id: form.value.id,
      p_teacher_id: form.value.lessonOwnerTeacherId,
      p_start_date: null,
      p_end_date: null,
    });
    editorVisible.value = false;
    success.value = "คืนคาบให้เจ้าของคาบแล้ว";
    await load();
  } catch (e) {
    message.value = e.message;
    window.alert(message.value);
  } finally {
    saving.value = false;
  }
}
async function deleteEvent(e) {
  if (!window.confirm("ยืนยันการลบคาบเรียนนี้?")) return;
  await rpc("teacher_schedule_delete", { p_schedule_id: e.id });
  editorVisible.value = false;
  await load();
}
function dragStart(e) {
  if (!e.substitute) draggingId.value = e.id;
}
async function dropAt(day, time) {
  const e = schedule.value.find((x) => x.id === draggingId.value);
  draggingId.value = null;
  if (!e || e.substitute || e.substituteConfigured) return;
  const p = teachingPeriods.find((x) => x.start === time),
    owner = e.lessonOwnerTeacherId || e.teacherId;
  await rpc("teacher_schedule_save", {
    p_payload: {
      ...e,
      id: e.id,
      offeringId: e.offeringId,
      teacherId: owner,
      lessonOwnerTeacherId: owner,
      dayOfWeek: day,
      startTime: p.start,
      endTime: p.end,
      substitute: false,
    },
  });
  await load();
}

function exportSubstituteReport() {
  if (!substituteReportRows.value.length)
    return window.alert("ไม่พบรายการครูลาและครูสอนแทนตามตัวกรอง");
  editorVisible.value = false;
  const old = document.title;
  document.title = `ใบรายงานครูลา-สอนแทน-${schoolReport.value.academicYear}`;
  document.body.classList.add("substitute-report-printing");
  const clean = () => {
    document.body.classList.remove("substitute-report-printing");
    document.title = old;
    window.removeEventListener("afterprint", clean);
  };
  window.addEventListener("afterprint", clean);
  setTimeout(() => window.print(), 150);
}
function exportScheduleTable() {
  if (!exportSchedule.value.length)
    return window.alert("ไม่พบข้อมูลตามตัวกรอง");
  editorVisible.value = false;
  const old = document.title;
  document.title =
    filterGrade.value !== "all"
      ? `ตารางสอน-${filterGrade.value}-${schoolReport.value.academicYear}`
      : `ตารางสอนทุกชั้น-${schoolReport.value.academicYear}`;
  document.body.classList.add("schedule-table-printing");
  const clean = () => {
    document.body.classList.remove("schedule-table-printing");
    document.title = old;
    window.removeEventListener("afterprint", clean);
  };
  window.addEventListener("afterprint", clean);
  setTimeout(() => window.print(), 150);
}
onMounted(load);
</script>

<template>
  <div class="schedule-page">
    <section class="hero">
      <div>
        <span class="kicker"
          ><i class="pi pi-calendar" /> SCHEDULE MANAGEMENT</span
        >
        <h1>ตารางเรียน</h1>
        <p>จัดตาราง ตรวจคาบชน และกำหนดครูสอนแทน</p>
      </div>
      <div class="hero-actions">
        <Button
          label="ใบรายงานครูลา/สอนแทน"
          icon="pi pi-file-export"
          severity="warn"
          outlined
          @click="exportSubstituteReport"
        /><Button
          label="Export ตาราง"
          icon="pi pi-file-pdf"
          severity="secondary"
          outlined
          @click="exportScheduleTable"
        /><Button label="เพิ่มคาบเรียน" icon="pi pi-plus" @click="addEvent()" />
      </div>
    </section>
    <Message v-if="message" severity="error" closable @close="message = ''">{{
      message
    }}</Message
    ><Message
      v-if="success"
      severity="success"
      closable
      @close="success = ''"
      >{{ success }}</Message
    >
    <Card
      ><template #content>
        <div class="filter-panel">
          <div class="filter-title">
            <div>
              <b>กรองตารางเรียน</b><small>ตัวกรองมีผลต่อเอกสาร Export</small>
            </div>
            <Button
              label="ล้างตัวกรอง"
              icon="pi pi-filter-slash"
              text
              @click="clearFilters"
            />
          </div>
          <div class="filters">
            <Select
              v-model="filterDay"
              :options="[
                { label: 'ทุกวัน', value: 'all' },
                ...weekDays.map((d) => ({ label: d.label, value: d.key })),
              ]"
              option-label="label"
              option-value="value"
            /><Select
              v-model="filterSubject"
              :options="[{ label: 'ทุกวิชา', value: 'all' }, ...subjectOptions]"
              option-label="label"
              option-value="value"
              filter
            /><Select
              v-model="filterGrade"
              :options="[
                { label: 'ทุกชั้นเรียน', value: 'all' },
                ...gradeOptions,
              ]"
              option-label="label"
              option-value="value"
            /><Select
              v-model="filterTeacher"
              :options="[
                { label: 'ครูทุกคน', value: 'all' },
                ...teacherOptions,
              ]"
              option-label="label"
              option-value="value"
              filter
            /><Select
              v-model="filterPeriod"
              :options="periodOptions"
              option-label="label"
              option-value="value"
            /><Select
              v-model="filterType"
              :options="[
                { label: 'ทุกประเภท', value: 'all' },
                { label: 'คาบปกติ', value: 'normal' },
                { label: 'สอนแทน', value: 'substitute' },
              ]"
              option-label="label"
              option-value="value"
            /><Select
              v-model="filterOwnerTeacher"
              :options="[
                { label: 'เจ้าของคาบทั้งหมด', value: 'all' },
                ...ownerTeacherOptions,
              ]"
              option-label="label"
              option-value="value"
              filter
            />
          </div>
        </div>
       <br>
        <div class="all-days-stack">
          <div
            v-for="day in visibleDays"
            :key="day.key"
            class="teacher-sheet-wrap"
          >
            <div class="teacher-sheet-title" :class="`day-${day.key}`">
              <span class="day-title-dot"></span>วัน{{ day.label }}
            </div>
            <div class="teacher-sheet">
              <div class="teacher-head">ครู</div>
              <div
                v-for="p in teachingPeriods"
                :key="p.key"
                class="period-head"
              >
                <b>{{ p.label }}</b
                ><small>{{ p.start }}-{{ p.end }}</small>
              </div>
              <template v-for="t in sheetTeachers" :key="t.id"
                ><div class="teacher-cell">
                  <span class="teacher-avatar" :style="teacherColor(t.id)">{{
                    teacherInitial(t.teacherName)
                  }}</span
                  ><b>{{ t.teacherName }}</b>
                </div>
                <div
                  v-for="p in teachingPeriods"
                  :key="p.key"
                  class="lesson-cell"
                  @click="openTeacherPeriod(day.key, t, p)"
                  @dragover.prevent
                  @drop="dropAt(day.key, p.start)"
                >
                  <span v-if="!eventAt(day.key, t.id, p)" class="lesson-empty"
                    >-</span
                  ><button
                    v-else
                    type="button"
                    class="lesson-chip"
                    :class="{ sub: eventAt(day.key, t.id, p).substitute }"
                    :style="lessonStyle(eventAt(day.key, t.id, p))"
                    :draggable="!eventAt(day.key, t.id, p).substitute"
                    @dragstart.stop="dragStart(eventAt(day.key, t.id, p))"
                    @click.stop="editEvent(eventAt(day.key, t.id, p))"
                  >
                    <b>{{ eventAt(day.key, t.id, p).subjectName }}</b
                    ><span
                      >{{ eventAt(day.key, t.id, p).gradeLevel }}/{{
                        eventAt(day.key, t.id, p).classRoom
                      }}</span
                    ><small
                      v-if="eventAt(day.key, t.id, p).substitute"
                      class="substitute-name"
                      >สอนแทน:
                      {{ eventAt(day.key, t.id, p).teacherName }}</small
                    >
                  </button>
                </div></template
              >
            </div>
          </div>
        </div>
      </template></Card
    >

    <section class="class-export-sheet" aria-hidden="true">
      <article v-for="g in exportGroups" :key="g.key" class="class-report-page">
        <header class="class-report-header">
          <h2>ตารางสอนชั้น {{ g.grade }} / ห้อง {{ g.room }}</h2>
          <h2>
            {{ schoolReport.schoolName }} ภาคเรียนที่
            {{ schoolReport.semester }} ปีการศึกษา
            {{ schoolReport.academicYear }}
          </h2>
        </header>
        <!--  -->
        <table class="class-report-table">
          <thead>
            <tr>
              <th rowspan="2">วัน</th>
              <th v-for="p in exportMorningPeriods" :key="`m-${p.key}`">
                {{ p.key }}
              </th>
              <th v-if="showExportLunch" rowspan="2" class="lunch-column">
                พักกลางวัน
              </th>
              <th v-for="p in exportAfternoonPeriods" :key="`a-${p.key}`">
                {{ p.key }}
              </th>
            </tr>
            <tr>
              <th v-for="p in exportMorningPeriods" :key="`mt-${p.key}`">
                {{ p.start.replace(":", ".") }}-{{ p.end.replace(":", ".") }}
              </th>
              <th v-for="p in exportAfternoonPeriods" :key="`at-${p.key}`">
                {{ p.start.replace(":", ".") }}-{{ p.end.replace(":", ".") }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in exportDays" :key="d.key">
              <th>{{ d.label }}</th>
              <td v-for="p in exportMorningPeriods" :key="p.key">
                <template v-if="groupEventAt(g, d.key, p)"
                  ><strong>{{ groupEventAt(g, d.key, p).subjectName }}</strong
                  ><span
                    >({{ exportTeacherName(groupEventAt(g, d.key, p)) }})</span
                  ></template
                >
              </td>
              <td v-if="showExportLunch" class="lunch-column"></td>
              <td v-for="p in exportAfternoonPeriods" :key="p.key">
                <template v-if="groupEventAt(g, d.key, p)"
                  ><strong>{{ groupEventAt(g, d.key, p).subjectName }}</strong
                  ><span
                    >({{ exportTeacherName(groupEventAt(g, d.key, p)) }})</span
                  ></template
                >
              </td>
            </tr>
          </tbody>
        </table>
        <footer class="substitute-report-signatures">
          <div>
            <p>
              ลงชื่อ............................................................
            </p>
            <p>({{ schoolReport.academicHeadName }})</p>
            <p>{{ schoolReport.academicHeadTitle }}</p>
          </div>
          <div>
            <p>
              ลงชื่อ............................................................
            </p>
            <p>({{ schoolReport.directorName }})</p>
            <p>{{ schoolReport.directorTitle }}</p>
            <!-- <p>{{ schoolReport.schoolName }}</p> -->
          </div>
        </footer>
      </article>
    </section>

    <section class="substitute-report-sheet" aria-hidden="true">
      <div class="report-logo"><img :src="schoolLogo" alt="ตราโรงเรียน" /></div>
      <header class="substitute-report-header">
        <h2>แบบบันทึกการจัดบุคลากรสอนแทน{{ schoolReport.schoolName }}</h2>
        <h3>
          ภาคเรียนที่ {{ schoolReport.semester }} ปีการศึกษา
          {{ schoolReport.academicYear }}
        </h3>
        <p>
          ประจำวันที่ ............ ที่ ............ เดือน
          ........................ พ.ศ. ............
        </p>
      </header>
      <table class="substitute-report-table">
        <thead>
          <tr>
            <th>ชั่วโมงที่</th>
            <th>วิชา</th>
            <th>ชั้น</th>
            <th>ชื่อครูผู้สอน</th>
            <th>ลงชื่อผู้สอนแทน</th>
            <th>ลงชื่อผู้สอนแทน<br />รับทราบ</th>
            <th>หมายเหตุที่<br />จัดสอนแทน</th>
            <th>หมายเหตุ</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in substituteReportRows" :key="`sub-report-${row.id}`">
            <td>{{ reportPeriodNumber(row) }}</td>
            <td>{{ row.subjectName || "-" }}</td>
            <td>{{ reportClassName(row) }}</td>
            <td>{{ reportOwnerName(row) }}</td>
            <td>{{ reportSubstituteName(row) }}</td>
            <td></td>
            <td></td>
            <td></td>
          </tr>
          <tr
            v-for="blank in Math.max(0, 12 - substituteReportRows.length)"
            :key="`blank-${blank}`"
          >
            <td>&nbsp;</td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
          </tr>
        </tbody>
      </table>
      <footer class="substitute-report-signatures">
        <div>
          <p>
            ลงชื่อ............................................................
          </p>
          <p>({{ schoolReport.academicHeadName }})</p>
          <p>{{ schoolReport.academicHeadTitle }}</p>
        </div>
        <div>
          <p>
            ลงชื่อ............................................................
          </p>
          <p>({{ schoolReport.directorName }})</p>
          <p>{{ schoolReport.directorTitle }}</p>
          <!-- <p>{{ schoolReport.schoolName }}</p> -->
        </div>
      </footer>
    </section>

    <Dialog
      v-model:visible="editorVisible"
      modal
      :header="form.id ? 'แก้ไขคาบเรียน' : 'เพิ่มคาบเรียน'"
      :style="{ width: 'min(42rem,95vw)' }"
      ><form class="form" @submit.prevent="saveEvent">
        <template v-if="form.id && form.substitute"
          ><div class="locked-lesson">
            <div>
              <small>วิชา / ชั้น / ห้อง</small
              ><b
                >{{ selectedOffering?.subjectName || "-" }} •
                {{ selectedOffering?.gradeLevel || "-" }}/{{
                  selectedOffering?.room || "-"
                }}</b
              >
            </div>
            <div>
              <small>เจ้าของคาบ</small
              ><b>{{ teacherDisplayName(form.lessonOwnerTeacherId) }}</b>
            </div>
          </div>
          <label
            ><span>ครูผู้สอนแทน *</span
            ><Select
              v-model="form.teacherId"
              :options="substituteTeacherOptions"
              option-label="label"
              option-value="value"
              option-disabled="disabled"
              filter
              fluid
          /></label>
          <div v-if="form.teacherId" class="selected-substitute-info">
            <b>{{ teacherDisplayName(form.teacherId) }}</b
            ><span
              >สอนแทนวัน{{
                weekDays.find((d) => d.key === Number(form.dayOfWeek))?.label
              }}
              • {{ periodLabelFromTime(form.startTime) }} •
              {{ form.startTime }}-{{ form.endTime }}</span
            >
          </div>
          <div class="grid">
            <label
              ><span>วันเริ่ม *</span
              ><input v-model="form.substituteStartDate" type="date" /></label
            ><label
              ><span>วันสิ้นสุด *</span
              ><input v-model="form.substituteEndDate" type="date"
            /></label></div></template
        ><template v-else
          ><label
            ><span>วิชา / ชั้น / ห้อง *</span
            ><Select
              v-model="form.offeringId"
              :options="offeringOptions"
              option-label="label"
              option-value="value"
              filter
              fluid
              @change="loadBuildingsForOffering"
          /></label>
          <div class="grid">
            <label
              ><span>ครูผู้สอน *</span
              ><Select
                v-model="form.teacherId"
                :options="teacherOptions"
                option-label="label"
                option-value="value"
                :disabled="!!form.id"
                fluid /></label
            ><label
              ><span>เจ้าของคาบ *</span
              ><Select
                v-model="form.lessonOwnerTeacherId"
                :options="ownerTeacherOptions"
                option-label="label"
                option-value="value"
                :disabled="!!form.id"
                fluid
            /></label>
          </div>
          <div class="grid">
            <label
              ><span>วัน *</span
              ><Select
                v-model="form.dayOfWeek"
                :options="freeDayOptions"
                option-label="label"
                option-value="key"
                fluid /></label
            ><label
              ><span>ประเภท</span
              ><Select
                v-model="form.substitute"
                :options="
                  form.id
                    ? [
                        { label: 'คาบปกติ', value: false },
                        { label: 'สอนแทน', value: true },
                      ]
                    : [{ label: 'คาบปกติ', value: false }]
                "
                option-label="label"
                option-value="value"
                fluid
            /></label>
          </div>
          <div class="grid">
            <label
              ><span>คาบ *</span
              ><Select
                v-model="form.startTime"
                :options="freeTimeOptions"
                option-label="label"
                option-value="value"
                @change="onFreeTimeChange"
                fluid /></label
            ><label
              ><span>สิ้นสุด</span><input :value="form.endTime" disabled
            /></label>
          </div>
          <div class="auto-location">
            <b>{{ autoLocationText }}</b>
          </div></template
        >
        <div class="actions">
          <Button
            v-if="form.id && form.originalSubstitute"
            type="button"
            label="ยกเลิกสอนแทน"
            severity="warn"
            outlined
            @click="cancelSubstitute"
          /><Button
            v-else-if="form.id"
            type="button"
            label="ลบคาบ"
            severity="danger"
            text
            @click="deleteEvent(form)"
          /><span /><Button
            type="submit"
            label="บันทึก"
            icon="pi pi-save"
            :loading="saving"
          />
        </div></form
    ></Dialog>
  </div>
</template>

<style scoped>
.schedule-page {
  --line: #dce7f2;
  --navy: #102b52;
  --blue: #167df5;
  --muted: #71839d;
  display: grid;
  gap: 16px;
}
.hero {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 18px;
  padding: 22px 26px;
  border: 1px solid var(--line);
  border-radius: 20px;
  background: linear-gradient(110deg, #fff, #f2f8ff 58%, #effbf6);
  box-shadow: 0 12px 30px rgba(24, 57, 94, 0.06);
}
.hero h1 {
  margin: 10px 0 4px;
  color: var(--navy);
  font-size: 30px;
}
.hero p {
  margin: 0;
  color: var(--muted);
  font-size: 12px;
}
.hero-actions,
.legend,
.actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
.kicker {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 6px 10px;
  border-radius: 999px;
  background: #e7f2ff;
  color: var(--blue);
  font-size: 9px;
  font-weight: 800;
}
.hero-actions :deep(.p-button) {
  border-radius: 9px;
}
.filter-panel {
  padding: 14px;
  border: 1px solid var(--line);
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 8px 22px rgba(24, 57, 94, 0.04);
}
.filter-title {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 11px;
}
.filter-title b,
.filter-title small {
  display: block;
}
.filter-title b {
  color: #274664;
  font-size: 14px;
}
.filter-title small {
  margin-top: 2px;
  color: #8293a6;
  font-size: 9px;
}
.filters {
  display: grid;
  grid-template-columns: repeat(4, minmax(140px, 1fr));
  gap: 8px;
}
.filter-panel :deep(.p-select) {
  border-color: #d6e3ef;
  border-radius: 9px;
  background: #fbfdff;
  box-shadow: none;
}
.legend {
  flex-wrap: wrap;
  padding: 0 4px;
  color: #587089;
  font-size: 10px;
}
.legend span {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: #2c8aef;
}
.dot.substitute {
  background: #ef8b00;
}
.all-days-stack {
  display: grid;
  gap: 14px;
}
.teacher-sheet-wrap {
  overflow: auto;
  border: 1px solid #dce7f2;
  border-radius: 15px;
  background: #fff;
  box-shadow: 0 8px 24px rgba(24, 57, 94, 0.05);
}
.teacher-sheet-title {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 10px 14px;
  color: #203f5e;
  font-size: 14px;
  font-weight: 800;
}
.day-title-dot {
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: currentColor;
}
.day-1 {
  background: linear-gradient(90deg, #fff8dc, #fffdf4);
  color: #eeb31c;
}
.day-2 {
  background: linear-gradient(90deg, #fff0f7, #fff9fc);
  color: #e84b99;
}
.day-3 {
  background: linear-gradient(90deg, #eaf9ef, #f8fdf9);
  color: #24a968;
}
.day-4 {
  background: linear-gradient(90deg, #fff4e6, #fffaf5);
  color: #ef8b27;
}
.day-5 {
  background: linear-gradient(90deg, #eaf5ff, #f8fcff);
  color: #348bd8;
}
.teacher-sheet {
  display: grid;
  grid-template-columns: 135px repeat(6, minmax(118px, 1fr));
  min-width: 850px;
  border-top: 1px solid #dce7f2;
}
.teacher-head,
.period-head,
.teacher-cell,
.lesson-cell {
  border-right: 1px solid #dce7f2;
  border-bottom: 1px solid #dce7f2;
  min-height: 44px;
}
.teacher-head,
.period-head {
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f2f7fc;
  color: #294967;
}
.teacher-head {
  font-size: 16px;
  font-weight: 800;
}
.period-head {
  flex-direction: column;
  padding: 4px;
}
.period-head b {
  font-size: 16px;
}
.period-head small {
  margin-top: 2px;
  color: #8093a7;
  font-size: 14px;
}
.teacher-cell {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 9px;
  background: #fbfdff;
  color: #2d4c69;
}
.teacher-cell b {
  font-size: 16px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.teacher-avatar {
  width: 26px;
  height: 26px;
  display: grid;
  place-items: center;
  flex: 0 0 26px;
  border: 1px solid transparent;
  border-radius: 50%;
  font-size: 9px;
  font-weight: 800;
}
.lesson-cell {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;
  padding: 4px;
  background: #fff;
  cursor: pointer;
  transition: background 0.15s ease;
}
.lesson-cell:hover {
  background: #f8fbff;
}
.lesson-empty {
  color: #c3ced9;
  font-size: 9px;
}
.lesson-chip {
  position: relative;
  width: 100%;
  min-height: 34px;
  height: auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1px;
  padding: 4px 7px 4px 10px;
  border: 1px solid transparent;
  border-radius: 7px;
  cursor: pointer;
  box-shadow: 0 2px 5px rgba(40, 77, 116, 0.04);
  overflow: hidden;
}
.lesson-chip::before {
  content: "";
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 3px;
  background: currentColor;
  opacity: 0.85;
}
.lesson-chip b {
  font-size: 14px;
  line-height: 1.1;
}
.lesson-chip span {
  font-size: 14px;
  opacity: 0.86;
}
.lesson-chip.sub {
  background: #fff3dc !important;
  border-color: #f2cb83 !important;
  color: #8b5907 !important;
}
.lesson-chip.sub::before {
  background: #ef8b00;
}
.substitute-name {
  margin-top: 2px;
  padding: 2px 5px;
  border-radius: 99px;
  background: #f52e2e;
  color: #fff;
  font-size: 12px;
  font-weight: 700;
}
.form {
  display: grid;
  gap: 14px;
}
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.form label {
  display: grid;
  gap: 6px;
}
.form input {
  height: 42px;
  padding: 0 12px;
  border: 1px solid #d3dfeb;
  border-radius: 9px;
}
.locked-lesson {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  padding: 12px;
  border-radius: 10px;
  background: #f8fbfe;
}
.selected-substitute-info {
  padding: 11px;
  border: 1px solid #86d8b4;
  border-radius: 10px;
  background: #effbf5;
}
.selected-substitute-info b,
.selected-substitute-info span {
  display: block;
}
.selected-substitute-info span {
  margin-top: 3px;
  color: #527466;
  font-size: 10px;
}
.actions {
  justify-content: space-between;
  margin-top: 4px;
}
.class-export-sheet,
.substitute-report-sheet {
  display: none;
}
@media (max-width: 900px) {
  .filters {
    grid-template-columns: 1fr 1fr;
  }
}
@media (max-width: 700px) {
  .filters,
  .grid,
  .locked-lesson {
    grid-template-columns: 1fr;
  }
  .hero {
    align-items: flex-start;
    flex-direction: column;
  }
  .hero-actions {
    width: 100%;
    flex-direction: column;
  }
  .hero-actions :deep(.p-button) {
    width: 100%;
  }
  .actions {
    align-items: stretch;
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
  * {
    font-family: "TH Sarabun New", "Sarabun", Tahoma, sans-serif !important;
  }
  html,
  body {
    margin: 0 !important;
    padding: 0 !important;
    background: #fff !important;
  }
  body.substitute-report-printing .topbar,
  body.substitute-report-printing .sidebar,
  body.schedule-table-printing .topbar,
  body.schedule-table-printing .sidebar {
    display: none !important;
  }
  body.substitute-report-printing .main,
  body.substitute-report-printing .content,
  body.substitute-report-printing .schedule-page,
  body.schedule-table-printing .main,
  body.schedule-table-printing .content,
  body.schedule-table-printing .schedule-page {
    display: block !important;
    margin: 0 !important;
    padding: 0 !important;
    width: 100% !important;
  }
  body.substitute-report-printing .schedule-page > * {
    display: none !important;
  }
  body.substitute-report-printing .schedule-page > .substitute-report-sheet {
    display: block !important;
  }
  body.schedule-table-printing .schedule-page > * {
    display: none !important;
  }
  body.schedule-table-printing .schedule-page > .class-export-sheet {
    display: block !important;
  }
  .report-logo {
    display: flex !important;
    align-items: center;
    justify-content: center;
    height: 18mm;
    margin: 0 0 1mm !important;
  }
  .report-logo img {
    display: block !important;
    width: 16mm !important;
    height: 16mm !important;
    object-fit: contain !important;
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }
  .substitute-report-header {
    text-align: center !important;
    margin: 0 0 2mm !important;
  }
  .substitute-report-header h2,
  .substitute-report-header h3 {
    margin: 0 !important;
    font-size: 18px !important;
    font-weight: 700 !important;
    line-height: 1.05 !important;
  }
  .substitute-report-header h3 {
    margin-top: 1mm !important;
  }
  .substitute-report-header p {
    margin: 1mm 0 0 !important;
    font-size: 16px !important;
    line-height: 1.05 !important;
  }
  .substitute-report-table {
    width: 100% !important;
    border-collapse: collapse !important;
    table-layout: fixed !important;
  }
  .substitute-report-table th,
  .substitute-report-table td {
    border: 1px solid #000 !important;
    padding: 0.5mm 0.8mm !important;
    font-size: 16px !important;
    line-height: 1 !important;
    text-align: center !important;
    vertical-align: middle !important;
  }
  .substitute-report-table th {
    height: 10mm !important;
    font-weight: 700 !important;
  }
  .substitute-report-table tbody tr {
    height: 7mm !important;
    break-inside: avoid !important;
  }
  .substitute-report-table th:nth-child(1) {
    width: 11mm !important;
  }
  .substitute-report-table th:nth-child(2) {
    width: 34mm !important;
  }
  .substitute-report-table th:nth-child(3) {
    width: 14mm !important;
  }
  .substitute-report-table th:nth-child(4) {
    width: 44mm !important;
  }
  .substitute-report-table th:nth-child(5) {
    width: 44mm !important;
  }
  .substitute-report-table th:nth-child(6) {
    width: 30mm !important;
  }
  .substitute-report-table th:nth-child(7) {
    width: 34mm !important;
  }
  .substitute-report-table th:nth-child(8) {
    width: 22mm !important;
  }
  .substitute-report-signatures,
  .class-report-signatures {
    display: grid !important;
    grid-template-columns: 1fr 1fr !important;
    text-align: center !important;
    break-inside: avoid !important;
  }
  .substitute-report-signatures {
    gap: 60mm !important;
    margin: 8mm 16mm 0 !important;
  }
  .substitute-report-signatures,
  .substitute-report-signatures p,
  .class-report-signatures,
  .class-report-signatures p {
    font-size: 16px !important;
    line-height: 1.05 !important;
  }
  .substitute-report-signatures p {
    margin: 0 0 1mm !important;
  }
  body.schedule-table-printing .class-report-page {
    width: 100% !important;
    break-after: page;
    page-break-after: always;
  }
  body.schedule-table-printing .class-report-page:last-child {
    break-after: auto;
    page-break-after: auto;
  }
  .class-report-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 15mm;
    margin: 0 2mm 3mm;
  }
  .class-report-header h2 {
    margin: 0 !important;
    font-size: 18px !important;
  }
  .class-report-filter-summary {
    margin: 0 2mm 3mm;
    font-size: 14px !important;
  }
  .class-report-table {
    width: 100% !important;
    table-layout: fixed !important;
    border-collapse: collapse !important;
  }
  .class-report-table th,
  .class-report-table td {
    border: 1px solid #000 !important;
    padding: 1mm !important;
    font-size: 16px !important;
    text-align: center !important;
    vertical-align: middle !important;
  }
  .class-report-table thead th,
  .class-report-table .lunch-column {
    background: #f7cfad !important;
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }
  .class-report-table tbody tr {
    height: 18mm;
  }
  .class-report-table td strong,
  .class-report-table td span {
    display: block;
  }
  .class-report-signatures {
    gap: 25mm !important;
    margin: 12mm 28mm 0 !important;
  }
}
</style>
