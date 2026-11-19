-- Education Hub migration: adds attendance, gradebook and class schedule.
-- Safe for an existing Exam Tutor database: existing exam tables are not dropped.

create extension if not exists pgcrypto;

create table if not exists public.class_students (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references auth.users(id) on delete cascade,
  student_code text not null check (length(trim(student_code)) between 1 and 50),
  student_name text not null check (length(trim(student_name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (teacher_id, student_code)
);

create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  session_date date not null default current_date,
  code text not null unique check (length(code) = 6),
  status text not null default 'open' check (status in ('open','closed')),
  opened_at timestamptz not null default now(),
  late_after timestamptz not null,
  closed_at timestamptz
);

create unique index if not exists one_open_attendance_per_teacher
  on public.attendance_sessions(teacher_id) where status = 'open';

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.attendance_sessions(id) on delete cascade,
  student_id uuid not null references public.class_students(id) on delete cascade,
  status text not null check (status in ('present','late')),
  checked_at timestamptz not null default now(),
  unique (session_id, student_id)
);

create table if not exists public.grade_items (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  category text not null default 'เก็บคะแนน',
  max_score numeric(10,2) not null check (max_score > 0 and max_score <= 10000),
  weight numeric(6,2) not null default 0 check (weight between 0 and 100),
  term text,
  item_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists public.grades (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.grade_items(id) on delete cascade,
  student_id uuid not null references public.class_students(id) on delete cascade,
  score numeric(10,2) not null check (score >= 0),
  note text,
  updated_at timestamptz not null default now(),
  unique (item_id, student_id)
);

create table if not exists public.class_schedules (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  day_of_week int not null check (day_of_week between 1 and 7),
  start_time time not null,
  end_time time not null,
  room text,
  online_url text,
  note text,
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);

alter table public.class_students enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.grade_items enable row level security;
alter table public.grades enable row level security;
alter table public.class_schedules enable row level security;

revoke all on public.class_students, public.attendance_sessions, public.attendance_records,
  public.grade_items, public.grades, public.class_schedules from anon, authenticated;

create or replace function public.teacher_attendance_create(
  p_title text,
  p_session_date date,
  p_grace_minutes int default 15
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  new_code text;
  new_session attendance_sessions;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  if length(trim(coalesce(p_title,''))) not between 1 and 120 then
    raise exception 'กรุณากรอกชื่อวิชาหรือห้องเรียน';
  end if;
  if p_grace_minutes not between 0 and 180 then
    raise exception 'เวลาตรงเวลาต้องอยู่ระหว่าง 0-180 นาที';
  end if;

  update attendance_sessions
     set status = 'closed', closed_at = now()
   where teacher_id = auth.uid() and status = 'open';

  loop
    new_code := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 6));
    exit when not exists (select 1 from attendance_sessions where code = new_code);
  end loop;

  insert into attendance_sessions(teacher_id,title,session_date,code,late_after)
  values(auth.uid(), trim(p_title), coalesce(p_session_date,current_date), new_code,
         now() + make_interval(mins => p_grace_minutes))
  returning * into new_session;

  return jsonb_build_object('id',new_session.id,'code',new_session.code);
end;
$$;

create or replace function public.teacher_attendance_close(p_session_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  update attendance_sessions
     set status = 'closed', closed_at = now()
   where id = p_session_id and teacher_id = auth.uid();
  if not found then raise exception 'ไม่พบรอบเช็คชื่อ'; end if;
end;
$$;

create or replace function public.student_attendance_checkin(
  p_code text,
  p_student_code text,
  p_student_name text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  current_session attendance_sessions;
  current_student class_students;
  current_record attendance_records;
  attendance_status text;
begin
  if length(trim(coalesce(p_code,''))) <> 6 then raise exception 'รหัสเช็คชื่อไม่ถูกต้อง'; end if;
  if length(trim(coalesce(p_student_code,''))) not between 1 and 50 then raise exception 'กรุณากรอกเลขประจำตัวนักเรียน'; end if;
  if length(trim(coalesce(p_student_name,''))) not between 1 and 120 then raise exception 'กรุณากรอกชื่อ - นามสกุล'; end if;

  select * into current_session
    from attendance_sessions
   where code = upper(trim(p_code)) and status = 'open'
   order by opened_at desc limit 1;
  if current_session.id is null then raise exception 'ไม่พบรอบเช็คชื่อ หรือรอบนี้ปิดแล้ว'; end if;

  insert into class_students(teacher_id,student_code,student_name)
  values(current_session.teacher_id, trim(p_student_code), trim(p_student_name))
  on conflict(teacher_id,student_code)
  do update set student_name = excluded.student_name, updated_at = now()
  returning * into current_student;

  attendance_status := case when now() > current_session.late_after then 'late' else 'present' end;

  insert into attendance_records(session_id,student_id,status)
  values(current_session.id,current_student.id,attendance_status)
  on conflict(session_id,student_id)
  do update set status = attendance_records.status
  returning * into current_record;

  return jsonb_build_object(
    'title',current_session.title,
    'sessionDate',current_session.session_date,
    'studentName',current_student.student_name,
    'status',current_record.status,
    'checkedAt',current_record.checked_at
  );
end;
$$;

create or replace function public.teacher_attendance_dashboard()
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  active_json jsonb;
  sessions_json jsonb;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;

  select jsonb_build_object(
    'id',s.id,
    'title',s.title,
    'sessionDate',s.session_date,
    'code',s.code,
    'status',s.status,
    'openedAt',s.opened_at,
    'lateAfter',s.late_after,
    'records',coalesce((
      select jsonb_agg(jsonb_build_object(
        'studentCode',cs.student_code,
        'studentName',cs.student_name,
        'status',ar.status,
        'checkedAt',ar.checked_at
      ) order by ar.checked_at)
      from attendance_records ar
      join class_students cs on cs.id = ar.student_id
      where ar.session_id = s.id
    ),'[]'::jsonb)
  ) into active_json
  from attendance_sessions s
  where s.teacher_id = auth.uid() and s.status = 'open'
  order by s.opened_at desc limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',x.id,
    'title',x.title,
    'sessionDate',x.session_date,
    'code',x.code,
    'status',x.status,
    'attendeeCount',(select count(*) from attendance_records ar where ar.session_id = x.id)
  ) order by x.opened_at desc),'[]'::jsonb)
  into sessions_json
  from (select * from attendance_sessions where teacher_id = auth.uid() order by opened_at desc limit 10) x;

  return jsonb_build_object('active',active_json,'sessions',sessions_json);
