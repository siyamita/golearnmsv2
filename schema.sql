-- GoLearnMS database schema for Supabase (PostgreSQL)
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '', username text unique not null,
  email text not null, institution text default '', role text not null default 'student' check (role in ('admin','teacher','student')),
  is_super_admin boolean not null default false, status text not null default 'active' check (status in ('active','inactive','online','deleted')),
  avatar_url text, bio text default '', class_name text default '', student_number text default '', cohort text default '', nip text default '',
  password_reset_required boolean not null default false, last_seen_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(), teacher_id uuid not null references public.profiles(id), name text not null,
  description text default '', join_code text unique not null, created_at timestamptz not null default now()
);
create table if not exists public.class_members (
  class_id uuid references public.classes(id) on delete cascade, student_id uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(), primary key(class_id, student_id)
);
create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(), class_id uuid not null references public.classes(id) on delete cascade,
  title text not null, description text default '', materials jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(), session_id uuid not null references public.sessions(id) on delete cascade,
  title text not null, instructions text default '', materials jsonb not null default '[]'::jsonb, deadline timestamptz, max_score int not null default 100 check (max_score between 1 and 100), created_at timestamptz not null default now()
);
create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(), assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade, answer_text text default '', file_url text, submitted_at timestamptz not null default now(), score numeric(5,2) check (score between 0 and 100), feedback text default '', graded_at timestamptz, unique(assignment_id, student_id)
);
create table if not exists public.attendance_meetings (
  id uuid primary key default gen_random_uuid(), class_id uuid not null references public.classes(id) on delete cascade,
  title text not null, meeting_date date not null, meeting_time time, material text default '', created_at timestamptz not null default now()
);
create table if not exists public.attendance_records (
  meeting_id uuid references public.attendance_meetings(id) on delete cascade, student_id uuid references public.profiles(id) on delete cascade,
  attendance_status text not null default 'Tidak Hadir' check (attendance_status in ('Hadir','Tidak Hadir','Izin','Sakit')),
  updated_at timestamptz not null default now(), primary key(meeting_id, student_id)
);
create table if not exists public.visits (
  id bigint generated always as identity primary key, user_id uuid references public.profiles(id) on delete set null,
  role text, visited_at timestamptz not null default now(), path text default '/'
);
create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(), user_id uuid references public.profiles(id) on delete set null,
  user_email text, message text not null, created_at timestamptz not null default now()
);
create table if not exists public.maintenance_logs (
  id uuid primary key default gen_random_uuid(), user_id uuid references public.profiles(id) on delete set null,
  issue text not null, severity text not null default 'info', details jsonb default '{}'::jsonb, created_at timestamptz not null default now()
);

-- Create a profile when a user registers. Username must be unique.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare uname text;
begin
  uname := coalesce(nullif(new.raw_user_meta_data->>'username',''), split_part(new.email,'@',1));
  insert into public.profiles(id, full_name, username, email, institution, role)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name','Pengguna Baru'), uname, new.email,
         coalesce(new.raw_user_meta_data->>'institution',''), case when new.raw_user_meta_data->>'requested_role'='teacher' then 'teacher' else 'student' end);
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.touch_profile() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.touch_profile();

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.class_members enable row level security;
alter table public.sessions enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.attendance_meetings enable row level security;
alter table public.attendance_records enable row level security;
alter table public.visits enable row level security;
alter table public.support_messages enable row level security;
alter table public.maintenance_logs enable row level security;

-- Helper predicates use profiles role; policies are intentionally conservative.
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and p.status <> 'deleted') $$;
create or replace function public.is_teacher_of(target_class uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.classes c where c.id=target_class and c.teacher_id=auth.uid()) $$;

