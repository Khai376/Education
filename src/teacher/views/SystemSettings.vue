<script setup>
import { onMounted, ref } from "vue";
import Button from "primevue/button";
import Card from "primevue/card";
import Message from "primevue/message";
import Select from "primevue/select";
import { rpc } from "../../services/supabase";

const loading = ref(false);
const saving = ref(false);
const message = ref("");
const success = ref("");

const semesterOptions = [
  { label: "ภาคเรียนที่ 1", value: "1" },
  { label: "ภาคเรียนที่ 2", value: "2" },
];

const form = ref({
  schoolName: "โรงเรียนบ้านบ่อ",
  semester: "2",
  academicYear: "2569",
  academicHeadTitle: "หัวหน้าฝ่ายวิชาการ",
  academicHeadName: "นางสาวพิกุลทอง ถ่องตะคุ",
  directorTitle: "ผู้อำนวยการ",
  directorName: "นายจิรวัฒน์ แสงสุรินทร์",
});

async function loadSettings() {
  loading.value = true;
  message.value = "";
  try {
    const data = await rpc("teacher_school_settings_get");
    if (data) {
      form.value = {
        schoolName: data.schoolName || "โรงเรียนบ้านบ่อ",
        semester: String(data.semester || "2"),
        academicYear: String(data.academicYear || "2569"),
        academicHeadTitle: data.academicHeadTitle || "หัวหน้าฝ่ายวิชาการ",
        academicHeadName: data.academicHeadName || "",
        directorTitle: data.directorTitle || "ผู้อำนวยการ",
        directorName: data.directorName || "",
      };
    }
  } catch (error) {
    message.value = error?.message || "ไม่สามารถโหลดการตั้งค่าระบบได้";
  } finally {
    loading.value = false;
  }
}

async function saveSettings() {
  message.value = "";
  success.value = "";

  if (!form.value.schoolName.trim()) return (message.value = "กรุณากรอกชื่อโรงเรียน");
  if (!form.value.semester) return (message.value = "กรุณาเลือกภาคเรียน");
  if (!/^25\d{2}$/.test(String(form.value.academicYear))) {
    return (message.value = "ปีการศึกษาต้องเป็น พ.ศ. 4 หลัก เช่น 2569");
  }

  saving.value = true;
  try {
    await rpc("teacher_school_settings_save", {
      p_payload: {
        schoolName: form.value.schoolName.trim(),
        semester: form.value.semester,
        academicYear: String(form.value.academicYear),
        academicHeadTitle: form.value.academicHeadTitle.trim(),
        academicHeadName: form.value.academicHeadName.trim(),
        directorTitle: form.value.directorTitle.trim(),
        directorName: form.value.directorName.trim(),
      },
    });
    success.value = "บันทึกการตั้งค่าระบบเรียบร้อยแล้ว";
    await loadSettings();
  } catch (error) {
    message.value = error?.message || "ไม่สามารถบันทึกการตั้งค่าระบบได้";
  } finally {
    saving.value = false;
  }
}

onMounted(loadSettings);
</script>

<template>
  <div class="settings-page">
    <section class="hero">
      <div>
        <span class="kicker"><i class="pi pi-cog" /> SYSTEM SETTINGS</span>
        <h1>ตั้งค่าระบบ</h1>
        <p>กำหนดข้อมูลโรงเรียน ภาคเรียน ปีการศึกษา และข้อมูลผู้ลงนามในรายงาน</p>
      </div>
    </section>

    <Message v-if="message" severity="error" closable @close="message = ''">{{ message }}</Message>
    <Message v-if="success" severity="success" closable @close="success = ''">{{ success }}</Message>

    <Card>
      <template #content>
        <form class="settings-form" @submit.prevent="saveSettings">
          <div class="section-title">
            <i class="pi pi-building" />
            <div><b>ข้อมูลโรงเรียนและปีการศึกษา</b><small>ข้อมูลนี้จะแสดงบนตารางสอนและใบรายงาน</small></div>
          </div>

          <label class="full"><span>ชื่อโรงเรียน *</span><input v-model="form.schoolName" type="text" :disabled="loading || saving" /></label>

          <div class="grid">
            <label>
              <span>ภาคเรียน *</span>
              <Select v-model="form.semester" :options="semesterOptions" option-label="label" option-value="value" fluid :disabled="loading || saving" />
            </label>
            <label><span>ปีการศึกษา (พ.ศ.) *</span><input v-model="form.academicYear" type="text" inputmode="numeric" maxlength="4" placeholder="2569" :disabled="loading || saving" /></label>
          </div>

          <div class="section-title sign-title">
            <i class="pi pi-pen-to-square" />
            <div><b>ผู้ลงนาม</b><small>ใช้ในส่วนท้ายของเอกสาร Export</small></div>
          </div>

          <div class="grid">
            <label><span>ชื่อหัวหน้าฝ่ายวิชาการ</span><input v-model="form.academicHeadName" type="text" :disabled="loading || saving" /></label>
            <label><span>ตำแหน่ง</span><input v-model="form.academicHeadTitle" type="text" :disabled="loading || saving" /></label>
          </div>

          <div class="grid">
            <label><span>ชื่อผู้อำนวยการ</span><input v-model="form.directorName" type="text" :disabled="loading || saving" /></label>
            <label><span>ตำแหน่ง</span><input v-model="form.directorTitle" type="text" :disabled="loading || saving" /></label>
          </div>

          <div class="preview">
            <small>ตัวอย่างหัวรายงาน</small>
            <b>ตารางสอน {{ form.schoolName }}</b>
            <span>ภาคเรียนที่ {{ form.semester }} ปีการศึกษา {{ form.academicYear }}</span>
          </div>

          <div class="actions">
            <Button type="submit" label="บันทึกการตั้งค่า" icon="pi pi-save" :loading="saving" :disabled="loading" />
          </div>
        </form>
      </template>
    </Card>
  </div>
</template>

<style scoped>
.settings-page{display:grid;gap:14px}.hero{padding:20px 24px;border:1px solid #dce7f2;border-radius:20px;background:linear-gradient(110deg,#fff,#f2f8ff 60%,#effbf6)}.kicker{display:inline-flex;gap:7px;padding:6px 10px;border-radius:999px;color:#167df5;background:#e7f2ff;font-size:10px;font-weight:800}.hero h1{margin:11px 0 4px;color:#102b52}.hero p{margin:0;color:#71839d}.settings-form{display:grid;gap:16px}.section-title{display:flex;align-items:center;gap:10px;padding-bottom:10px;border-bottom:1px solid #e4edf6;color:#294766}.section-title i{color:#167df5;font-size:18px}.section-title b,.section-title small{display:block}.section-title small{margin-top:2px;color:#71839d;font-size:11px}.sign-title{margin-top:8px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}.settings-form label{display:grid;gap:6px;color:#294766;font-size:13px;font-weight:700}.settings-form input{height:44px;padding:0 12px;border:1px solid #d3dfeb;border-radius:9px;font:inherit}.preview{display:grid;gap:3px;padding:14px;border:1px solid #cfe1f2;border-radius:11px;background:#f6faff;text-align:center}.preview small{color:#71839d}.preview b{color:#102b52}.actions{display:flex;justify-content:flex-end}@media(max-width:700px){.grid{grid-template-columns:1fr}.actions :deep(.p-button){width:100%}}
</style>
