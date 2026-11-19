-- Education Hub full installation: Exam Tutor core.
-- Existing exam data is recreated. For an upgrade that preserves data, run migration-education-modules.sql only.

create extension if not exists pgcrypto;

drop table if exists public.answers cascade;
drop table if exists public.attempts cascade;
drop table if exists public.tutor_sessions cascade;
drop table if exists public.questions cascade;
drop table if exists public.exams cascade;

create table if not exists public.teachers (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create table public.exams (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  duration_minutes int not null default 2 check (duration_minutes between 1 and 60),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams(id) on delete cascade,
  position int not null,
  text text not null,
  choices jsonb not null,
  correct_index int not null,
  unique (exam_id,position)
);

create table public.tutor_sessions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams(id) on delete cascade,
  status text not null default 'waiting' check (status in ('waiting','live','finished')),
  current_position int not null default -1,
  started_at timestamptz not null default now(),
  question_started_at timestamptz,
  ended_at timestamptz
);

create unique index one_open_session
  on public.tutor_sessions ((status in ('waiting','live')))
  where status in ('waiting','live');

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  token uuid unique not null default gen_random_uuid(),
  session_id uuid not null references public.tutor_sessions(id) on delete cascade,
  student_id text not null,
  student_name text not null,
  score int not null default 0,
  joined_at timestamptz not null default now(),
  unique (session_id,student_id)
);

create table public.answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  choice_index int not null,
  is_correct boolean not null,
  answered_at timestamptz not null default now(),
  unique (attempt_id,question_id)
);

alter table public.teachers enable row level security;
alter table public.exams enable row level security;
alter table public.questions enable row level security;
alter table public.tutor_sessions enable row level security;
alter table public.attempts enable row level security;
alter table public.answers enable row level security;

revoke all on public.teachers,public.exams,public.questions,public.tutor_sessions,public.attempts,public.answers from anon,authenticated;

create or replace function public.is_teacher()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from teachers where user_id = auth.uid()) $$;

create or replace function public.teacher_exam_get()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare e exams; result_json jsonb;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  select * into e from exams where created_by = auth.uid() order by created_at desc limit 1;
  if e.id is null then return null; end if;
  select jsonb_build_object(
    'id',e.id,
    'title',e.title,
    'durationMinutes',e.duration_minutes,
    'questions',coalesce(jsonb_agg(jsonb_build_object(
      'text',q.text,'choices',q.choices,'correct',q.correct_index
    ) order by q.position),'[]'::jsonb)
  ) into result_json
  from questions q where q.exam_id = e.id;
  return result_json;
end;
$$;

create or replace function public.teacher_exam_save(payload jsonb)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  exam_id uuid;
  item jsonb;
  item_count int := 0;
  duration_value int;
  correct_value int;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  if jsonb_typeof(payload->'questions') <> 'array' or jsonb_array_length(payload->'questions') not between 1 and 200 then
    raise exception 'ต้องมีข้อสอบ 1-200 ข้อ';
  end if;
  duration_value := (payload->>'durationMinutes')::int;
  if duration_value not between 1 and 60 then raise exception 'เวลาต่อข้อต้องอยู่ระหว่าง 1-60 นาที'; end if;

  insert into exams(title,duration_minutes,created_by)
  values(coalesce(nullif(trim(payload->>'title'),''),'ชุดติวข้อสอบ'),duration_value,auth.uid())
  returning id into exam_id;

  for item in select * from jsonb_array_elements(payload->'questions') loop
    if jsonb_typeof(item->'choices') <> 'array' or jsonb_array_length(item->'choices') not between 2 and 6 then
      raise exception 'ตัวเลือกต้องมี 2-6 ตัวเลือก';
    end if;
    correct_value := (item->>'correct')::int;
    if correct_value < 0 or correct_value >= jsonb_array_length(item->'choices') then
      raise exception 'ตำแหน่งเฉลยไม่ถูกต้อง';
    end if;
    insert into questions(exam_id,position,text,choices,correct_index)
    values(exam_id,item_count,coalesce(nullif(trim(item->>'text'),''),'ข้อ '||(item_count+1)),item->'choices',correct_value);
    item_count := item_count + 1;
  end loop;

  return jsonb_build_object('ok',true,'examId',exam_id);
