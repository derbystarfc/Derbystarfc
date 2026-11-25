-- Run in Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.manager_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.player_applications (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text not null,
  phone text not null,
  date_of_birth date,
  position text not null,
  preferred_foot text,
  previous_club text,
  experience text,
  bio text,
  photo_url text,
  status text not null default 'PENDING' check (status in ('PENDING','APPROVED','REJECTED')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table public.manager_users enable row level security;
alter table public.player_applications enable row level security;

-- Public visitors can submit applications and read ONLY approved profiles.
create policy "Anyone can submit an application"
on public.player_applications for insert to anon, authenticated
with check (status = 'PENDING');

create policy "Public can view approved players"
on public.player_applications for select to anon, authenticated
using (status = 'APPROVED');

-- Only user IDs explicitly listed in manager_users can view all applications,
-- approve/reject them, or manage manager access.
-- SECURITY DEFINER avoids recursive row-level-security checks on manager_users.
create or replace function public.is_derby_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(select 1 from public.manager_users where user_id = auth.uid());
$$;
revoke all on function public.is_derby_manager() from public;
grant execute on function public.is_derby_manager() to authenticated;

create policy "Managers can view manager list"
on public.manager_users for select to authenticated
using (public.is_derby_manager());

create policy "Managers can view all applications"
on public.player_applications for select to authenticated
using (public.is_derby_manager());

create policy "Managers can update applications"
on public.player_applications for update to authenticated
using (public.is_derby_manager())
with check (public.is_derby_manager());

-- Create a PUBLIC storage bucket named player-photos in Storage.
-- Allow uploads to the bucket, but never allow applicants to update application status.
-- Public read is needed for approved player photos to display on the public site.
insert into storage.buckets (id,name,public) values ('player-photos','player-photos',true)
on conflict (id) do update set public=true;

create policy "Applicants can upload player photos"
on storage.objects for insert to anon, authenticated
with check (bucket_id = 'player-photos');

create policy "Public can view player photos"
on storage.objects for select to anon, authenticated
using (bucket_id = 'player-photos');

-- IMPORTANT: after creating a manager account in Authentication > Users,
-- add that user's UUID using this SQL (replace the UUID):
-- insert into public.manager_users(user_id) values ('YOUR-MANAGER-AUTH-USER-UUID');