end;
$$;

create or replace function public.grade_letter(p_percent numeric)
returns text language sql immutable
as $$
  select case
    when p_percent >= 80 then 'A'
    when p_percent >= 75 then 'B+'
    when p_percent >= 70 then 'B'
    when p_percent >= 65 then 'C+'
    when p_percent >= 60 then 'C'
    when p_percent >= 55 then 'D+'
    when p_percent >= 50 then 'D'
    else 'F'
  end;
$$;

create or replace function public.teacher_grade_item_create(
  p_title text,
  p_category text,
  p_max_score numeric,
  p_weight numeric,
  p_term text,
  p_item_date date
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare new_item grade_items;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  if length(trim(coalesce(p_title,''))) not between 1 and 120 then raise exception 'กรุณากรอกชื่อรายการคะแนน'; end if;
  if p_max_score <= 0 or p_max_score > 10000 then raise exception 'คะแนนเต็มไม่ถูกต้อง'; end if;
  if p_weight < 0 or p_weight > 100 then raise exception 'น้ำหนักต้องอยู่ระหว่าง 0-100'; end if;

  insert into grade_items(teacher_id,title,category,max_score,weight,term,item_date)
  values(auth.uid(),trim(p_title),left(trim(coalesce(p_category,'เก็บคะแนน')),50),p_max_score,p_weight,
         nullif(left(trim(coalesce(p_term,'')),50),''),coalesce(p_item_date,current_date))
  returning * into new_item;
  return jsonb_build_object('id',new_item.id);
end;
$$;

create or replace function public.teacher_grade_save(
  p_item_id uuid,
  p_student_code text,
  p_student_name text,
  p_score numeric,
  p_note text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  current_item grade_items;
  current_student class_students;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  select * into current_item from grade_items where id = p_item_id and teacher_id = auth.uid();
  if current_item.id is null then raise exception 'ไม่พบรายการคะแนน'; end if;
  if length(trim(coalesce(p_student_code,''))) not between 1 and 50 then raise exception 'กรุณากรอกรหัสนักเรียน'; end if;
  if length(trim(coalesce(p_student_name,''))) not between 1 and 120 then raise exception 'กรุณากรอกชื่อนักเรียน'; end if;
  if p_score < 0 or p_score > current_item.max_score then
    raise exception 'คะแนนต้องอยู่ระหว่าง 0 ถึง %', current_item.max_score;
  end if;

  insert into class_students(teacher_id,student_code,student_name)
  values(auth.uid(),trim(p_student_code),trim(p_student_name))
  on conflict(teacher_id,student_code)
  do update set student_name = excluded.student_name, updated_at = now()
  returning * into current_student;

  insert into grades(item_id,student_id,score,note)
  values(current_item.id,current_student.id,p_score,nullif(left(trim(coalesce(p_note,'')),200),''))
  on conflict(item_id,student_id)
  do update set score = excluded.score, note = excluded.note, updated_at = now();
end;
$$;

create or replace function public.teacher_grade_item_delete(p_item_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  delete from grade_items where id = p_item_id and teacher_id = auth.uid();
  if not found then raise exception 'ไม่พบรายการคะแนน'; end if;
end;
$$;

create or replace function public.teacher_gradebook_get()
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare result_json jsonb;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',gi.id,
    'title',gi.title,
    'category',gi.category,
    'maxScore',gi.max_score,
    'weight',gi.weight,
    'term',gi.term,
    'itemDate',gi.item_date,
    'grades',coalesce((
      select jsonb_agg(jsonb_build_object(
        'studentCode',cs.student_code,
        'studentName',cs.student_name,
        'score',g.score,
        'percent',round((g.score / gi.max_score) * 100,2),
        'letter',grade_letter((g.score / gi.max_score) * 100),
        'note',g.note,
        'updatedAt',g.updated_at
      ) order by cs.student_code)
      from grades g join class_students cs on cs.id = g.student_id
      where g.item_id = gi.id
    ),'[]'::jsonb)
  ) order by gi.item_date desc,gi.created_at desc),'[]'::jsonb)
  into result_json
  from grade_items gi where gi.teacher_id = auth.uid();

  return result_json;