end;
$$;

create or replace function public.teacher_round_start()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare exam_id uuid; session_id uuid;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  update tutor_sessions set status='finished',ended_at=now() where status in ('waiting','live');
  select id into exam_id from exams where created_by = auth.uid() order by created_at desc limit 1;
  if exam_id is null then raise exception 'ยังไม่มีชุดข้อสอบ'; end if;
  insert into tutor_sessions(exam_id,status,current_position) values(exam_id,'waiting',-1) returning id into session_id;
  return jsonb_build_object('sessionId',session_id);
end;
$$;

create or replace function public.teacher_release_next()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare current_session tutor_sessions; total_questions int;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  select s.* into current_session
  from tutor_sessions s join exams e on e.id=s.exam_id
  where s.status in ('waiting','live') and e.created_by=auth.uid()
  order by s.started_at desc limit 1 for update of s;
  if current_session.id is null then raise exception 'ยังไม่มีรอบติว'; end if;
  select count(*) into total_questions from questions where exam_id=current_session.exam_id;
  if current_session.current_position + 1 >= total_questions then raise exception 'ครบทุกข้อแล้ว กรุณาจบการติว'; end if;
  update tutor_sessions
     set status='live',current_position=current_position+1,question_started_at=now()
   where id=current_session.id;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function public.teacher_round_finish()
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  update tutor_sessions s set status='finished',ended_at=now()
  from exams e where s.exam_id=e.id and e.created_by=auth.uid() and s.status in ('waiting','live');
end;
$$;

create or replace function public.teacher_control_state()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  current_exam exams;
  current_session tutor_sessions;
  total_questions int := 0;
  student_count int := 0;
  answered_count int := 0;
  correct_count int := 0;
  remaining_seconds int := 0;
  expired boolean := false;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  select * into current_exam from exams where created_by=auth.uid() order by created_at desc limit 1;
  if current_exam.id is null then return null; end if;
  select count(*) into total_questions from questions where exam_id=current_exam.id;
  select * into current_session from tutor_sessions where exam_id=current_exam.id order by started_at desc limit 1;

  if current_session.id is not null then
    select count(*) into student_count from attempts where session_id=current_session.id;
    select count(*),count(*) filter(where a.is_correct)
      into answered_count,correct_count
      from answers a
      join attempts at on at.id=a.attempt_id
      join questions q on q.id=a.question_id
     where at.session_id=current_session.id and q.position=current_session.current_position;
  end if;

  if current_session.status='live' and current_session.question_started_at is not null then
    remaining_seconds := greatest(0,ceil(current_exam.duration_minutes*60 - extract(epoch from (now()-current_session.question_started_at)))::int);
    expired := remaining_seconds <= 0;
  end if;

  return jsonb_build_object(
    'title',current_exam.title,
    'total',total_questions,
    'sessionStatus',case when current_session.id is null then 'none' else current_session.status end,
    'currentPosition',coalesce(current_session.current_position,-1),
    'studentCount',student_count,
    'answeredCount',answered_count,
    'correctCount',correct_count,
    'wrongCount',answered_count-correct_count,
    'remainingSeconds',remaining_seconds,
    'timeExpired',expired
  );
end;
$$;

create or replace function public.student_session_info()
returns jsonb language sql security definer set search_path = public
as $$
  select jsonb_build_object(
    'title',e.title,
    'questionCount',(select count(*) from questions where exam_id=e.id),
    'status',s.status
  )
  from tutor_sessions s join exams e on e.id=s.exam_id
  where s.status in ('waiting','live')
  order by s.started_at desc limit 1
