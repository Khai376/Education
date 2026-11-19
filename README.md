# Education Hub

ระบบจัดการชั้นเรียนสำหรับครูและนักเรียน ประกอบด้วย:

- ติวข้อสอบแบบเรียลไทม์ ทีละข้อ พร้อมจับเวลาและดูผล
- เช็คชื่อออนไลน์ด้วยรหัส 6 ตัว พร้อมแยก “มาเรียน/มาสาย”
- สมุดคะแนนและการคำนวณเกรด A–F
- ตารางเรียนรายสัปดาห์ พร้อมห้องและลิงก์ออนไลน์
- Teacher Workspace แบบ Sidebar บนคอมพิวเตอร์ และ Bottom Navigation บนมือถือ

## เริ่มใช้งานกับฐานข้อมูลเดิม

> สำรองฐานข้อมูลก่อนเปลี่ยนแปลงทุกครั้ง

1. เปิด Supabase → SQL Editor → New query
2. รันไฟล์ `migration-education-modules.sql` **เพียงไฟล์เดียว** เพื่อเพิ่มระบบเช็คชื่อ คะแนน และตารางเรียน โดยไม่ลบตาราง Exam Tutor เดิม
3. **อย่ารัน `supabase.sql` กับฐานข้อมูลเดิม** เพราะเป็นสคริปต์ติดตั้งใหม่และมีคำสั่งลบตาราง Exam Tutor
4. ตรวจค่า `supabaseUrl` และ `supabaseAnonKey` ใน `config.js`
5. สร้าง/ตรวจสอบบัญชีครูใน Supabase Authentication และตาราง `teacher_accounts` ตามคู่มือ `SETUP-SUPABASE.md`

## รันใน VS Code

ต้องมี Node.js 20 ขึ้นไป จาก Terminal ในโฟลเดอร์โปรเจกต์:

```bash
npm start
```

ไม่ต้องติดตั้ง dependency เพิ่ม แล้วเปิด:

```text
http://localhost:3000
```

หน้าหลัก:

- `/` — หน้า Education Hub
- `/teacher.html` — ศูนย์จัดการครู
- `/student.html` — ระบบติวข้อสอบสำหรับนักเรียน
- `/attendance.html` — หน้าเช็คชื่อสำหรับนักเรียน

## ลำดับทดสอบแนะนำ

1. Login ครูที่ `teacher.html`
2. เปิดรอบเช็คชื่อและนำรหัส 6 ตัวไปกรอกที่ `attendance.html`
3. สร้างรายการคะแนนและบันทึกคะแนนนักเรียน
4. เพิ่มคาบในตารางเรียน
5. เปิดเมนูติวข้อสอบ → สร้างข้อสอบ → เริ่มรอบ → ให้นักเรียนเข้า `student.html`

## Deploy บน Render

Repository มี `render.yaml` ให้แล้ว ตั้ง Start Command เป็น `npm start` และตรวจว่า `config.js` ชี้ไปยัง Supabase project ที่ต้องการ
