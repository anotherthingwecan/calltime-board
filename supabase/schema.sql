-- 공연 콜타임 보드 · Supabase 스키마 (calltime-board 프로젝트에 이미 적용됨, 기록용)
-- PD(보드 주인)는 Supabase Auth 계정, 스태프는 PD가 발급한 6자리 개인 코드로 자기 줄만 수정

-- PD 이메일 목록 (API로는 아무도 못 읽음). PD를 추가하려면 여기에 이메일을 넣고 Auth에 사용자를 만들면 돼요.
create table public.pd_emails (email text primary key);
alter table public.pd_emails enable row level security;
insert into public.pd_emails (email) values ('sjqwer1234@gmail.com');

create or replace function public.is_pd() returns boolean
language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from auth.users u
    join public.pd_emails p on lower(p.email) = lower(u.email)
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.is_pd() from public;
grant execute on function public.is_pd() to anon, authenticated;

create table public.show (
  id int primary key default 1 check (id = 1),
  title text not null default '',
  show_date text not null default '',
  venue text not null default '',
  buffer int not null default 15 check (buffer between 0 and 180),
  notice text not null default '',
  notice_at timestamptz,
  pdf_path text,
  pdf_name text not null default '',
  pdf_size int not null default 0,
  pdf_at timestamptz,
  example boolean not null default false
);

create table public.crew (
  id text primary key,
  role text not null default '',
  name text not null default '',
  team text not null default '스태프',
  avail_from text not null default '',
  avail_to text not null default '',
  sort int not null default 0,
  self_name text,
  self_from text,
  self_to text,
  self_at timestamptz
);

create table public.blocks (
  id text primary key,
  label text not null default '',
  start_t text not null default '',
  end_t text not null default '',
  crew text[] not null default '{}',
  sort int not null default 0
);

create table public.checkins (
  crew_id text primary key references public.crew(id) on delete cascade,
  at_min int not null check (at_min between 0 and 1439),
  by_who text not null default 'pd',
  created_at timestamptz not null default now()
);

create table public.crew_codes (
  crew_id text primary key references public.crew(id) on delete cascade,
  code text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  created_at timestamptz not null default now()
);

alter table public.show enable row level security;
alter table public.crew enable row level security;
alter table public.blocks enable row level security;
alter table public.checkins enable row level security;
alter table public.crew_codes enable row level security;

create policy "anyone reads show" on public.show for select to anon, authenticated using (true);
create policy "anyone reads crew" on public.crew for select to anon, authenticated using (true);
create policy "anyone reads blocks" on public.blocks for select to anon, authenticated using (true);
create policy "anyone reads checkins" on public.checkins for select to anon, authenticated using (true);

create policy "pd inserts show" on public.show for insert to authenticated with check (public.is_pd());
create policy "pd updates show" on public.show for update to authenticated using (public.is_pd()) with check (public.is_pd());
create policy "pd deletes show" on public.show for delete to authenticated using (public.is_pd());
create policy "pd inserts crew" on public.crew for insert to authenticated with check (public.is_pd());
create policy "pd updates crew" on public.crew for update to authenticated using (public.is_pd()) with check (public.is_pd());
create policy "pd deletes crew" on public.crew for delete to authenticated using (public.is_pd());
create policy "pd inserts blocks" on public.blocks for insert to authenticated with check (public.is_pd());
create policy "pd updates blocks" on public.blocks for update to authenticated using (public.is_pd()) with check (public.is_pd());
create policy "pd deletes blocks" on public.blocks for delete to authenticated using (public.is_pd());
create policy "pd inserts checkins" on public.checkins for insert to authenticated with check (public.is_pd());
create policy "pd updates checkins" on public.checkins for update to authenticated using (public.is_pd()) with check (public.is_pd());
create policy "pd deletes checkins" on public.checkins for delete to authenticated using (public.is_pd());
create policy "pd reads codes" on public.crew_codes for select to authenticated using (public.is_pd());
create policy "pd inserts codes" on public.crew_codes for insert to authenticated with check (public.is_pd());
create policy "pd updates codes" on public.crew_codes for update to authenticated using (public.is_pd()) with check (public.is_pd());
create policy "pd deletes codes" on public.crew_codes for delete to authenticated using (public.is_pd());

-- 스태프용: 코드가 맞을 때만 자기 줄을 바꿈
create or replace function public.staff_whoami(p_code text) returns text
language sql stable security definer set search_path = public as $$
  select crew_id from public.crew_codes where code = upper(trim(coalesce(p_code, '')));
$$;

create or replace function public.staff_update(p_code text, p_name text, p_from text, p_to text) returns void
language plpgsql security definer set search_path = public as $$
declare v_id text;
begin
  select crew_id into v_id from public.crew_codes where code = upper(trim(coalesce(p_code, '')));
  if v_id is null then raise exception 'invalid code' using errcode = '28000'; end if;
  if coalesce(p_from, '') !~ '^(([01][0-9]|2[0-3]):[0-5][0-9])?$'
     or coalesce(p_to, '') !~ '^(([01][0-9]|2[0-3]):[0-5][0-9])?$' then
    raise exception 'bad time' using errcode = '22023';
  end if;
  update public.crew
     set self_name = left(coalesce(p_name, ''), 40),
         self_from = coalesce(p_from, ''),
         self_to = coalesce(p_to, ''),
         self_at = coalesce(self_at, now())
   where id = v_id;
end $$;

create or replace function public.staff_checkin(p_code text, p_at int, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_id text;
begin
  select crew_id into v_id from public.crew_codes where code = upper(trim(coalesce(p_code, '')));
  if v_id is null then raise exception 'invalid code' using errcode = '28000'; end if;
  if p_on then
    insert into public.checkins (crew_id, at_min, by_who)
    values (v_id, greatest(0, least(1439, coalesce(p_at, 0))), 'self')
    on conflict (crew_id) do update set at_min = excluded.at_min, by_who = 'self', created_at = now();
  else
    delete from public.checkins where crew_id = v_id;
  end if;
end $$;

revoke all on function public.staff_whoami(text) from public;
revoke all on function public.staff_update(text, text, text, text) from public;
revoke all on function public.staff_checkin(text, int, boolean) from public;
grant execute on function public.staff_whoami(text) to anon, authenticated;
grant execute on function public.staff_update(text, text, text, text) to anon, authenticated;
grant execute on function public.staff_checkin(text, int, boolean) to anon, authenticated;

-- 기획안 PDF: 누구나 링크로 보기, PD만 올리기·지우기
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('plans', 'plans', true, 20971520, array['application/pdf']);
create policy "pd reads plans" on storage.objects for select to authenticated using (bucket_id = 'plans' and public.is_pd());
create policy "pd uploads plans" on storage.objects for insert to authenticated with check (bucket_id = 'plans' and public.is_pd());
create policy "pd updates plans" on storage.objects for update to authenticated using (bucket_id = 'plans' and public.is_pd());
create policy "pd deletes plans" on storage.objects for delete to authenticated using (bucket_id = 'plans' and public.is_pd());

alter publication supabase_realtime add table public.show, public.crew, public.blocks, public.checkins, public.crew_codes;