end;
$$;

create or replace function public.teacher_schedule_create(
  p_title text,
  p_day_of_week int,
  p_start_time time,
  p_end_time time,
  p_room text default null,
  p_online_url text default null,
  p_note text default null
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare new_schedule class_schedules;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  if length(trim(coalesce(p_title,''))) not between 1 and 120 then raise exception 'กรุณากรอกชื่อวิชา'; end if;
  if p_day_of_week not between 1 and 7 then raise exception 'วันไม่ถูกต้อง'; end if;
  if p_end_time <= p_start_time then raise exception 'เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม'; end if;
  if nullif(trim(coalesce(p_online_url,'')),'') is not null and trim(p_online_url) !~* '^https?://' then
    raise exception 'ลิงก์ออนไลน์ต้องขึ้นต้นด้วย http:// หรือ https://';
  end if;

  insert into class_schedules(teacher_id,title,day_of_week,start_time,end_time,room,online_url,note)
  values(auth.uid(),trim(p_title),p_day_of_week,p_start_time,p_end_time,
         nullif(left(trim(coalesce(p_room,'')),80),''),
         nullif(left(trim(coalesce(p_online_url,'')),500),''),
         nullif(left(trim(coalesce(p_note,'')),250),''))
  returning * into new_schedule;
  return jsonb_build_object('id',new_schedule.id);
end;
$$;

create or replace function public.teacher_schedule_delete(p_schedule_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  delete from class_schedules where id = p_schedule_id and teacher_id = auth.uid();
  if not found then raise exception 'ไม่พบรายการในตาราง'; end if;
end;
$$;

create or replace function public.teacher_schedule_get()
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare result_json jsonb;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',id,
    'title',title,
    'dayOfWeek',day_of_week,
    'startTime',start_time,
    'endTime',end_time,
    'room',room,
    'onlineUrl',online_url,
    'note',note
  ) order by day_of_week,start_time),'[]'::jsonb)
  into result_json
  from class_schedules where teacher_id = auth.uid();
  return result_json;
end;
$$;

revoke all on function public.grade_letter(numeric) from public;
grant execute on function public.student_attendance_checkin(text,text,text) to anon, authenticated;
grant execute on function public.teacher_attendance_create(text,date,int) to authenticated;
grant execute on function public.teacher_attendance_close(uuid) to authenticated;
grant execute on function public.teacher_attendance_dashboard() to authenticated;
grant execute on function public.teacher_grade_item_create(text,text,numeric,numeric,text,date) to authenticated;
grant execute on function public.teacher_grade_save(uuid,text,text,numeric,text) to authenticated;
grant execute on function public.teacher_grade_item_delete(uuid) to authenticated;
grant execute on function public.teacher_gradebook_get() to authenticated;
grant execute on function public.teacher_schedule_create(text,int,time,time,text,text,text) to authenticated;
grant execute on function public.teacher_schedule_delete(uuid) to authenticated;
grant execute on function public.teacher_schedule_get() to authenticated;