$$;

create or replace function public.student_join(p_student_id text,p_student_name text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare current_session tutor_sessions; current_attempt attempts;
begin
  if trim(coalesce(p_student_id,''))='' or trim(coalesce(p_student_name,''))='' then raise exception 'กรุณากรอกชื่อและเลขประจำตัว'; end if;
  select * into current_session from tutor_sessions where status in ('waiting','live') order by started_at desc limit 1;
  if current_session.id is null then raise exception 'ยังไม่มีรอบติวที่เปิดอยู่'; end if;
  select * into current_attempt from attempts where session_id=current_session.id and student_id=trim(p_student_id);
  if current_attempt.id is null then
    insert into attempts(session_id,student_id,student_name)
    values(current_session.id,left(trim(p_student_id),50),left(trim(p_student_name),120))
    returning * into current_attempt;
  end if;
  return jsonb_build_object('token',current_attempt.token);
end;
$$;

create or replace function public.student_state(p_token uuid)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  current_attempt attempts;
  current_session tutor_sessions;
  current_exam exams;
  current_question questions;
  current_answer answers;
  total_questions int;
  remaining_seconds int := 0;
  expired boolean := false;
begin
  select * into current_attempt from attempts where token=p_token;
  if current_attempt.id is null then raise exception 'ไม่พบข้อมูลนักเรียน'; end if;
  select * into current_session from tutor_sessions where id=current_attempt.session_id;
  select * into current_exam from exams where id=current_session.exam_id;
  select count(*) into total_questions from questions where exam_id=current_exam.id;

  if current_session.status='finished' then
    return jsonb_build_object('status','finished','score',current_attempt.score,'total',total_questions);
  end if;
  if current_session.current_position<0 then
    return jsonb_build_object('status',current_session.status,'currentNumber',0,'total',total_questions,'score',current_attempt.score);
  end if;

  select * into current_question from questions where exam_id=current_exam.id and position=current_session.current_position;
  select * into current_answer from answers where attempt_id=current_attempt.id and question_id=current_question.id;
  remaining_seconds := greatest(0,ceil(current_exam.duration_minutes*60 - extract(epoch from (now()-current_session.question_started_at)))::int);
  expired := remaining_seconds <= 0;

  if current_answer.id is not null then
    return jsonb_build_object(
      'status',current_session.status,'currentNumber',current_question.position+1,'total',total_questions,
      'answered',true,'correct',current_answer.is_correct,'choice',current_answer.choice_index,
      'choiceText',current_question.choices->>current_answer.choice_index,'correctChoice',current_question.correct_index,
      'correctText',current_question.choices->>current_question.correct_index,'score',current_attempt.score,
      'remainingSeconds',remaining_seconds,'timeExpired',expired
    );
  end if;

  return jsonb_build_object(
    'status',current_session.status,'currentNumber',current_question.position+1,'total',total_questions,
    'answered',false,'text',current_question.text,'choices',current_question.choices,'score',current_attempt.score,
    'remainingSeconds',remaining_seconds,'timeExpired',expired
  );
end;
$$;

create or replace function public.student_answer(p_token uuid,p_choice int)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare current_attempt attempts; current_session tutor_sessions; current_exam exams; current_question questions; is_correct boolean;
begin
  select * into current_attempt from attempts where token=p_token for update;
  if current_attempt.id is null then raise exception 'ไม่พบข้อมูลนักเรียน'; end if;
  select * into current_session from tutor_sessions where id=current_attempt.session_id;
  select * into current_exam from exams where id=current_session.exam_id;
  if current_session.status<>'live' or current_session.current_position<0 then raise exception 'ครูยังไม่ได้ส่งข้อสอบ'; end if;
  if current_session.question_started_at is null or now() >= current_session.question_started_at + make_interval(mins=>current_exam.duration_minutes) then
    raise exception 'หมดเวลาข้อนี้แล้ว';
  end if;
  select * into current_question from questions where exam_id=current_session.exam_id and position=current_session.current_position;
  if p_choice<0 or p_choice>=jsonb_array_length(current_question.choices) then raise exception 'คำตอบไม่ถูกต้อง'; end if;
  is_correct := p_choice=current_question.correct_index;
  insert into answers(attempt_id,question_id,choice_index,is_correct)
  values(current_attempt.id,current_question.id,p_choice,is_correct);
  if is_correct then update attempts set score=score+1 where id=current_attempt.id; end if;
  return jsonb_build_object('ok',true);
exception when unique_violation then
  raise exception 'ข้อนี้ตอบแล้ว ไม่สามารถแก้ไขได้';
end;
$$;

create or replace function public.teacher_results()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare current_session tutor_sessions; current_exam exams; result_json jsonb; total_questions int; current_expired boolean := false;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  select s,e into current_session,current_exam
  from tutor_sessions s join exams e on e.id=s.exam_id
  where e.created_by=auth.uid() order by s.started_at desc limit 1;
  if current_session.id is null then return '[]'::jsonb; end if;
  select count(*) into total_questions from questions where exam_id=current_session.exam_id;
  if current_session.status='live' and current_session.question_started_at is not null then
    current_expired := now() >= current_session.question_started_at + make_interval(mins=>current_exam.duration_minutes);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'attemptId',a.id,'studentId',a.student_id,'studentName',a.student_name,'score',a.score,
    'total',total_questions,'finished',current_session.status='finished',
    'answers',(
      select coalesce(jsonb_agg(jsonb_build_object(
        'question',q.position+1,
        'choice',ans.choice_index,
        'correct',coalesce(ans.is_correct,false),
        'status',case
          when ans.id is not null then 'answered'
          when current_session.status='finished' then 'timeout'
          when q.position < current_session.current_position then 'timeout'
          when q.position = current_session.current_position and current_expired then 'timeout'
          when q.position = current_session.current_position then 'pending'
          else 'not_released'
        end
      ) order by q.position),'[]'::jsonb)
      from questions q left join answers ans on ans.question_id=q.id and ans.attempt_id=a.id
      where q.exam_id=current_session.exam_id
    )
  ) order by a.joined_at),'[]'::jsonb)
  into result_json from attempts a where a.session_id=current_session.id;
  return result_json;