-- Profile visibility and editing
create policy "profiles read self or admin" on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin());
create policy "profiles update self or admin" on public.profiles for update to authenticated using (id=auth.uid() or public.is_admin()) with check (id=auth.uid() or public.is_admin());
create policy "profiles admin insert" on public.profiles for insert to authenticated with check (public.is_admin());
-- Classes: teachers manage their own, enrolled students can read
create policy "classes visible to owner member or admin" on public.classes for select to authenticated using (teacher_id=auth.uid() or public.is_admin() or exists(select 1 from public.class_members m where m.class_id=id and m.student_id=auth.uid()));
create policy "teachers create classes" on public.classes for insert to authenticated with check (exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='teacher'));
create policy "teachers update own classes" on public.classes for update to authenticated using (teacher_id=auth.uid() or public.is_admin()) with check (teacher_id=auth.uid() or public.is_admin());
create policy "teachers delete own classes" on public.classes for delete to authenticated using (teacher_id=auth.uid() or public.is_admin());
create policy "members visible to class members" on public.class_members for select to authenticated using (student_id=auth.uid() or public.is_admin() or public.is_teacher_of(class_id));
create policy "students join classes" on public.class_members for insert to authenticated with check (student_id=auth.uid());
create policy "teacher admin manage members" on public.class_members for delete to authenticated using (public.is_admin() or public.is_teacher_of(class_id));
create policy "sessions visible to class users" on public.sessions for select to authenticated using (public.is_admin() or public.is_teacher_of(class_id) or exists(select 1 from public.class_members m where m.class_id=sessions.class_id and m.student_id=auth.uid()));
create policy "teachers manage sessions" on public.sessions for all to authenticated using (public.is_admin() or public.is_teacher_of(class_id)) with check (public.is_admin() or public.is_teacher_of(class_id));
create policy "assignments visible via session" on public.assignments for select to authenticated using (public.is_admin() or exists(select 1 from public.sessions s where s.id=session_id and (public.is_teacher_of(s.class_id) or exists(select 1 from public.class_members m where m.class_id=s.class_id and m.student_id=auth.uid()))));
create policy "teachers manage assignments" on public.assignments for all to authenticated using (public.is_admin() or exists(select 1 from public.sessions s where s.id=session_id and public.is_teacher_of(s.class_id))) with check (public.is_admin() or exists(select 1 from public.sessions s where s.id=session_id and public.is_teacher_of(s.class_id)));
create policy "submissions visible to owner teacher admin" on public.submissions for select to authenticated using (student_id=auth.uid() or public.is_admin() or exists(select 1 from public.assignments a join public.sessions s on s.id=a.session_id where a.id=assignment_id and public.is_teacher_of(s.class_id)));
create policy "students submit own work" on public.submissions for insert to authenticated with check (student_id=auth.uid());
create policy "students edit own work and teachers grade" on public.submissions for update to authenticated using (student_id=auth.uid() or public.is_admin() or exists(select 1 from public.assignments a join public.sessions s on s.id=a.session_id where a.id=assignment_id and public.is_teacher_of(s.class_id))) with check (student_id=auth.uid() or public.is_admin() or exists(select 1 from public.assignments a join public.sessions s on s.id=a.session_id where a.id=assignment_id and public.is_teacher_of(s.class_id)));
create policy "meetings visible to class users" on public.attendance_meetings for select to authenticated using (public.is_admin() or public.is_teacher_of(class_id) or exists(select 1 from public.class_members m where m.class_id=attendance_meetings.class_id and m.student_id=auth.uid()));
create policy "teachers manage meetings" on public.attendance_meetings for all to authenticated using (public.is_admin() or public.is_teacher_of(class_id)) with check (public.is_admin() or public.is_teacher_of(class_id));
create policy "attendance visible to self teacher admin" on public.attendance_records for select to authenticated using (student_id=auth.uid() or public.is_admin() or exists(select 1 from public.attendance_meetings mt where mt.id=meeting_id and public.is_teacher_of(mt.class_id)));
create policy "teachers manage attendance" on public.attendance_records for all to authenticated using (public.is_admin() or exists(select 1 from public.attendance_meetings mt where mt.id=meeting_id and public.is_teacher_of(mt.class_id))) with check (public.is_admin() or exists(select 1 from public.attendance_meetings mt where mt.id=meeting_id and public.is_teacher_of(mt.class_id)));
create policy "visits own or admin read" on public.visits for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy "user records visit" on public.visits for insert to authenticated with check (user_id=auth.uid());
create policy "support create own" on public.support_messages for insert to authenticated with check (user_id=auth.uid());
create policy "admin read support" on public.support_messages for select to authenticated using (public.is_admin());
create policy "admin manage maintenance logs" on public.maintenance_logs for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Bootstrap the main admin AFTER creating the account via the sign-up screen.
-- In Supabase SQL editor, replace the email below if needed, then run:
-- update public.profiles set full_name='siya', username='siya', role='admin', is_super_admin=true where lower(email)=lower('sitiyasinta029@gmail.com');
-- Promote additional admins through an admin-only server workflow; do not expose the service_role key in frontend code.
