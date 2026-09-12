-- Top Weight cloud sync schema.
-- Run this once in the Supabase SQL editor for a fresh project.
-- Safe to re-run: every statement is idempotent (CREATE ... IF NOT EXISTS / OR REPLACE / DROP ... IF EXISTS first).

-- =========================================================================
-- Tables
-- =========================================================================

create table if not exists public.profiles (
    id uuid primary key,
    owner_id uuid not null references auth.users (id) on delete cascade,
    name text not null,
    avatar_symbol text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create table if not exists public.exercises (
    id uuid primary key,
    owner_id uuid not null references auth.users (id) on delete cascade,
    name text not null,
    exercise_type text not null default 'strength',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create table if not exists public.workout_records (
    id uuid primary key,
    owner_id uuid not null references auth.users (id) on delete cascade,
    user_id uuid not null references public.profiles (id) on delete cascade,
    exercise_id uuid not null references public.exercises (id) on delete cascade,
    weight double precision not null default 0,
    reps integer not null default 0,
    series integer not null default 0,
    date timestamptz not null,
    distance double precision,
    is_indoor boolean,
    seconds integer,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists workout_records_owner_updated_idx
    on public.workout_records (owner_id, updated_at);
create index if not exists profiles_owner_updated_idx
    on public.profiles (owner_id, updated_at);
create index if not exists exercises_owner_updated_idx
    on public.exercises (owner_id, updated_at);

-- =========================================================================
-- Row Level Security — every account can only ever see/write its own rows.
-- =========================================================================

alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.workout_records enable row level security;

drop policy if exists "profiles_owner_all" on public.profiles;
create policy "profiles_owner_all" on public.profiles
    for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "exercises_owner_all" on public.exercises;
create policy "exercises_owner_all" on public.exercises
    for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "workout_records_owner_all" on public.workout_records;
create policy "workout_records_owner_all" on public.workout_records
    for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- =========================================================================
-- Cascade tombstoning: soft-deleting a profile/exercise soft-deletes its
-- workout_records too, mirroring the local SwiftData cascade delete rule.
-- =========================================================================

create or replace function public.cascade_tombstone_profile()
returns trigger language plpgsql security definer as $$
begin
    if new.deleted_at is not null and old.deleted_at is null then
        update public.workout_records
        set deleted_at = new.deleted_at, updated_at = new.updated_at
        where user_id = new.id and deleted_at is null;
    end if;
    return new;
end;
$$;

drop trigger if exists cascade_tombstone_profile_trigger on public.profiles;
create trigger cascade_tombstone_profile_trigger
    after update of deleted_at on public.profiles
    for each row execute function public.cascade_tombstone_profile();

create or replace function public.cascade_tombstone_exercise()
returns trigger language plpgsql security definer as $$
begin
    if new.deleted_at is not null and old.deleted_at is null then
        update public.workout_records
        set deleted_at = new.deleted_at, updated_at = new.updated_at
        where exercise_id = new.id and deleted_at is null;
    end if;
    return new;
end;
$$;

drop trigger if exists cascade_tombstone_exercise_trigger on public.exercises;
create trigger cascade_tombstone_exercise_trigger
    after update of deleted_at on public.exercises
    for each row execute function public.cascade_tombstone_exercise();

-- =========================================================================
-- Last-write-wins upsert RPCs.
-- Plain PostgREST .upsert() always overwrites on conflict; these functions
-- only apply the incoming row if it is at least as new as what's stored,
-- so a stale/offline device can never clobber a newer edit made elsewhere.
-- `security invoker` keeps RLS enforced using the calling user's session.
-- =========================================================================

create or replace function public.upsert_profile(
    p_id uuid,
    p_name text,
    p_avatar_symbol text,
    p_created_at timestamptz,
    p_updated_at timestamptz,
    p_deleted_at timestamptz
) returns void language sql security invoker as $$
    insert into public.profiles (id, owner_id, name, avatar_symbol, created_at, updated_at, deleted_at)
    values (p_id, auth.uid(), p_name, p_avatar_symbol, p_created_at, p_updated_at, p_deleted_at)
    on conflict (id) do update set
        name = excluded.name,
        avatar_symbol = excluded.avatar_symbol,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at
    where excluded.updated_at >= public.profiles.updated_at;
$$;

create or replace function public.upsert_exercise(
    p_id uuid,
    p_name text,
    p_exercise_type text,
    p_created_at timestamptz,
    p_updated_at timestamptz,
    p_deleted_at timestamptz
) returns void language sql security invoker as $$
    insert into public.exercises (id, owner_id, name, exercise_type, created_at, updated_at, deleted_at)
    values (p_id, auth.uid(), p_name, p_exercise_type, p_created_at, p_updated_at, p_deleted_at)
    on conflict (id) do update set
        name = excluded.name,
        exercise_type = excluded.exercise_type,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at
    where excluded.updated_at >= public.exercises.updated_at;
$$;

create or replace function public.upsert_workout_record(
    p_id uuid,
    p_user_id uuid,
    p_exercise_id uuid,
    p_weight double precision,
    p_reps integer,
    p_series integer,
    p_date timestamptz,
    p_distance double precision,
    p_is_indoor boolean,
    p_seconds integer,
    p_updated_at timestamptz,
    p_deleted_at timestamptz
) returns void language sql security invoker as $$
    insert into public.workout_records (
        id, owner_id, user_id, exercise_id, weight, reps, series, date,
        distance, is_indoor, seconds, updated_at, deleted_at
    )
    values (
        p_id, auth.uid(), p_user_id, p_exercise_id, p_weight, p_reps, p_series, p_date,
        p_distance, p_is_indoor, p_seconds, p_updated_at, p_deleted_at
    )
    on conflict (id) do update set
        user_id = excluded.user_id,
        exercise_id = excluded.exercise_id,
        weight = excluded.weight,
        reps = excluded.reps,
        series = excluded.series,
        date = excluded.date,
        distance = excluded.distance,
        is_indoor = excluded.is_indoor,
        seconds = excluded.seconds,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at
    where excluded.updated_at >= public.workout_records.updated_at;
$$;

-- =========================================================================
-- Self-service account deletion (required for App Store review — Guideline
-- 5.1.1(v): apps that support account creation must support in-app deletion).
--
-- Deleting from auth.users requires elevated privileges a client's anon key
-- doesn't have, so this runs `security definer` (as the function's owner,
-- typically the project's postgres role) rather than `security invoker`.
-- profiles/exercises/workout_records all have `owner_id references
-- auth.users(id) on delete cascade`, so deleting the auth.users row alone
-- cleans up every row this account owns.
-- =========================================================================

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_own_account() to authenticated;