end;
$$;

create or replace function public.teacher_reset_attempt(p_attempt_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  delete from attempts a using tutor_sessions s,exams e
   where a.id=p_attempt_id and a.session_id=s.id and s.exam_id=e.id and e.created_by=auth.uid();
end;
$$;

create or replace function public.teacher_clear_results()
returns void language plpgsql security definer set search_path = public
as $$
declare target_session_id uuid;
begin
  if not is_teacher() then raise exception 'Unauthorized'; end if;
  select s.id into target_session_id from tutor_sessions s join exams e on e.id=s.exam_id
  where e.created_by=auth.uid() order by s.started_at desc limit 1;
  delete from attempts where session_id=target_session_id;
end;
$$;

grant execute on function public.student_session_info() to anon,authenticated;
grant execute on function public.student_join(text,text) to anon,authenticated;
grant execute on function public.student_state(uuid) to anon,authenticated;
grant execute on function public.student_answer(uuid,int) to anon,authenticated;
grant execute on function public.teacher_exam_get() to authenticated;
grant execute on function public.teacher_exam_save(jsonb) to authenticated;
grant execute on function public.teacher_round_start() to authenticated;
grant execute on function public.teacher_release_next() to authenticated;
grant execute on function public.teacher_round_finish() to authenticated;
grant execute on function public.teacher_control_state() to authenticated;
grant execute on function public.teacher_results() to authenticated;
grant execute on function public.teacher_reset_attempt(uuid) to authenticated;
grant execute on function public.teacher_clear_results() to authenticated;
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
