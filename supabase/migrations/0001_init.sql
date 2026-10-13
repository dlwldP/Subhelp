-- Subhelp 초기 스키마
-- Supabase 대시보드 > SQL Editor에 붙여넣어 실행하거나, Supabase CLI로 `supabase db push` 한다.

-- ─────────────────────────────────────────────
-- 1. 프리셋 (원격 관리, 로그인 없이 누구나 읽기)
-- ─────────────────────────────────────────────
create table public.presets (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  category    text not null default '기타',
  cycle       text not null default 'monthly' check (cycle in ('weekly', 'monthly', 'yearly')),
  color_hex   text not null default '#5B8DEF',
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  updated_at  timestamptz not null default now()
);

alter table public.presets enable row level security;

create policy "활성 프리셋은 누구나 읽을 수 있다"
  on public.presets for select
  to anon, authenticated
  using (is_active);

-- ─────────────────────────────────────────────
-- 2. 구독 (로그인한 사용자 본인 데이터만)
-- id는 앱에서 만든 UUID를 그대로 쓴다 (기기 ↔ 서버 동일 ID)
-- deleted_at: 삭제 기록(tombstone). 다른 기기에도 삭제를 전파하기 위해 행을 바로 지우지 않는다
-- ─────────────────────────────────────────────
create table public.subscriptions (
  id                  uuid primary key,
  user_id             uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name                text not null,
  price               numeric(12, 2) not null check (price > 0),
  currency_code       text not null default 'KRW' check (currency_code in ('KRW', 'USD')),
  cycle               text not null check (cycle in ('weekly', 'monthly', 'yearly')),
  cycle_interval      int  not null default 1 check (cycle_interval >= 1),
  start_date          date not null,
  category            text not null default '기타',
  color_hex           text not null default '#5B8DEF',
  notify_days_before  int,
  is_active           boolean not null default true,
  trial_end_date      date,
  memo                text not null default '',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

create index subscriptions_user_id_idx on public.subscriptions (user_id);

alter table public.subscriptions enable row level security;

create policy "본인 구독 읽기"
  on public.subscriptions for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "본인 구독 추가"
  on public.subscriptions for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "본인 구독 수정"
  on public.subscriptions for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "본인 구독 삭제"
  on public.subscriptions for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────
-- 3. 계정 삭제 (App Store 가이드라인 5.1.1(v): 앱 안에서 계정 삭제 제공 필수)
-- 본인 auth.users 행을 지우면 subscriptions는 on delete cascade로 함께 지워진다
-- 앱은 기본으로 Edge Function `delete-account`(Apple 토큰 철회 포함)를 호출하고,
-- 함수가 배포되지 않았거나 실패했을 때만 이 함수로 대신 삭제한다 (Apple 토큰 철회는 생략됨)
-- ─────────────────────────────────────────────
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

-- ─────────────────────────────────────────────
-- 4. 프리셋 초기 데이터 (앱 번들 기본값과 동일)
-- ─────────────────────────────────────────────
insert into public.presets (name, category, cycle, color_hex, sort_order) values
  ('넷플릭스',            '영상',            'monthly', '#D64545', 10),
  ('유튜브 프리미엄',      '영상',            'monthly', '#E0603A', 20),
  ('티빙',               '영상',            'monthly', '#C2456B', 30),
  ('디즈니+',             '영상',            'monthly', '#3C5BA9', 40),
  ('웨이브',              '영상',            'monthly', '#3D7BD9', 50),
  ('쿠팡플레이',           '영상',            'monthly', '#4A6FE3', 60),
  ('스포티파이',           '음악',            'monthly', '#2E9E5B', 70),
  ('멜론',               '음악',            'monthly', '#3BB273', 80),
  ('애플 뮤직',           '음악',            'monthly', '#E5566B', 90),
  ('쿠팡 와우',           '쇼핑·멤버십',       'monthly', '#2F8FD8', 100),
  ('네이버플러스 멤버십',    '쇼핑·멤버십',       'monthly', '#2FA866', 110),
  ('노션',               '생산성·업무',       'monthly', '#5F5F5F', 120),
  ('피그마',              '생산성·업무',       'monthly', '#8A5BD6', 130),
  ('ChatGPT',           'AI',             'monthly', '#4A9C88', 140),
  ('Claude',            'AI',             'monthly', '#C9733E', 150),
  ('iCloud+',           '클라우드·저장공간',   'monthly', '#5B8DEF', 160),
  ('구글 One',           '클라우드·저장공간',   'monthly', '#4C8BF5', 170),
  ('닌텐도 스위치 온라인',   '게임',            'yearly',  '#D9534F', 180),
  ('밀리의 서재',          '뉴스·도서',        'monthly', '#E5A23A', 190);
