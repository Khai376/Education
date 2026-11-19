# Education Hub PrimeVue

Vue 3 + Vite + PrimeVue + Supabase โดยแยกโค้ดฝั่งครู นักเรียน และเช็คชื่อ

## โครงสร้าง
- `src/teacher/views` หน้าครู
- `src/student/views` หน้านักเรียน
- `src/attendance/views` หน้าเช็คชื่อของนักเรียน
- `src/layouts` layout และเมนูครู
- `src/components` component ใช้ร่วมกัน
- `src/services` Supabase client/RPC
- `src/router` route ของระบบ
- `src/assets` CSS กลาง

## เริ่มใช้งาน
1. คัดลอก `.env.example` เป็น `.env`
2. กรอก `VITE_SUPABASE_URL` และ `VITE_SUPABASE_ANON_KEY`
3. รัน `npm install`
4. รัน `npm run dev`
5. เปิด `http://localhost:5173`

## Build
- `npm run build`
- `npm run preview`

## Route
- `/teacher`
- `/teacher/attendance`
- `/teacher/students`
- `/teacher/grades`
- `/teacher/schedule`
- `/student`
- `/attendance`
