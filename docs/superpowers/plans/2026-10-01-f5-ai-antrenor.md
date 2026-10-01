# F5 — AI Antrenör Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alt menüde dördüncü sekme "Antrenör": kullanıcının verisini bilen bir AI sohbeti; altı araçla (kilo, profil, amaç, öğün, set, program) onay kartı üzerinden veri değiştirir, her değişiklik geri alınabilir; kullanıcı başına 24 saatlik mesaj sınırı.

**Architecture:** `coach-chat` Edge Function'ı kullanıcının JWT'siyle (RLS altında) veri özetini toplar, sağlayıcıdan bağımsız `LlmClient` (varsayılan Gemini ücretsiz katmanı) ile araç tanımlarını gönderir; araç çağrısı doğrulanıp `chat_events`'e **beklemede** yazılır. Uygulama onay/vazgeç/geri al için doğrudan SQL fonksiyonlarını (`apply_chat_action`, `cancel_chat_action`, `undo_chat_action`) çağırır; bunlar `chat_target_snapshot` görüntüleriyle (base/before/after) "arada değişti mi" kontrolünü tek transaction'da yapar. Hedef kalori/protein uygulamada `TdeeCalculator` ile hesaplanıp onayda gönderilir.

**Tech Stack:** Flutter + Riverpod 3 + go_router 18 + supabase_flutter 2.17 + easy_localization. Backend: Postgres plpgsql (Supabase), Deno Edge Function (`jsr:@supabase/supabase-js@2`), Gemini API (`v1beta generateContent`, function calling).

**Spec:** `docs/superpowers/specs/2026-10-01-f5-ai-antrenor-design.md`

## Global Constraints

- Araç adları tam olarak: `log_body_weight`, `update_profile`, `set_goal`, `create_meal`, `log_set`, `edit_program` (spec §3.2).
- Olay durumları tam olarak: `pending`, `applied`, `cancelled`, `undone`, `stale` (spec §3).
- Tüm yeni SQL fonksiyonları `security invoker`, `set search_path = public`; yeni üç tabloda RLS zorunlu; `chat_usage`'ta yalnız select + insert politikası (spec §3).
- Edge Function veritabanına **yalnızca kullanıcının JWT'siyle** bağlanır (anon key + kullanıcının `Authorization` başlığı); service role kullanılmaz (spec §4.1).
- Secret'lar: `GEMINI_API_KEY` (mevcut), `LLM_PROVIDER` (varsayılan `gemini`), `LLM_MODEL` (varsayılan `gemini-3.5-flash-lite`), `COACH_DAILY_LIMIT` (varsayılan `30`) (spec §4.1, §4.3).
- Sınırlar: mesaj 1–2000 karakter; geçmiş son 20 mesaj; istek başına en fazla 3 LLM çağrısı; LLM zaman aşımı 25 sn; günlük sınır son 24 saatteki `chat_usage` satırı sayısıdır (spec §4.1).
- Her cevapta en fazla bir değişiklik önerisi; kilo yalnız `log_body_weight` ile değişir; `edit_program` yalnız **aktif** ve kullanıcının **kendi** programını düzenler (spec §3.2).
- LLM makro hesaplamaz: öğün makroları USDA'nın 100 g değerlerinden `round(gram × değer / 100, 1)` (spec §3.2, F2 ile aynı).
- Sağlayıcıya özgü kod yalnız `supabase/functions/coach-chat/llm/gemini_client.ts`'tedir; geri kalan kod `llm/types.ts`'teki formatı kullanır (spec §4.3).
- Hareket adları İngilizce kalır; diğer tüm UI metinleri `assets/translations/tr.json` + `en.json`'daki `coach` bölümündedir (`nav.coach` dahil).
- Supabase'e dokunan sınıflar (`SupabaseChatRepository`, `store.ts`, `index.ts`) unit test edilmez; mantık fake'lerle test edilir; SQL Task 13'te SQL Editor'da doğrulanır.
- Widget testlerinde `.tr()` çıktısına güvenilmez; bulma `Key`, ikon veya veri metniyle yapılır.
- "Şimdi"ye bağlı Dart kodu `nowProvider`'ı (`lib/features/workout/application/session_providers.dart`) kullanır.
- `flutter analyze` "No issues found!" vermeli (info dahil): her `await`'ten sonra `context` kullanmadan önce `context.mounted` / `mounted` kontrolü.
- Tüm `flutter` komutları `--no-pub` ile çalıştırılır (otomatik `pub get` bu makinede ağda takılıyor). Deno testleri: `deno test supabase/functions/`.
- Düşük bellekli makine: `flutter test` tam paket ~6 dk; görev içinde yalnız ilgili test dosyaları, görev sonunda tam paket.
- Tüm işler `f5-ai-antrenor` dalında (master'dan açıldı).

## Spec'ten Bilinçli Sapmalar (plan yazımında ortaya çıktı, spec'e işlendi)

1. **Günlük sınır `chat_usage` tablosuyla sayılır:** mesajları saymak "Sohbeti temizle" ile sınırın sıfırlanmasına izin veriyordu. Kullanıcı bu tabloya yalnız ekleyebilir/okuyabilir.
2. **`base` her araçta doludur** (`create_meal`'da `{"meal": null}`): tek, istisnasız bir karşılaştırma kuralı.
3. **3 LLM çağrısında geçerli araç çıkmazsa sabit, yerelleştirilmiş bir cevap döner** (ek LLM çağrısı yok; kota korunur).
4. **İstek `utc_offset_minutes` taşır:** "bugün", varsayılan kilo tarihi ve öğün saati cihazın yerel gününe göre hesaplanır.
5. **`{action: 'status'}` isteği** kalan hakkı LLM çağırmadan döndürür (ekran açılışında uyarı için).
6. **Mesajlar tek bir SQL biçimiyle döner** (`chat_message_json`): uygulama (`recent_chat_messages`) ve Edge Function (`save_chat_exchange`) aynı JSON'u üretir.
7. **Geri almada "Sonradan değişti" durumu kalıcı değildir:** kart yerel durumunda tutulur; sayfa yenilenince buton yine görünür, basınca yine `modified` döner ve pasifleşir.

## Dosya Haritası

```
supabase/migrations/
  0010_create_coach_chat.sql            # Task 1 (tablolar, görüntüler, mesaj fonksiyonları) + Task 2 (uygula/vazgeç/geri al)
  checks/f5_rls_checks.sql              # Task 2
supabase/functions/
  _shared/http.ts                       # Task 3 (JWT'den user id, CORS, jsonResponse)
  _shared/http.test.ts                  # Task 3 (analyze-meal-photo/auth.test.ts taşınır)
  _shared/usda_client.ts(+test)         # Task 3 (analyze-meal-photo'dan taşınır)
  analyze-meal-photo/index.ts           # Task 3 (importlar)
  coach-chat/
    types.ts                            # Task 4 (ortak tipler)
    llm/types.ts, llm/gemini_client.ts, llm/factory.ts (+testler)   # Task 4
    context.ts, prompts.ts (+test)      # Task 5
    program_ops.ts (+test)              # Task 6
    tools.ts (+test)                    # Task 7
    handler.ts (+test), store.ts, index.ts   # Task 8
.github/workflows/ci.yml                # Task 3 (deno test kapsamı)
lib/features/onboarding/domain/profile.dart        # Task 9 (copyWith, public db çeviricileri)
lib/features/chat/
  domain/chat_models.dart               # Task 9
  domain/card_data.dart                 # Task 9
  data/chat_repository.dart             # Task 10
  application/chat_providers.dart       # Task 10
  application/chat_notifier.dart        # Task 10
  application/chat_refresh.dart         # Task 10
  presentation/widgets/card_bodies.dart # Task 11
  presentation/widgets/confirm_card.dart# Task 11
  presentation/widgets/message_bubble.dart # Task 12
  presentation/coach_screen.dart        # Task 12
lib/core/app_shell.dart, lib/core/router.dart       # Task 12
assets/translations/tr.json, en.json    # Task 11, 12
test/features/chat/...                  # Task 9–12
PLAN.md                                 # Task 13
```

---

### Task 1: Migration 0010 — tablolar, RLS, görüntüler, mesaj fonksiyonları

**Files:**
- Create: `supabase/migrations/0010_create_coach_chat.sql`

**Interfaces:**
- Produces (SQL, PostgREST'ten RPC olarak çağrılır):
  - tablolar `chat_events`, `chat_messages`, `chat_usage`
  - `program_snapshot(p_program_id uuid) returns jsonb` — `save_program` girdisi formatında (`id, name, description, level, schedule_mode, days_per_week, source_program_id, workouts[{name, weekday, exercises[{exercise_id, sets, reps_min, reps_max, is_amrap, percent_1rm, percent_ref_exercise_id, rest_seconds, notes}]}]`); program kullanıcıya ait değilse `null`
  - `chat_target_snapshot(p_tool text, p_payload jsonb) returns jsonb` (spec §3.1)
  - `chat_message_json(m chat_messages) returns jsonb` → `{id, role, content, created_at, event: null | {id, tool, status, summary, payload, base}}`
  - `recent_chat_messages(p_limit int) returns jsonb` (eskiden yeniye dizi)
  - `save_chat_exchange(p_user_text text, p_assistant_text text, p_event jsonb) returns jsonb` (`p_event`: null veya `{tool, summary, payload, base}`; iki mesajı eskiden yeniye döndürür, bir `chat_usage` satırı ekler)
  - `clear_chat() returns void`

Bu görevde çalıştırılabilir bir SQL testi yok: migration ve kontroller Task 13'te kullanıcı tarafından SQL Editor'da çalıştırılır. Task 2'nin kontrol scripti bu görevdeki her fonksiyonu kullanır.

- [ ] **Step 1: Migration dosyasının ilk bölümünü yaz**

`supabase/migrations/0010_create_coach_chat.sql`:

```sql
-- F5: AI antrenör sohbeti. Öneri → onay → uygula → geri al akışı; görüntüler
-- (base/before/after) jsonb eşitliğiyle "arada değişti mi" kontrolü yapar.

create table if not exists public.chat_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  tool text not null check (tool in ('log_body_weight', 'update_profile', 'set_goal',
                                     'create_meal', 'log_set', 'edit_program')),
  status text not null default 'pending'
    check (status in ('pending', 'applied', 'cancelled', 'undone', 'stale')),
  summary text not null,
  payload jsonb not null,
  base jsonb not null,               -- öneri anındaki görüntü
  before jsonb,                      -- uygulamadan hemen önce
  after jsonb,                       -- uygulamadan sonra
  created_at timestamptz not null default now(),
  applied_at timestamptz,
  resolved_at timestamptz            -- vazgeçme / geri alma / bayatlama
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  event_id uuid references public.chat_events (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_user_created
  on public.chat_messages (user_id, created_at desc);

-- Günlük sınır sayacı: her başarılı cevapta bir satır. Silme politikası yok,
-- böylece "Sohbeti temizle" sınırı sıfırlamaz.
create table if not exists public.chat_usage (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists chat_usage_user_created on public.chat_usage (user_id, created_at);

alter table public.chat_events enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_usage enable row level security;

create policy "Users can manage own chat events"
  on public.chat_events for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can manage own chat messages"
  on public.chat_messages for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can view own chat usage"
  on public.chat_usage for select
  using (user_id = auth.uid());

create policy "Users can insert own chat usage"
  on public.chat_usage for insert
  with check (user_id = auth.uid());

-- Programın save_program girdisi formatındaki tam hali (yalnız kullanıcının kendi programı).
create or replace function public.program_snapshot(p_program_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'description', p.description,
    'level', p.level,
    'schedule_mode', p.schedule_mode,
    'days_per_week', p.days_per_week,
    'source_program_id', p.source_program_id,
    'workouts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', w.name,
        'weekday', w.weekday,
        'exercises', coalesce((
          select jsonb_agg(jsonb_build_object(
            'exercise_id', e.exercise_id,
            'sets', e.sets,
            'reps_min', e.reps_min,
            'reps_max', e.reps_max,
            'is_amrap', e.is_amrap,
            'percent_1rm', e.percent_1rm,
            'percent_ref_exercise_id', e.percent_ref_exercise_id,
            'rest_seconds', e.rest_seconds,
            'notes', e.notes
          ) order by e.position)
          from workout_exercises e where e.workout_id = w.id
        ), '[]'::jsonb)
      ) order by w.position)
      from program_workouts w where w.program_id = p.id
    ), '[]'::jsonb)
  )
  from programs p
  where p.id = p_program_id and p.user_id = auth.uid();
$$;

-- Bir aracın dokunduğu verinin şu anki hali (spec §3.1). base/before/after hep
-- bununla alınır ve jsonb eşitliğiyle karşılaştırılır.
create or replace function public.chat_target_snapshot(p_tool text, p_payload jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  keys text[];
  result jsonb;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  case p_tool
  when 'log_body_weight' then
    select jsonb_build_object(
      'log', (select l.weight_kg from body_weight_logs l
               where l.user_id = uid and l.logged_on = (p_payload->>'date')::date),
      'profile', (select jsonb_build_object(
                    'weight_kg', p.weight_kg,
                    'daily_calorie_target', p.daily_calorie_target,
                    'daily_protein_target_g', p.daily_protein_target_g)
                  from profiles p where p.user_id = uid))
      into result;
  when 'update_profile', 'set_goal' then
    if p_tool = 'set_goal' then
      keys := array['goal'];
    else
      select array_agg(k order by k) into keys from jsonb_object_keys(p_payload->'changes') k;
    end if;
    keys := coalesce(keys, array[]::text[]) || array['daily_calorie_target', 'daily_protein_target_g'];
    select jsonb_object_agg(k, to_jsonb(p) -> k)
      into result
      from profiles p, unnest(keys) k
      where p.user_id = uid;
  when 'create_meal' then
    select jsonb_build_object('meal', (
      select jsonb_build_object(
        'meal_type', m.meal_type,
        'logged_at', m.logged_at,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', i.name, 'grams', i.grams, 'calories', i.calories,
            'protein_g', i.protein_g, 'carbs_g', i.carbs_g, 'fat_g', i.fat_g
          ) order by i.id)
          from meal_items i where i.meal_id = m.id
        ), '[]'::jsonb))
      from meals m
      where m.id = (p_payload->>'meal_id')::uuid and m.user_id = uid))
      into result;
  when 'log_set' then
    select jsonb_build_object('set', (
      select jsonb_build_object(
        'weight_kg', s.weight_kg,
        'reps', s.reps,
        'completed_at', s.completed_at,
        'finished_at', w.finished_at)
      from session_sets s
      join workout_sessions w on w.id = s.session_id
      where s.session_id = (p_payload->>'session_id')::uuid
        and s.exercise_position = (p_payload->>'exercise_position')::int
        and s.set_index = (p_payload->>'set_index')::int
        and w.user_id = uid))
      into result;
  when 'edit_program' then
    result := jsonb_build_object('program', program_snapshot((p_payload->>'program_id')::uuid));
  else
    raise exception 'unknown_tool %', p_tool;
  end case;

  return result;
end;
$$;

-- Uygulamanın ve Edge Function'ın kullandığı tek mesaj biçimi.
create or replace function public.chat_message_json(m public.chat_messages)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'id', m.id,
    'role', m.role,
    'content', m.content,
    'created_at', m.created_at,
    'event', (select jsonb_build_object(
                'id', e.id, 'tool', e.tool, 'status', e.status,
                'summary', e.summary, 'payload', e.payload, 'base', e.base)
              from chat_events e where e.id = m.event_id));
$$;

-- Son p_limit mesaj, eskiden yeniye.
create or replace function public.recent_chat_messages(p_limit int)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(jsonb_agg(t.j order by t.created_at), '[]'::jsonb)
  from (
    select chat_message_json(m) as j, m.created_at
    from chat_messages m
    where m.user_id = auth.uid()
    order by m.created_at desc
    limit p_limit
  ) t;
$$;

-- Bir soru-cevap çiftini (ve varsa bekleyen öneriyi) tek transaction'da yazar,
-- günlük sayaca bir satır ekler. İki mesajı eskiden yeniye döndürür.
create or replace function public.save_chat_exchange(
  p_user_text text,
  p_assistant_text text,
  p_event jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_event_id uuid;
  v_user_msg uuid;
  v_assistant_msg uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  if p_event is not null then
    insert into chat_events (user_id, tool, summary, payload, base)
      values (uid, p_event->>'tool', p_event->>'summary', p_event->'payload', p_event->'base')
      returning id into v_event_id;
  end if;

  -- clock_timestamp: aynı transaction'daki iki mesaj farklı zaman alsın (sıralama).
  insert into chat_messages (user_id, role, content, created_at)
    values (uid, 'user', p_user_text, clock_timestamp())
    returning id into v_user_msg;
  insert into chat_messages (user_id, role, content, event_id, created_at)
    values (uid, 'assistant', p_assistant_text, v_event_id, clock_timestamp())
    returning id into v_assistant_msg;
  insert into chat_usage (user_id) values (uid);

  return (
    select jsonb_agg(chat_message_json(m) order by m.created_at)
    from chat_messages m
    where m.id in (v_user_msg, v_assistant_msg)
  );
end;
$$;

-- Sohbeti temizler; chat_events ve chat_usage kalır.
create or replace function public.clear_chat()
returns void
language sql
security invoker
set search_path = public
as $$
  delete from chat_messages where user_id = auth.uid();
$$;
```

- [ ] **Step 2: Gözden geçir**

Kontrol: altı aracın her biri `chat_target_snapshot`'ta bir dala sahip; `chat_events.tool` check'i ile aynı altı ad; tüm fonksiyonlar `security invoker` + `set search_path = public`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0010_create_coach_chat.sql
git commit -m "feat(coach): add chat tables, snapshots and message functions"
```

---

### Task 2: Uygula / vazgeç / geri al fonksiyonları ve SQL kontrol scripti

**Files:**
- Modify: `supabase/migrations/0010_create_coach_chat.sql` (sonuna ekle)
- Create: `supabase/migrations/checks/f5_rls_checks.sql`

**Interfaces:**
- Consumes: Task 1'deki tablolar ve `chat_target_snapshot`, `program_snapshot`, `save_chat_exchange`, `recent_chat_messages`, `clear_chat`; mevcut `log_body_weight(date, numeric, numeric, numeric)` (0009) ve `save_program(jsonb)` (0006).
- Produces:
  - `chat_write_profile(p_fields jsonb) returns void` — `p_fields`'ta bulunan profil kolonlarını yazar (height_cm, activity_level, does_exercise, sport_type, exercise_days_per_week, health_notes, goal, weight_kg, daily_calorie_target, daily_protein_target_g)
  - `apply_chat_action(p_event_id uuid, p_extras jsonb) returns text` → `'applied'` | `'stale'`; hata mesajları: `event_not_found`, `event_not_pending`, `invalid_targets`, `invalid_payload`, `invalid_extras`, `set_not_available`, `program_not_found`
  - `p_extras`: profil araçlarında `{"calorie_target": number, "protein_target": number}` (zorunlu); `create_meal`'da isteğe bağlı `{"item_grams": [number, ...]}`
  - `cancel_chat_action(p_event_id uuid) returns void` (hata: `event_not_pending`)
  - `undo_chat_action(p_event_id uuid) returns text` → `'undone'` | `'modified'`; hatalar: `event_not_found`, `event_not_applied`

- [ ] **Step 1: Fonksiyonları migration'ın sonuna ekle**

`supabase/migrations/0010_create_coach_chat.sql` sonuna:

```sql
-- p_fields'ta bulunan profil kolonlarını yazar (uygulama ve geri alma ortak).
create or replace function public.chat_write_profile(p_fields jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update profiles set
    height_cm = case when p_fields ? 'height_cm' then (p_fields->>'height_cm')::numeric else height_cm end,
    activity_level = case when p_fields ? 'activity_level' then p_fields->>'activity_level' else activity_level end,
    does_exercise = case when p_fields ? 'does_exercise' then (p_fields->>'does_exercise')::boolean else does_exercise end,
    sport_type = case when p_fields ? 'sport_type' then p_fields->>'sport_type' else sport_type end,
    exercise_days_per_week = case when p_fields ? 'exercise_days_per_week'
                                  then (p_fields->>'exercise_days_per_week')::int else exercise_days_per_week end,
    health_notes = case when p_fields ? 'health_notes' then p_fields->>'health_notes' else health_notes end,
    goal = case when p_fields ? 'goal' then p_fields->>'goal' else goal end,
    weight_kg = case when p_fields ? 'weight_kg' then (p_fields->>'weight_kg')::numeric else weight_kg end,
    daily_calorie_target = case when p_fields ? 'daily_calorie_target'
                                then (p_fields->>'daily_calorie_target')::numeric else daily_calorie_target end,
    daily_protein_target_g = case when p_fields ? 'daily_protein_target_g'
                                  then (p_fields->>'daily_protein_target_g')::numeric else daily_protein_target_g end,
    updated_at = now()
  where user_id = auth.uid();
end;
$$;

-- Bekleyen öneriyi uygular. Veri öneriden beri değiştiyse 'stale' (hiçbir şey değişmez).
create or replace function public.apply_chat_action(p_event_id uuid, p_extras jsonb)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  ev chat_events%rowtype;
  cur jsonb;
  p jsonb;
  targets jsonb;
  item jsonb;
  grams numeric;
  idx int := 0;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select * into ev from chat_events where id = p_event_id and user_id = uid for update;
  if not found then
    raise exception 'event_not_found';
  end if;
  if ev.status <> 'pending' then
    raise exception 'event_not_pending';
  end if;

  cur := chat_target_snapshot(ev.tool, ev.payload);
  if cur is distinct from ev.base then
    update chat_events set status = 'stale', resolved_at = now() where id = ev.id;
    return 'stale';
  end if;

  p := ev.payload;

  if ev.tool in ('log_body_weight', 'update_profile', 'set_goal') then
    if coalesce((p_extras->>'calorie_target')::numeric, 0) <= 0
       or coalesce((p_extras->>'protein_target')::numeric, 0) <= 0 then
      raise exception 'invalid_targets';
    end if;
    targets := jsonb_build_object(
      'daily_calorie_target', (p_extras->>'calorie_target')::numeric,
      'daily_protein_target_g', (p_extras->>'protein_target')::numeric);
  end if;

  case ev.tool
  when 'log_body_weight' then
    if (p->>'kg')::numeric not between 20 and 400 or (p->>'date') is null then
      raise exception 'invalid_payload';
    end if;
    perform log_body_weight((p->>'date')::date, (p->>'kg')::numeric,
                            (targets->>'daily_calorie_target')::numeric,
                            (targets->>'daily_protein_target_g')::numeric);
  when 'update_profile' then
    if jsonb_typeof(p->'changes') is distinct from 'object'
       or exists (select 1 from jsonb_object_keys(p->'changes') k
                  where k not in ('height_cm', 'activity_level', 'does_exercise', 'sport_type',
                                  'exercise_days_per_week', 'health_notes')) then
      raise exception 'invalid_payload';
    end if;
    perform chat_write_profile((p->'changes') || targets);
  when 'set_goal' then
    perform chat_write_profile(jsonb_build_object('goal', p->>'goal') || targets);
  when 'create_meal' then
    if p_extras ? 'item_grams'
       and jsonb_array_length(p_extras->'item_grams') <> jsonb_array_length(p->'items') then
      raise exception 'invalid_extras';
    end if;
    insert into meals (id, user_id, meal_type, logged_at)
      values ((p->>'meal_id')::uuid, uid, p->>'meal_type', (p->>'logged_at')::timestamptz);
    for item in select value from jsonb_array_elements(p->'items') loop
      grams := coalesce((p_extras->'item_grams'->>idx)::numeric, (item->>'grams')::numeric);
      if grams is null or grams <= 0 then
        raise exception 'invalid_extras';
      end if;
      insert into meal_items (meal_id, name, grams, calories, protein_g, carbs_g, fat_g,
                              usda_fdc_id, needs_review)
      values (
        (p->>'meal_id')::uuid, item->>'name', grams,
        round(grams * (item->'per100'->>'calories')::numeric / 100, 1),
        round(grams * (item->'per100'->>'protein_g')::numeric / 100, 1),
        round(grams * (item->'per100'->>'carbs_g')::numeric / 100, 1),
        round(grams * (item->'per100'->>'fat_g')::numeric / 100, 1),
        item->>'usda_fdc_id',
        coalesce((item->>'needs_review')::boolean, false));
      idx := idx + 1;
    end loop;
  when 'log_set' then
    if jsonb_typeof(cur->'set') is distinct from 'object' or (cur->'set'->>'finished_at') is not null then
      raise exception 'set_not_available';
    end if;
    update session_sets
      set weight_kg = (p->>'weight_kg')::numeric,
          reps = (p->>'reps')::int,
          completed_at = coalesce(completed_at, now())
      where session_id = (p->>'session_id')::uuid
        and exercise_position = (p->>'exercise_position')::int
        and set_index = (p->>'set_index')::int;
  when 'edit_program' then
    if jsonb_typeof(cur->'program') is distinct from 'object' then
      raise exception 'program_not_found';
    end if;
    perform save_program((p->'program') || jsonb_build_object('id', p->>'program_id'));
  end case;

  update chat_events
    set status = 'applied',
        before = cur,
        after = chat_target_snapshot(ev.tool, ev.payload),
        applied_at = now()
    where id = ev.id;
  return 'applied';
end;
$$;

create or replace function public.cancel_chat_action(p_event_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update chat_events set status = 'cancelled', resolved_at = now()
    where id = p_event_id and user_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'event_not_pending';
  end if;
end;
$$;

-- Uygulanmış öneriyi geri alır. Veri uygulamadan sonra değiştiyse 'modified'
-- (hiçbir şey değişmez).
create or replace function public.undo_chat_action(p_event_id uuid)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  ev chat_events%rowtype;
  b jsonb;
  p jsonb;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select * into ev from chat_events where id = p_event_id and user_id = uid for update;
  if not found then
    raise exception 'event_not_found';
  end if;
  if ev.status <> 'applied' then
    raise exception 'event_not_applied';
  end if;
  if chat_target_snapshot(ev.tool, ev.payload) is distinct from ev.after then
    return 'modified';
  end if;

  b := ev.before;
  p := ev.payload;

  case ev.tool
  when 'log_body_weight' then
    if jsonb_typeof(b->'log') = 'number' then
      update body_weight_logs set weight_kg = (b->>'log')::numeric
        where user_id = uid and logged_on = (p->>'date')::date;
    else
      delete from body_weight_logs where user_id = uid and logged_on = (p->>'date')::date;
    end if;
    perform chat_write_profile(b->'profile');
  when 'update_profile', 'set_goal' then
    perform chat_write_profile(b);
  when 'create_meal' then
    delete from meals where id = (p->>'meal_id')::uuid and user_id = uid;
  when 'log_set' then
    update session_sets
      set weight_kg = (b->'set'->>'weight_kg')::numeric,
          reps = (b->'set'->>'reps')::int,
          completed_at = (b->'set'->>'completed_at')::timestamptz
      where session_id = (p->>'session_id')::uuid
        and exercise_position = (p->>'exercise_position')::int
        and set_index = (p->>'set_index')::int;
  when 'edit_program' then
    perform save_program(b->'program');
  end case;

  update chat_events set status = 'undone', resolved_at = now() where id = ev.id;
  return 'undone';
end;
$$;
```

- [ ] **Step 2: Kontrol scriptini yaz**

`supabase/migrations/checks/f5_rls_checks.sql`:

```sql
-- F5 RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- A = profili olan bir kullanıcı, B = başka bir kullanıcı. Sonuç bilerek HATA
-- olarak basılır; hata tüm değişiklikleri geri aldığı için veritabanında
-- hiçbir şey değişmez.
-- Beklenen: kilo=t profil=t amac=t ogun=t set=t program=t bayat=stale
--           engel=modified tekrar_engellendi=t iptal=t kayit=t B_gorulen=0
--           B_engellendi=t usage_silinemedi=t temizle=t
do $$
declare
  a uuid;
  b uuid;
  ex1 text;
  ex2 text;
  e uuid;
  e_applied uuid;
  pl jsonb;
  r text;
  snap jsonb;
  pid uuid;
  sid uuid;
  mid uuid := gen_random_uuid();
  n int;
  ok_weight boolean;
  ok_profile boolean;
  ok_goal boolean;
  ok_meal boolean;
  ok_set boolean;
  ok_program boolean;
  stale_result text;
  modified_result text;
  reapply_blocked boolean := false;
  cancel_ok boolean := false;
  exchange_ok boolean;
  b_seen int;
  b_blocked boolean := false;
  usage_kept boolean;
  clear_ok boolean;
  w numeric;
  c numeric;
  h numeric;
  g text;
begin
  select p.user_id into a from public.profiles p limit 1;
  select u.id into b from auth.users u where u.id <> a limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;
  select id into ex1 from public.exercises where user_id is null order by id limit 1;
  select id into ex2 from public.exercises where user_id is null order by id offset 1 limit 1;

  -- A'yı bilinen bir başlangıca getir (hepsi geri alınacak).
  delete from public.body_weight_logs where user_id = a;
  insert into public.body_weight_logs (user_id, logged_on, weight_kg) values (a, date '2026-01-10', 80);
  update public.profiles
    set weight_kg = 80, height_cm = 180, goal = 'maintain', activity_level = 'moderate',
        daily_calorie_target = 2700, daily_protein_target_g = 160
    where user_id = a;
  delete from public.workout_sessions where user_id = a and finished_at is null;

  -- A olarak
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- 1) Kilo: uygula → profil 82/3000; geri al → 80/2700 ve kayıt silinir
  pl := jsonb_build_object('date', '2026-01-20', 'kg', 82);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_body_weight', 's', pl, public.chat_target_snapshot('log_body_weight', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"calorie_target": 3000, "protein_target": 180}');
  select weight_kg, daily_calorie_target into w, c from public.profiles where user_id = a;
  ok_weight := r = 'applied' and w = 82 and c = 3000;
  r := public.undo_chat_action(e);
  select weight_kg, daily_calorie_target into w, c from public.profiles where user_id = a;
  ok_weight := ok_weight and r = 'undone' and w = 80 and c = 2700
    and not exists (select 1 from public.body_weight_logs where user_id = a and logged_on = date '2026-01-20');

  -- 2) Profil: boy 185 → geri al → 180
  pl := jsonb_build_object('changes', jsonb_build_object('height_cm', 185));
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'update_profile', 's', pl, public.chat_target_snapshot('update_profile', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"calorie_target": 2800, "protein_target": 170}');
  select height_cm into h from public.profiles where user_id = a;
  ok_profile := r = 'applied' and h = 185;
  r := public.undo_chat_action(e);
  select height_cm, daily_calorie_target into h, c from public.profiles where user_id = a;
  ok_profile := ok_profile and r = 'undone' and h = 180 and c = 2700;

  -- 3) Amaç: lose_weight → geri al → maintain
  pl := jsonb_build_object('goal', 'lose_weight');
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'set_goal', 's', pl, public.chat_target_snapshot('set_goal', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"calorie_target": 2700, "protein_target": 160}');
  select goal into g from public.profiles where user_id = a;
  ok_goal := r = 'applied' and g = 'lose_weight';
  r := public.undo_chat_action(e);
  select goal into g from public.profiles where user_id = a;
  ok_goal := ok_goal and r = 'undone' and g = 'maintain';

  -- 4) Öğün: kartta düzenlenen gramlarla iki kalem; geri al → öğün silinir
  pl := jsonb_build_object(
    'meal_id', mid, 'meal_type', 'lunch', 'logged_at', '2026-01-20T12:00:00Z',
    'items', jsonb_build_array(
      jsonb_build_object('name', 'Tavuk', 'grams', 100, 'usda_fdc_id', '1', 'needs_review', false,
        'per100', jsonb_build_object('calories', 165, 'protein_g', 31, 'carbs_g', 0, 'fat_g', 3.6)),
      jsonb_build_object('name', 'Pilav', 'grams', 100, 'usda_fdc_id', null, 'needs_review', true,
        'per100', jsonb_build_object('calories', 130, 'protein_g', 2.7, 'carbs_g', 28, 'fat_g', 0.3))));
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'create_meal', 's', pl, public.chat_target_snapshot('create_meal', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"item_grams": [200, 150]}');
  select count(*) into n from public.meal_items where meal_id = mid;
  select calories into c from public.meal_items where meal_id = mid and name = 'Tavuk';
  ok_meal := r = 'applied' and n = 2 and c = 330;
  r := public.undo_chat_action(e);
  ok_meal := ok_meal and r = 'undone' and not exists (select 1 from public.meals where id = mid);

  -- 5) Set: devam eden oturumda set kaydı → geri al → boş
  insert into public.workout_sessions (user_id, program_name, workout_name, workout_position)
    values (a, 'P', 'A', 0) returning id into sid;
  insert into public.session_sets (session_id, exercise_position, set_index, exercise_id,
                                   target_reps_min, target_reps_max)
    values (sid, 0, 0, ex1, 5, 5);
  pl := jsonb_build_object('session_id', sid, 'exercise_position', 0, 'set_index', 0,
                           'weight_kg', 80, 'reps', 5);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_set', 's', pl, public.chat_target_snapshot('log_set', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{}');
  select weight_kg into w from public.session_sets where session_id = sid;
  ok_set := r = 'applied' and w = 80;
  r := public.undo_chat_action(e);
  ok_set := ok_set and r = 'undone' and exists (
    select 1 from public.session_sets where session_id = sid and weight_kg is null and completed_at is null);

  -- 6) Program: hareket ekle → 2 hareket; geri al → 1
  pid := public.save_program(jsonb_build_object(
    'name', 'F5 Test', 'schedule_mode', 'rotation',
    'workouts', jsonb_build_array(jsonb_build_object('name', 'A',
      'exercises', jsonb_build_array(jsonb_build_object('exercise_id', ex1, 'sets', 3, 'reps_min', 5, 'reps_max', 5)))))));
  snap := public.program_snapshot(pid);
  snap := jsonb_set(snap, '{workouts,0,exercises}',
    (snap->'workouts'->0->'exercises') || jsonb_build_array(
      jsonb_build_object('exercise_id', ex2, 'sets', 3, 'reps_min', 8, 'reps_max', 12)));
  pl := jsonb_build_object('program_id', pid, 'program', snap, 'changes', '[]'::jsonb);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'edit_program', 's', pl, public.chat_target_snapshot('edit_program', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{}');
  select count(*) into n from public.workout_exercises we
    join public.program_workouts pw on pw.id = we.workout_id where pw.program_id = pid;
  ok_program := r = 'applied' and n = 2;
  r := public.undo_chat_action(e);
  select count(*) into n from public.workout_exercises we
    join public.program_workouts pw on pw.id = we.workout_id where pw.program_id = pid;
  ok_program := ok_program and r = 'undone' and n = 1;

  -- 7) Bayatlama: öneriden sonra hedef değişirse uygulanmaz
  pl := jsonb_build_object('date', '2026-01-25', 'kg', 83);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_body_weight', 's', pl, public.chat_target_snapshot('log_body_weight', pl))
    returning id into e;
  update public.profiles set daily_calorie_target = 2650 where user_id = a;
  stale_result := public.apply_chat_action(e, '{"calorie_target": 3000, "protein_target": 180}');
  select weight_kg into w from public.profiles where user_id = a;
  if w <> 80 then stale_result := stale_result || '_AMA_DEGISTI'; end if;

  -- 8) Geri alma engeli: uygulamadan sonra yeni kilo kaydı gelirse 'modified'
  pl := jsonb_build_object('date', '2026-01-25', 'kg', 83);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_body_weight', 's', pl, public.chat_target_snapshot('log_body_weight', pl))
    returning id into e_applied;
  r := public.apply_chat_action(e_applied, '{"calorie_target": 3000, "protein_target": 180}');
  perform public.log_body_weight(date '2026-01-30', 84, 3050, 182);
  modified_result := public.undo_chat_action(e_applied);

  -- 9) Uygulanmış öneri tekrar uygulanamaz
  begin
    perform public.apply_chat_action(e_applied, '{"calorie_target": 3000, "protein_target": 180}');
  exception when others then
    reapply_blocked := sqlerrm like '%event_not_pending%';
  end;

  -- 10) Vazgeçilen öneri uygulanamaz
  pl := jsonb_build_object('goal', 'gain_muscle');
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'set_goal', 's', pl, public.chat_target_snapshot('set_goal', pl))
    returning id into e;
  perform public.cancel_chat_action(e);
  begin
    perform public.apply_chat_action(e, '{"calorie_target": 2700, "protein_target": 160}');
  exception when others then
    cancel_ok := sqlerrm like '%event_not_pending%';
  end;

  -- 11) Mesaj çifti + öneri kaydı
  pl := jsonb_build_object('goal', 'gain_muscle');
  snap := public.save_chat_exchange('merhaba', 'amacını değiştireyim mi?',
    jsonb_build_object('tool', 'set_goal', 'summary', 's', 'payload', pl,
                       'base', public.chat_target_snapshot('set_goal', pl)));
  exchange_ok := jsonb_array_length(snap) = 2
    and snap->0->>'role' = 'user'
    and snap->1->'event'->>'tool' = 'set_goal'
    and jsonb_array_length(public.recent_chat_messages(10)) >= 2;

  -- 12) B olarak: A'nın mesaj ve önerilerini göremez, uygulayamaz
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select (select count(*) from public.chat_messages where user_id = a)
       + (select count(*) from public.chat_events where user_id = a)
    into b_seen;
  begin
    perform public.undo_chat_action(e_applied);
  exception when others then
    b_blocked := sqlerrm like '%event_not_found%';
  end;

  -- 13) A olarak: sayaç silinemez, sohbeti temizle mesajları siler ama olayları değil
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  delete from public.chat_usage where user_id = a;
  get diagnostics n = row_count;
  usage_kept := n = 0;
  perform public.clear_chat();
  clear_ok := not exists (select 1 from public.chat_messages where user_id = a)
    and exists (select 1 from public.chat_events where user_id = a);

  reset role;

  raise exception 'SONUC kilo=% profil=% amac=% ogun=% set=% program=% bayat=% engel=% tekrar_engellendi=% iptal=% kayit=% B_gorulen=% B_engellendi=% usage_silinemedi=% temizle=%',
    ok_weight, ok_profile, ok_goal, ok_meal, ok_set, ok_program, stale_result, modified_result,
    reapply_blocked, cancel_ok, exchange_ok, b_seen, b_blocked, usage_kept, clear_ok;
end;
$$;
```

- [ ] **Step 3: Gözden geçir**

Kontrol: scriptte kullanılan her fonksiyon adı ve parametre sırası migration'dakiyle aynı; beklenen satır dosyanın başındaki yorumla aynı.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0010_create_coach_chat.sql supabase/migrations/checks/f5_rls_checks.sql
git commit -m "feat(coach): add apply/cancel/undo chat action functions and RLS checks"
```

---
### Task 3: Ortak Edge Function kodunu `_shared`'e taşı

**Files:**
- Create: `supabase/functions/_shared/http.ts`
- Move: `supabase/functions/analyze-meal-photo/auth.test.ts` → `supabase/functions/_shared/http.test.ts`
- Move: `supabase/functions/analyze-meal-photo/usda_client.ts` → `supabase/functions/_shared/usda_client.ts`
- Move: `supabase/functions/analyze-meal-photo/usda_client.test.ts` → `supabase/functions/_shared/usda_client.test.ts`
- Modify: `supabase/functions/analyze-meal-photo/index.ts`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces (`_shared/http.ts`):
  - `getUserIdFromAuthHeader(req: Request): string | null` (davranışı değişmez)
  - `corsHeaders: Record<string, string>`
  - `jsonResponse(status: number, body: unknown): Response` (CORS + `Content-Type: application/json`)
- Produces (`_shared/usda_client.ts`, içerik değişmez): `findBestMatch(foodName, apiKey, fetchFn?)`, `fetchMacrosPer100g(fdcId, apiKey, fetchFn?)`, tipler `UsdaFood`, `Macros {calories, proteinG, carbsG, fatG}`

Not: `_shared` klasörü Supabase CLI'nin `functions deploy` komutuyla birlikte paketlenir; bu taşıma nedeniyle `analyze-meal-photo` da Task 13'te yeniden deploy edilir.

- [ ] **Step 1: Dosyaları taşı**

```bash
mkdir -p supabase/functions/_shared
git mv supabase/functions/analyze-meal-photo/usda_client.ts supabase/functions/_shared/usda_client.ts
git mv supabase/functions/analyze-meal-photo/usda_client.test.ts supabase/functions/_shared/usda_client.test.ts
git mv supabase/functions/analyze-meal-photo/auth.test.ts supabase/functions/_shared/http.test.ts
```

- [ ] **Step 2: Testin import'unu güncelle ve başarısız olduğunu gör**

`supabase/functions/_shared/http.test.ts` 2. satır:

```ts
import { getUserIdFromAuthHeader } from './http.ts';
```

Run: `deno test supabase/functions/_shared/`
Expected: FAIL — `Module not found ".../_shared/http.ts"`.

- [ ] **Step 3: `_shared/http.ts`'i yaz**

```ts
// Edge Function'ların ortak HTTP yardımcıları.

/** JWT'nin `sub` alanı. İmza burada doğrulanmaz: Supabase gateway (verify_jwt)
 * ve PostgREST doğrular; bu yalnızca yol/sahiplik kontrolleri içindir. */
export function getUserIdFromAuthHeader(req: Request): string | null {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;
  const token = authHeader.slice('Bearer '.length);
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const payload = JSON.parse(atob(base64));
    return typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

export function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
```

- [ ] **Step 4: `analyze-meal-photo/index.ts`'i ortak modüllere bağla**

Dosyanın başındaki importları şununla değiştir:

```ts
import { corsHeaders, getUserIdFromAuthHeader, jsonResponse } from '../_shared/http.ts';
import { fetchMacrosPer100g, findBestMatch } from '../_shared/usda_client.ts';
import type { Macros, UsdaFood } from '../_shared/usda_client.ts';
import { GeminiQuotaExceededError, GeminiUnavailableError, identifyFoodItems } from './gemini_client.ts';
import type { FoodPrediction } from './gemini_client.ts';
```

Dosyadaki yerel `export function getUserIdFromAuthHeader(...) { ... }` fonksiyonunu ve `const corsHeaders = { ... };` tanımını sil. `Deno.serve` içindeki dört `new Response(JSON.stringify(X), { status: N, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })` ifadesinin her birini `jsonResponse(N, X)` ile değiştir (OPTIONS cevabı `new Response('ok', { headers: corsHeaders })` olarak kalır). Davranış aynıdır.

- [ ] **Step 5: CI'da tüm fonksiyonları test et**

`.github/workflows/ci.yml`:

```yaml
      - name: Run Edge Function tests
        run: deno test supabase/functions/
```

- [ ] **Step 6: Testleri çalıştır**

Run: `deno test supabase/functions/`
Expected: PASS — `29 passed | 0 failed` (taşınan testler dahil, sayı değişmez).

- [ ] **Step 7: Commit**

```bash
git add supabase/functions .github/workflows/ci.yml
git commit -m "refactor(functions): move shared HTTP and USDA helpers to _shared"
```

---

### Task 4: Sağlayıcıdan bağımsız LLM katmanı ve Gemini istemcisi

**Files:**
- Create: `supabase/functions/coach-chat/llm/types.ts`
- Create: `supabase/functions/coach-chat/llm/gemini_client.ts`
- Create: `supabase/functions/coach-chat/llm/factory.ts`
- Test: `supabase/functions/coach-chat/llm/gemini_client.test.ts`
- Test: `supabase/functions/coach-chat/llm/factory.test.ts`

**Interfaces:**
- Produces (`llm/types.ts`):

```ts
export type LlmMessage =
  | { role: 'user'; text: string }
  | { role: 'assistant'; text: string }
  | { role: 'assistant_tool_call'; name: string; args: Record<string, unknown>; raw?: unknown }
  | { role: 'tool_result'; name: string; result: Record<string, unknown> };
export interface ToolDefinition { name: string; description: string; parameters: Record<string, unknown> }
export interface LlmRequest { system: string; messages: LlmMessage[]; tools: ToolDefinition[] }
export type LlmResponse =
  | { type: 'text'; text: string }
  | { type: 'tool_call'; name: string; args: Record<string, unknown>; text: string; raw?: unknown };
export interface LlmClient { generate(req: LlmRequest): Promise<LlmResponse> }
export class LlmQuotaError extends Error {}
export class LlmUnavailableError extends Error {}
```

- Produces (`llm/gemini_client.ts`): `class GeminiClient implements LlmClient { constructor(apiKey: string, model: string, fetchFn?: typeof fetch) }`
- Produces (`llm/factory.ts`): `DEFAULT_GEMINI_MODEL = 'gemini-3.5-flash-lite'`, `interface LlmEnv { provider?: string; model?: string; geminiApiKey?: string }`, `createLlmClient(env: LlmEnv, fetchFn?: typeof fetch): LlmClient`

`raw`: sağlayıcının araç çağrısı parçası, sonraki istekte aynen geri gönderilir. Gemini 3 modelleri çok turlu function calling'de `thoughtSignature`'ın geri gönderilmesini ister; bunu yalnız `gemini_client.ts` bilir.

- [ ] **Step 1: Tipleri yaz**

`supabase/functions/coach-chat/llm/types.ts` — yukarıdaki Interfaces bloğunun aynısı, başına şu yorumla:

```ts
// Sağlayıcıdan bağımsız LLM formatı. Sağlayıcıya özgü çeviri yalnız *_client.ts
// dosyalarındadır; yeni sağlayıcı = yeni bir client + factory.ts'te bir satır.
```

- [ ] **Step 2: Gemini istemcisi testlerini yaz**

`supabase/functions/coach-chat/llm/gemini_client.test.ts`:

```ts
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { GeminiClient } from './gemini_client.ts';
import { LlmQuotaError, LlmUnavailableError } from './types.ts';
import type { LlmRequest } from './types.ts';

function capture(response: Response | (() => Promise<Response>)) {
  const calls: Array<{ url: string; body: Record<string, unknown> }> = [];
  const fetchFn: typeof fetch = async (input, init) => {
    calls.push({ url: String(input), body: JSON.parse(String(init?.body)) });
    return typeof response === 'function' ? await response() : response.clone();
  };
  return { calls, fetchFn };
}

function geminiResponse(parts: unknown[]): Response {
  return new Response(JSON.stringify({ candidates: [{ content: { role: 'model', parts } }] }), { status: 200 });
}

const tool = { name: 'set_goal', description: 'd', parameters: { type: 'object', properties: {} } };

const baseRequest: LlmRequest = {
  system: 'SYSTEM',
  messages: [
    { role: 'user', text: 'merhaba' },
    { role: 'assistant', text: 'selam' },
    { role: 'user', text: 'amacım kilo vermek' },
  ],
  tools: [tool],
};

Deno.test('sends system instruction, mapped contents and function declarations', async () => {
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'Tamam' }]));
  await new GeminiClient('KEY', 'gemini-test', fetchFn).generate(baseRequest);

  assertEquals(calls[0].url, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent?key=KEY');
  assertEquals(calls[0].body.systemInstruction, { parts: [{ text: 'SYSTEM' }] });
  assertEquals(calls[0].body.contents, [
    { role: 'user', parts: [{ text: 'merhaba' }] },
    { role: 'model', parts: [{ text: 'selam' }] },
    { role: 'user', parts: [{ text: 'amacım kilo vermek' }] },
  ]);
  assertEquals(calls[0].body.tools, [{ functionDeclarations: [tool] }]);
});

Deno.test('omits tools when none are given', async () => {
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'Tamam' }]));
  await new GeminiClient('KEY', 'm', fetchFn).generate({ ...baseRequest, tools: [] });
  assertEquals('tools' in calls[0].body, false);
});

Deno.test('parses a text reply, skipping thought parts', async () => {
  const { fetchFn } = capture(geminiResponse([{ text: 'düşünce', thought: true }, { text: 'Merhaba ' }, { text: 'dünya' }]));
  const res = await new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest);
  assertEquals(res, { type: 'text', text: 'Merhaba dünya' });
});

Deno.test('parses a function call and keeps the raw part (thought signature)', async () => {
  const part = { functionCall: { name: 'set_goal', args: { goal: 'lose_weight' } }, thoughtSignature: 'SIG' };
  const { fetchFn } = capture(geminiResponse([{ text: 'Önereyim:' }, part]));
  const res = await new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest);
  assertEquals(res, { type: 'tool_call', name: 'set_goal', args: { goal: 'lose_weight' }, text: 'Önereyim:', raw: part });
});

Deno.test('re-sends a tool call raw part and maps tool results to functionResponse', async () => {
  const part = { functionCall: { name: 'set_goal', args: { goal: 'x' } }, thoughtSignature: 'SIG' };
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'ok' }]));
  await new GeminiClient('KEY', 'm', fetchFn).generate({
    ...baseRequest,
    messages: [
      { role: 'user', text: 'hedef' },
      { role: 'assistant_tool_call', name: 'set_goal', args: { goal: 'x' }, raw: part },
      { role: 'tool_result', name: 'set_goal', result: { error: 'invalid goal' } },
    ],
  });
  assertEquals((calls[0].body.contents as unknown[]).slice(1), [
    { role: 'model', parts: [part] },
    { role: 'user', parts: [{ functionResponse: { name: 'set_goal', response: { error: 'invalid goal' } } }] },
  ]);
});

Deno.test('builds a functionCall part when no raw part is available', async () => {
  const { calls, fetchFn } = capture(geminiResponse([{ text: 'ok' }]));
  await new GeminiClient('KEY', 'm', fetchFn).generate({
    ...baseRequest,
    messages: [{ role: 'assistant_tool_call', name: 'set_goal', args: { goal: 'x' } }],
  });
  assertEquals(calls[0].body.contents, [{ role: 'model', parts: [{ functionCall: { name: 'set_goal', args: { goal: 'x' } } }] }]);
});

Deno.test('maps HTTP 429 to LlmQuotaError', async () => {
  const { fetchFn } = capture(new Response('quota', { status: 429 }));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmQuotaError);
});

Deno.test('maps other HTTP errors to LlmUnavailableError', async () => {
  const { fetchFn } = capture(new Response('boom', { status: 503 }));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmUnavailableError);
});

Deno.test('maps network failures to LlmUnavailableError', async () => {
  const { fetchFn } = capture(() => Promise.reject(new TypeError('network')));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmUnavailableError);
});

Deno.test('treats an empty reply as unavailable', async () => {
  const { fetchFn } = capture(geminiResponse([]));
  await assertRejects(() => new GeminiClient('KEY', 'm', fetchFn).generate(baseRequest), LlmUnavailableError);
});
```

- [ ] **Step 3: Testlerin başarısız olduğunu gör**

Run: `deno test supabase/functions/coach-chat/llm/`
Expected: FAIL — `Module not found ".../gemini_client.ts"`.

- [ ] **Step 4: Gemini istemcisini yaz**

`supabase/functions/coach-chat/llm/gemini_client.ts`:

```ts
import { LlmQuotaError, LlmUnavailableError } from './types.ts';
import type { LlmClient, LlmMessage, LlmRequest, LlmResponse } from './types.ts';

const TIMEOUT_MS = 25_000;

interface GeminiPart {
  text?: string;
  thought?: boolean;
  functionCall?: { name: string; args?: Record<string, unknown> };
  functionResponse?: { name: string; response: Record<string, unknown> };
  thoughtSignature?: string;
}

function toContents(messages: LlmMessage[]): Array<{ role: string; parts: GeminiPart[] }> {
  return messages.map((message) => {
    switch (message.role) {
      case 'user':
        return { role: 'user', parts: [{ text: message.text }] };
      case 'assistant':
        return { role: 'model', parts: [{ text: message.text }] };
      case 'assistant_tool_call':
        // Gemini 3, function calling turlarında thoughtSignature'ın geri gönderilmesini
        // ister: modelin döndürdüğü parça aynen gönderilir.
        return {
          role: 'model',
          parts: [(message.raw as GeminiPart | undefined) ?? { functionCall: { name: message.name, args: message.args } }],
        };
      case 'tool_result':
        return { role: 'user', parts: [{ functionResponse: { name: message.name, response: message.result } }] };
    }
  });
}

export class GeminiClient implements LlmClient {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async generate(req: LlmRequest): Promise<LlmResponse> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;
    const body: Record<string, unknown> = {
      systemInstruction: { parts: [{ text: req.system }] },
      contents: toContents(req.messages),
    };
    if (req.tools.length > 0) {
      body.tools = [{ functionDeclarations: req.tools }];
    }

    let response: Response;
    try {
      response = await this.fetchFn(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch (error) {
      throw new LlmUnavailableError(`Gemini request failed: ${error}`);
    }
    if (response.status === 429) {
      throw new LlmQuotaError('Gemini rate limit exceeded');
    }
    if (!response.ok) {
      throw new LlmUnavailableError(`Gemini request failed: ${response.status} ${await response.text()}`);
    }

    const data = await response.json();
    const parts: GeminiPart[] = data?.candidates?.[0]?.content?.parts ?? [];
    const text = parts
      .filter((part) => typeof part.text === 'string' && !part.thought)
      .map((part) => part.text)
      .join('')
      .trim();
    const call = parts.find((part) => part.functionCall);
    if (call?.functionCall) {
      return { type: 'tool_call', name: call.functionCall.name, args: call.functionCall.args ?? {}, text, raw: call };
    }
    if (text.length === 0) {
      throw new LlmUnavailableError(`Gemini returned no content: ${JSON.stringify(data)}`);
    }
    return { type: 'text', text };
  }
}
```

- [ ] **Step 5: Testlerin geçtiğini gör**

Run: `deno test supabase/functions/coach-chat/llm/gemini_client.test.ts`
Expected: PASS — 10 test.

- [ ] **Step 6: Fabrika testini yaz**

`supabase/functions/coach-chat/llm/factory.test.ts`:

```ts
import { assertEquals, assertInstanceOf, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { createLlmClient } from './factory.ts';
import { GeminiClient } from './gemini_client.ts';

Deno.test('defaults to Gemini with the default model', async () => {
  let url = '';
  const fetchFn: typeof fetch = async (input) => {
    url = String(input);
    return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: 'ok' }] } }] }));
  };
  const client = createLlmClient({ geminiApiKey: 'KEY' }, fetchFn);
  assertInstanceOf(client, GeminiClient);
  await client.generate({ system: 's', messages: [{ role: 'user', text: 'x' }], tools: [] });
  assertEquals(url.includes('/models/gemini-3.5-flash-lite:generateContent'), true);
});

Deno.test('empty strings fall back to defaults', () => {
  assertInstanceOf(createLlmClient({ provider: '', model: '', geminiApiKey: 'KEY' }), GeminiClient);
});

Deno.test('rejects an unknown provider', () => {
  assertThrows(() => createLlmClient({ provider: 'acme', geminiApiKey: 'KEY' }), Error, 'acme');
});

Deno.test('requires the Gemini API key', () => {
  assertThrows(() => createLlmClient({ provider: 'gemini' }), Error, 'GEMINI_API_KEY');
});
```

- [ ] **Step 7: Fabrikayı yaz**

`supabase/functions/coach-chat/llm/factory.ts`:

```ts
import { GeminiClient } from './gemini_client.ts';
import type { LlmClient } from './types.ts';

export const DEFAULT_GEMINI_MODEL = 'gemini-3.5-flash-lite';

export interface LlmEnv {
  provider?: string;
  model?: string;
  geminiApiKey?: string;
}

/** LLM_PROVIDER / LLM_MODEL secret'larına göre istemci. Boş değer = varsayılan. */
export function createLlmClient(env: LlmEnv, fetchFn: typeof fetch = fetch): LlmClient {
  const provider = env.provider || 'gemini';
  switch (provider) {
    case 'gemini':
      if (!env.geminiApiKey) throw new Error('GEMINI_API_KEY eksik');
      return new GeminiClient(env.geminiApiKey, env.model || DEFAULT_GEMINI_MODEL, fetchFn);
    default:
      throw new Error(`Bilinmeyen LLM_PROVIDER: ${provider}`);
  }
}
```

- [ ] **Step 8: Testleri çalıştır**

Run: `deno test supabase/functions/coach-chat/llm/`
Expected: PASS — 14 test.

- [ ] **Step 9: Commit**

```bash
git add supabase/functions/coach-chat/llm
git commit -m "feat(coach): add provider-neutral LLM client with Gemini implementation"
```

---

### Task 5: Ortak tipler, veri özeti, geçmiş ve sistem talimatı

**Files:**
- Create: `supabase/functions/coach-chat/types.ts`
- Create: `supabase/functions/coach-chat/context.ts`
- Create: `supabase/functions/coach-chat/prompts.ts`
- Create: `supabase/functions/coach-chat/test_fixtures.ts`
- Test: `supabase/functions/coach-chat/context.test.ts`

**Interfaces:**
- Consumes: `LlmMessage` (Task 4).
- Produces (`types.ts`):

```ts
export type Locale = 'tr' | 'en';
export const TOOL_NAMES = ['log_body_weight', 'update_profile', 'set_goal', 'create_meal', 'log_set', 'edit_program'] as const;
export type ToolName = typeof TOOL_NAMES[number];
export type EventStatus = 'pending' | 'applied' | 'cancelled' | 'undone' | 'stale';
export interface StoredEvent { id: string; tool: ToolName; status: EventStatus; summary: string; payload: Record<string, unknown>; base: unknown }
export interface StoredMessage { id: string; role: 'user' | 'assistant'; content: string; created_at: string; event: StoredEvent | null }
export interface NewEvent { tool: ToolName; summary: string; payload: Record<string, unknown>; base: unknown }
export interface ProfileRow { weight_kg: number; height_cm: number; birth_year: number; gender: string; activity_level: string; does_exercise: boolean; sport_type: string | null; exercise_days_per_week: number; goal: string; health_notes: string | null; daily_calorie_target: number; daily_protein_target_g: number; active_program_id: string | null }
export interface MealItemRow { name: string; grams: number; calories: number; protein_g: number; carbs_g: number; fat_g: number }
export interface MealRow { meal_type: string; logged_at: string; items: MealItemRow[] }
export interface SetRow { exercise_name: string; weight_kg: number | null; reps: number | null }
export interface SessionSummary { workout_name: string; finished_at: string; sets: SetRow[] }
export interface ProgramView { id: string; name: string; is_builtin: boolean; workouts: Array<{ name: string; exercises: Array<{ name: string; sets: number; reps_min: number; reps_max: number }> }> }
export interface InProgressSet { exercise_position: number; set_index: number; exercise_name: string; target_reps_min: number; target_reps_max: number; weight_kg: number | null; reps: number | null; completed: boolean }
export interface InProgressSession { id: string; workout_name: string; sets: InProgressSet[] }
export interface ContextData { today: string; profile: ProfileRow | null; todayMeals: MealRow[]; weights: Array<{ logged_on: string; weight_kg: number }>; recentSessions: SessionSummary[]; activeProgram: ProgramView | null; inProgress: InProgressSession | null; oneRepMaxes: Array<{ exercise_name: string; weight_kg: number }> }
```

- Produces (`context.ts`): `buildContextText(data: ContextData, utcOffsetMinutes: number): string`, `historyToLlmMessages(history: StoredMessage[]): LlmMessage[]`, `localDate(now: Date, utcOffsetMinutes: number): string` (`YYYY-MM-DD`)
- Produces (`prompts.ts`): `systemPrompt(locale: Locale, context: string): string`, `fallbackReply(locale: Locale): string`
- Produces (`test_fixtures.ts`): `sampleContext(): ContextData` (Task 7 ve 8 testleri de kullanır)

- [ ] **Step 1: Tipleri yaz**

`supabase/functions/coach-chat/types.ts` — yukarıdaki Interfaces bloğunun aynısı, başına:

```ts
// coach-chat'in ortak tipleri. Satır tipleri PostgREST'in döndürdüğü
// snake_case alan adlarını korur.
```

- [ ] **Step 2: Test verisini yaz**

`supabase/functions/coach-chat/test_fixtures.ts`:

```ts
import type { ContextData } from './types.ts';

/** Testlerde ortak bağlam: 2026-10-01, UTC+3. */
export function sampleContext(): ContextData {
  return {
    today: '2026-10-01',
    profile: {
      weight_kg: 80,
      height_cm: 180,
      birth_year: 1996,
      gender: 'male',
      activity_level: 'moderate',
      does_exercise: true,
      sport_type: 'fitness',
      exercise_days_per_week: 3,
      goal: 'gain_muscle',
      health_notes: null,
      daily_calorie_target: 2700.4,
      daily_protein_target_g: 176,
      active_program_id: 'prog-1',
    },
    todayMeals: [
      {
        meal_type: 'lunch',
        logged_at: '2026-10-01T09:30:00Z',
        items: [
          { name: 'Tavuk', grams: 200, calories: 330, protein_g: 62, carbs_g: 0, fat_g: 7.2 },
          { name: 'Pilav', grams: 150, calories: 195, protein_g: 4.1, carbs_g: 42, fat_g: 0.5 },
        ],
      },
    ],
    weights: [
      { logged_on: '2026-09-20', weight_kg: 80.5 },
      { logged_on: '2026-09-30', weight_kg: 80 },
    ],
    recentSessions: [
      {
        workout_name: 'A',
        finished_at: '2026-09-30T18:00:00Z',
        sets: [
          { exercise_name: 'Barbell Squat', weight_kg: 100, reps: 5 },
          { exercise_name: 'Barbell Squat', weight_kg: 105, reps: 3 },
          { exercise_name: 'Pullups', weight_kg: null, reps: 8 },
        ],
      },
    ],
    activeProgram: {
      id: 'prog-1',
      name: 'My 5x5',
      is_builtin: false,
      workouts: [
        {
          name: 'A',
          exercises: [
            { name: 'Barbell Squat', sets: 5, reps_min: 5, reps_max: 5 },
            { name: 'Barbell Bench Press - Medium Grip', sets: 3, reps_min: 8, reps_max: 12 },
          ],
        },
      ],
    },
    inProgress: {
      id: 'session-1',
      workout_name: 'A',
      sets: [
        { exercise_position: 0, set_index: 0, exercise_name: 'Barbell Squat', target_reps_min: 5, target_reps_max: 5, weight_kg: 100, reps: 5, completed: true },
        { exercise_position: 0, set_index: 1, exercise_name: 'Barbell Squat', target_reps_min: 5, target_reps_max: 5, weight_kg: null, reps: null, completed: false },
      ],
    },
    oneRepMaxes: [{ exercise_name: 'Barbell Squat', weight_kg: 120 }],
  };
}
```

- [ ] **Step 3: Bağlam ve geçmiş testlerini yaz**

`supabase/functions/coach-chat/context.test.ts`:

```ts
import { assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { buildContextText, historyToLlmMessages, localDate } from './context.ts';
import { fallbackReply, systemPrompt } from './prompts.ts';
import { sampleContext } from './test_fixtures.ts';
import type { StoredMessage } from './types.ts';

Deno.test('localDate uses the device offset', () => {
  assertEquals(localDate(new Date('2026-09-30T22:30:00Z'), 180), '2026-10-01');
  assertEquals(localDate(new Date('2026-09-30T22:30:00Z'), 0), '2026-09-30');
});

Deno.test('context lists profile, targets and today meals with local times and totals', () => {
  const text = buildContextText(sampleContext(), 180);
  assertStringIncludes(text, 'weight_kg: 80, height_cm: 180, birth_year: 1996, gender: male');
  assertStringIncludes(text, 'goal: gain_muscle, daily_calorie_target: 2700 kcal, daily_protein_target_g: 176');
  assertStringIncludes(text, "## Today's meals (2026-10-01)");
  assertStringIncludes(text, '- lunch 12:30: Tavuk 200 g, Pilav 150 g (525 kcal)');
  assertStringIncludes(text, 'totals: 525 kcal, protein 66.1 g, carbs 42 g, fat 7.7 g');
});

Deno.test('context shows weights, best set per exercise and the 1RMs', () => {
  const text = buildContextText(sampleContext(), 180);
  assertStringIncludes(text, '2026-09-20: 80.5, 2026-09-30: 80');
  assertStringIncludes(text, '- 2026-09-30 A: Barbell Squat 105x3, Pullups bodyweightx8');
  assertStringIncludes(text, 'Barbell Squat: 120 kg');
});

Deno.test('context marks the active program as editable and lists the in-progress sets', () => {
  const text = buildContextText(sampleContext(), 180);
  assertStringIncludes(text, '## Active program: My 5x5 (own, editable)');
  assertStringIncludes(text, '- A: Barbell Squat 5x5, Barbell Bench Press - Medium Grip 3x8-12');
  assertStringIncludes(text, '## In-progress workout: A');
  assertStringIncludes(text, '- Barbell Squat set 1: target 5, done 100 kg x 5');
  assertStringIncludes(text, '- Barbell Squat set 2: target 5, not done');
});

Deno.test('context handles missing data', () => {
  const data = { ...sampleContext(), todayMeals: [], weights: [], recentSessions: [], oneRepMaxes: [], inProgress: null };
  data.activeProgram = { ...data.activeProgram!, is_builtin: true };
  const text = buildContextText(data, 0);
  assertStringIncludes(text, 'none logged');
  assertStringIncludes(text, '(built-in, read-only)');
  assertStringIncludes(text, '## In-progress workout: none');
  assertEquals(buildContextText({ ...data, activeProgram: null }, 0).includes('## Active program: none'), true);
});

Deno.test('history keeps roles and annotates proposal cards with their status', () => {
  const history: StoredMessage[] = [
    { id: '1', role: 'user', content: 'kilom 82', created_at: 't1', event: null },
    {
      id: '2', role: 'assistant', content: 'Kaydedeyim mi?', created_at: 't2',
      event: { id: 'e', tool: 'log_body_weight', status: 'cancelled', summary: 'Kilo kaydı: 82 kg (2026-10-01)', payload: {}, base: {} },
    },
  ];
  assertEquals(historyToLlmMessages(history), [
    { role: 'user', text: 'kilom 82' },
    { role: 'assistant', text: 'Kaydedeyim mi?\nKilo kaydı: 82 kg (2026-10-01) [user declined the change]' },
  ]);
});

Deno.test('system prompt sets the reply language and embeds the context', () => {
  assertStringIncludes(systemPrompt('tr', 'CTX'), 'Always reply in Turkish.');
  assertStringIncludes(systemPrompt('en', 'CTX'), 'Always reply in English.');
  assertStringIncludes(systemPrompt('tr', 'CTX'), '# User data\nCTX');
  assertEquals(fallbackReply('tr'), 'Bunu tam anlayamadım, biraz daha açık yazar mısın?');
  assertEquals(fallbackReply('en'), "I couldn't quite understand that. Could you say it a bit more clearly?");
});
```

- [ ] **Step 4: Testlerin başarısız olduğunu gör**

Run: `deno test supabase/functions/coach-chat/context.test.ts`
Expected: FAIL — `Module not found ".../context.ts"`.

- [ ] **Step 5: `context.ts`'i yaz**

```ts
import type { LlmMessage } from './llm/types.ts';
import type { ContextData, EventStatus, SetRow, StoredMessage } from './types.ts';

const MINUTE_MS = 60_000;

/** Cihazın yerel günü (YYYY-MM-DD). */
export function localDate(now: Date, utcOffsetMinutes: number): string {
  return new Date(now.getTime() + utcOffsetMinutes * MINUTE_MS).toISOString().slice(0, 10);
}

function localTime(iso: string, utcOffsetMinutes: number): string {
  return new Date(new Date(iso).getTime() + utcOffsetMinutes * MINUTE_MS).toISOString().slice(11, 16);
}

function fmt(value: number): string {
  return String(Math.round(value * 10) / 10);
}

function repsLabel(min: number, max: number): string {
  return min === max ? `${min}` : `${min}-${max}`;
}

function kgLabel(kg: number | null): string {
  return kg === null ? 'bodyweight' : fmt(kg);
}

/** Hareket başına en ağır (eşitse en çok tekrarlı) set; ilk görülme sırasıyla. */
function bestSets(sets: SetRow[]): string {
  const best = new Map<string, SetRow>();
  for (const set of sets) {
    const current = best.get(set.exercise_name);
    const kg = set.weight_kg ?? 0;
    const currentKg = current?.weight_kg ?? 0;
    if (!current || kg > currentKg || (kg === currentKg && (set.reps ?? 0) > (current.reps ?? 0))) {
      best.set(set.exercise_name, set);
    }
  }
  return [...best.values()].map((s) => `${s.exercise_name} ${kgLabel(s.weight_kg)}x${s.reps ?? 0}`).join(', ');
}

/** LLM'e giden veri özeti (etiketler İngilizce; cevap dili sistem talimatında). */
export function buildContextText(data: ContextData, utcOffsetMinutes: number): string {
  const lines: string[] = ['## Profile'];
  const p = data.profile;
  if (p) {
    lines.push(`weight_kg: ${fmt(p.weight_kg)}, height_cm: ${fmt(p.height_cm)}, birth_year: ${p.birth_year}, gender: ${p.gender}`);
    lines.push(
      `activity_level: ${p.activity_level}, does_exercise: ${p.does_exercise}, sport_type: ${p.sport_type ?? '-'}, ` +
        `exercise_days_per_week: ${p.exercise_days_per_week}`,
    );
    lines.push(
      `goal: ${p.goal}, daily_calorie_target: ${Math.round(p.daily_calorie_target)} kcal, ` +
        `daily_protein_target_g: ${Math.round(p.daily_protein_target_g)}`,
    );
    if (p.health_notes) lines.push(`health_notes: ${p.health_notes}`);
  } else {
    lines.push('none');
  }

  lines.push('', `## Today's meals (${data.today})`);
  if (data.todayMeals.length === 0) {
    lines.push('none logged');
  } else {
    let kcal = 0, protein = 0, carbs = 0, fat = 0;
    for (const meal of data.todayMeals) {
      const items = meal.items.map((i) => `${i.name} ${fmt(i.grams)} g`).join(', ');
      const mealKcal = meal.items.reduce((sum, i) => sum + i.calories, 0);
      lines.push(`- ${meal.meal_type} ${localTime(meal.logged_at, utcOffsetMinutes)}: ${items} (${Math.round(mealKcal)} kcal)`);
      for (const i of meal.items) {
        kcal += i.calories;
        protein += i.protein_g;
        carbs += i.carbs_g;
        fat += i.fat_g;
      }
    }
    lines.push(`totals: ${Math.round(kcal)} kcal, protein ${fmt(protein)} g, carbs ${fmt(carbs)} g, fat ${fmt(fat)} g`);
  }

  lines.push('', '## Body weight (last 30 days)');
  lines.push(data.weights.length === 0 ? 'none' : data.weights.map((w) => `${w.logged_on}: ${fmt(w.weight_kg)}`).join(', '));

  lines.push('', '## Recent workouts');
  if (data.recentSessions.length === 0) lines.push('none');
  for (const session of data.recentSessions) {
    lines.push(`- ${localDate(new Date(session.finished_at), utcOffsetMinutes)} ${session.workout_name}: ${bestSets(session.sets)}`);
  }

  lines.push('');
  const program = data.activeProgram;
  if (!program) {
    lines.push('## Active program: none');
  } else {
    lines.push(`## Active program: ${program.name} (${program.is_builtin ? 'built-in, read-only' : 'own, editable'})`);
    for (const workout of program.workouts) {
      const exercises = workout.exercises.map((e) => `${e.name} ${e.sets}x${repsLabel(e.reps_min, e.reps_max)}`);
      lines.push(`- ${workout.name}: ${exercises.join(', ')}`);
    }
  }

  lines.push('');
  const live = data.inProgress;
  if (!live) {
    lines.push('## In-progress workout: none');
  } else {
    lines.push(`## In-progress workout: ${live.workout_name}`);
    for (const set of live.sets) {
      const state = set.completed
        ? `done ${set.weight_kg === null ? 'bodyweight' : `${fmt(set.weight_kg)} kg`} x ${set.reps ?? 0}`
        : 'not done';
      lines.push(`- ${set.exercise_name} set ${set.set_index + 1}: target ${repsLabel(set.target_reps_min, set.target_reps_max)}, ${state}`);
    }
  }

  lines.push('', '## 1RM');
  lines.push(
    data.oneRepMaxes.length === 0 ? 'none' : data.oneRepMaxes.map((o) => `${o.exercise_name}: ${fmt(o.weight_kg)} kg`).join(', '),
  );
  return lines.join('\n');
}

const STATUS_NOTES: Record<EventStatus, string> = {
  pending: '[proposed change awaiting user confirmation]',
  applied: '[user confirmed; change applied]',
  cancelled: '[user declined the change]',
  undone: '[change was applied, then the user undid it]',
  stale: '[not applied: data changed before confirmation]',
};

/** Kayıtlı geçmiş → LLM mesajları; öneri kartlarının durumu metne eklenir. */
export function historyToLlmMessages(history: StoredMessage[]): LlmMessage[] {
  return history.map((message): LlmMessage => {
    if (message.role === 'user') return { role: 'user', text: message.content };
    const note = message.event ? `\n${message.event.summary} ${STATUS_NOTES[message.event.status]}` : '';
    return { role: 'assistant', text: `${message.content}${note}` };
  });
}
```

- [ ] **Step 6: `prompts.ts`'i yaz**

```ts
import type { Locale } from './types.ts';

export function systemPrompt(locale: Locale, context: string): string {
  const language = locale === 'en' ? 'English' : 'Turkish';
  return [
    "You are the AI coach inside a fitness and nutrition tracking app. You know the user's data below " +
      'and give practical, encouraging and concise advice about training and nutrition.',
    `Always reply in ${language}.`,
    'Rules:',
    "- You can change the user's data ONLY by calling one of the provided tools. Never claim that a change " +
      'was made: every tool call is shown to the user as a confirmation card and applied only after they confirm.',
    '- Call at most one tool per reply. If the user asks for several changes, propose the first one and say ' +
      'you will do the next one after it is confirmed.',
    '- Never calculate calories or macros yourself. To log food use create_meal with food names, grams and an ' +
      'English USDA search query that says whether the food is raw or cooked.',
    '- Body weight changes only through log_body_weight. The goal (lose_weight / gain_muscle / maintain) ' +
      'changes only through set_goal.',
    "- edit_program edits only the active program and only if it is the user's own program. If it is built-in, " +
      'tell the user to copy it in the Workout tab first. Use English exercise names.',
    '- log_set works only on the in-progress workout listed below.',
    '- If a tool returns an error, fix the arguments (for example pick one of the candidate names) or ask the user.',
    '- You are not a doctor: do not diagnose; for pain, injuries or medical conditions recommend a professional.',
    "- Dates are YYYY-MM-DD in the user's local time.",
    '',
    '# User data',
    context,
  ].join('\n');
}

/** 3 LLM çağrısında geçerli bir araç çağrısı çıkmazsa dönen sabit cevap. */
export function fallbackReply(locale: Locale): string {
  return locale === 'en'
    ? "I couldn't quite understand that. Could you say it a bit more clearly?"
    : 'Bunu tam anlayamadım, biraz daha açık yazar mısın?';
}
```

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `deno test supabase/functions/coach-chat/context.test.ts`
Expected: PASS — 7 test.

- [ ] **Step 8: Commit**

```bash
git add supabase/functions/coach-chat/types.ts supabase/functions/coach-chat/context.ts supabase/functions/coach-chat/prompts.ts supabase/functions/coach-chat/test_fixtures.ts supabase/functions/coach-chat/context.test.ts
git commit -m "feat(coach): add context summary, history mapping and system prompt"
```

---

### Task 6: Program işlemleri (saf fonksiyonlar)

**Files:**
- Create: `supabase/functions/coach-chat/program_ops.ts`
- Test: `supabase/functions/coach-chat/program_ops.test.ts`

**Interfaces:**
- Produces:

```ts
export interface ProgramExercise { exercise_id: string; sets: number; reps_min: number; reps_max: number; is_amrap?: boolean; percent_1rm?: number | null; percent_ref_exercise_id?: string | null; rest_seconds?: number | null; notes?: string | null }
export interface ProgramWorkout { name: string; weekday: number | null; exercises: ProgramExercise[] }
export interface ProgramSnapshot { id: string; name: string; description: string | null; level: string | null; schedule_mode: string; days_per_week: number | null; source_program_id: string | null; workouts: ProgramWorkout[] }
export type ProgramOperation =
  | { op: 'add_exercise'; workout_name: string; exercise_id: string; exercise_name: string; sets: number; reps_min: number; reps_max: number }
  | { op: 'remove_exercise'; workout_name: string; exercise_name: string }
  | { op: 'modify_exercise'; workout_name: string; exercise_name: string; sets?: number; reps_min?: number; reps_max?: number }
  | { op: 'rename_workout'; workout_name: string; new_name: string };
export interface ProgramChange { kind: 'add' | 'remove' | 'modify' | 'rename'; label: string }
export class ProgramOpError extends Error { readonly candidates: string[] }
export function applyProgramOperations(program: ProgramSnapshot, ops: ProgramOperation[], names: Record<string, string>): { program: ProgramSnapshot; changes: ProgramChange[] }
```

`names`: exercise_id → İngilizce ad (programdaki hareketler için). Girdi değiştirilmez (kopya üzerinde çalışılır). Antrenman ve hareket adları büyük/küçük harf ve baştaki/sondaki boşluk gözetmeden eşleşir.

- [ ] **Step 1: Testleri yaz**

`supabase/functions/coach-chat/program_ops.test.ts`:

```ts
import { assertEquals, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { applyProgramOperations, ProgramOpError } from './program_ops.ts';
import type { ProgramSnapshot } from './program_ops.ts';

function program(): ProgramSnapshot {
  return {
    id: 'prog-1', name: 'My 5x5', description: null, level: null, schedule_mode: 'rotation',
    days_per_week: 3, source_program_id: null,
    workouts: [
      {
        name: 'A', weekday: null,
        exercises: [
          { exercise_id: 'squat', sets: 5, reps_min: 5, reps_max: 5, is_amrap: false, percent_1rm: null, percent_ref_exercise_id: null, rest_seconds: 180, notes: null },
          { exercise_id: 'bench', sets: 3, reps_min: 8, reps_max: 12, is_amrap: false, percent_1rm: null, percent_ref_exercise_id: null, rest_seconds: null, notes: null },
        ],
      },
      { name: 'B', weekday: null, exercises: [] },
    ],
  };
}

const names = { squat: 'Barbell Squat', bench: 'Barbell Bench Press' };

Deno.test('adds an exercise at the end of the workout', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'add_exercise', workout_name: 'b', exercise_id: 'dl', exercise_name: 'Barbell Deadlift', sets: 1, reps_min: 5, reps_max: 5 },
  ], names);
  assertEquals(result.workouts[1].exercises, [{ exercise_id: 'dl', sets: 1, reps_min: 5, reps_max: 5 }]);
  assertEquals(changes, [{ kind: 'add', label: '+ B: Barbell Deadlift 1×5' }]);
});

Deno.test('removes an exercise by name', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'remove_exercise', workout_name: 'A', exercise_name: ' barbell bench press ' },
  ], names);
  assertEquals(result.workouts[0].exercises.map((e) => e.exercise_id), ['squat']);
  assertEquals(changes, [{ kind: 'remove', label: '− A: Barbell Bench Press' }]);
});

Deno.test('modifies sets and reps and keeps other fields', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', sets: 3, reps_max: 8 },
  ], names);
  assertEquals(result.workouts[0].exercises[0], {
    exercise_id: 'squat', sets: 3, reps_min: 5, reps_max: 8, is_amrap: false, percent_1rm: null,
    percent_ref_exercise_id: null, rest_seconds: 180, notes: null,
  });
  assertEquals(changes, [{ kind: 'modify', label: '~ A: Barbell Squat 5×5 → 3×5–8' }]);
});

Deno.test('renames a workout', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'rename_workout', workout_name: 'A', new_name: 'Push' },
  ], names);
  assertEquals(result.workouts[0].name, 'Push');
  assertEquals(changes, [{ kind: 'rename', label: '✎ A → Push' }]);
});

Deno.test('does not mutate the input program', () => {
  const input = program();
  applyProgramOperations(input, [{ op: 'remove_exercise', workout_name: 'A', exercise_name: 'Barbell Squat' }], names);
  assertEquals(input.workouts[0].exercises.length, 2);
});

Deno.test('unknown workout lists the workout names as candidates', () => {
  const error = assertThrows(
    () => applyProgramOperations(program(), [{ op: 'rename_workout', workout_name: 'C', new_name: 'x' }], names),
    ProgramOpError,
  );
  assertEquals(error.candidates, ['A', 'B']);
});

Deno.test('unknown exercise lists the workout exercises as candidates', () => {
  const error = assertThrows(
    () => applyProgramOperations(program(), [{ op: 'remove_exercise', workout_name: 'A', exercise_name: 'Deadlift' }], names),
    ProgramOpError,
  );
  assertEquals(error.candidates, ['Barbell Squat', 'Barbell Bench Press']);
});

Deno.test('rejects reps_max below reps_min', () => {
  assertThrows(
    () => applyProgramOperations(program(), [{ op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', reps_max: 3 }], names),
    ProgramOpError,
    'reps_max',
  );
});

Deno.test('rejects out-of-range sets', () => {
  assertThrows(
    () => applyProgramOperations(program(), [{ op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', sets: 11 }], names),
    ProgramOpError,
    'sets',
  );
});
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `deno test supabase/functions/coach-chat/program_ops.test.ts`
Expected: FAIL — `Module not found ".../program_ops.ts"`.

- [ ] **Step 3: `program_ops.ts`'i yaz**

```ts
// edit_program aracının program üzerindeki işlemleri (saf fonksiyonlar).

export interface ProgramExercise {
  exercise_id: string;
  sets: number;
  reps_min: number;
  reps_max: number;
  is_amrap?: boolean;
  percent_1rm?: number | null;
  percent_ref_exercise_id?: string | null;
  rest_seconds?: number | null;
  notes?: string | null;
}

export interface ProgramWorkout {
  name: string;
  weekday: number | null;
  exercises: ProgramExercise[];
}

/** `program_snapshot` / `save_program` formatı. */
export interface ProgramSnapshot {
  id: string;
  name: string;
  description: string | null;
  level: string | null;
  schedule_mode: string;
  days_per_week: number | null;
  source_program_id: string | null;
  workouts: ProgramWorkout[];
}

export type ProgramOperation =
  | { op: 'add_exercise'; workout_name: string; exercise_id: string; exercise_name: string; sets: number; reps_min: number; reps_max: number }
  | { op: 'remove_exercise'; workout_name: string; exercise_name: string }
  | { op: 'modify_exercise'; workout_name: string; exercise_name: string; sets?: number; reps_min?: number; reps_max?: number }
  | { op: 'rename_workout'; workout_name: string; new_name: string };

export interface ProgramChange {
  kind: 'add' | 'remove' | 'modify' | 'rename';
  label: string;
}

export class ProgramOpError extends Error {
  constructor(message: string, readonly candidates: string[] = []) {
    super(message);
  }
}

function same(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase();
}

function scheme(sets: number, min: number, max: number): string {
  return `${sets}×${min === max ? min : `${min}–${max}`}`;
}

function validate(sets: number, min: number, max: number): void {
  if (!Number.isInteger(sets) || sets < 1 || sets > 10) throw new ProgramOpError('sets must be an integer 1-10');
  if (!Number.isInteger(min) || min < 1 || min > 100) throw new ProgramOpError('reps_min must be an integer 1-100');
  if (!Number.isInteger(max) || max < min || max > 100) throw new ProgramOpError('reps_max must be an integer between reps_min and 100');
}

export function applyProgramOperations(
  input: ProgramSnapshot,
  ops: ProgramOperation[],
  names: Record<string, string>,
): { program: ProgramSnapshot; changes: ProgramChange[] } {
  const program: ProgramSnapshot = structuredClone(input);
  const nameMap: Record<string, string> = { ...names };
  const changes: ProgramChange[] = [];

  const findWorkout = (name: string): ProgramWorkout => {
    const workout = program.workouts.find((w) => same(w.name, name));
    if (!workout) {
      throw new ProgramOpError(`workout "${name}" not found`, program.workouts.map((w) => w.name));
    }
    return workout;
  };
  const nameOf = (exercise: ProgramExercise) => nameMap[exercise.exercise_id] ?? exercise.exercise_id;
  const findExerciseIndex = (workout: ProgramWorkout, name: string): number => {
    const index = workout.exercises.findIndex((e) => same(nameOf(e), name));
    if (index < 0) {
      throw new ProgramOpError(`exercise "${name}" not found in workout "${workout.name}"`, workout.exercises.map(nameOf));
    }
    return index;
  };

  for (const op of ops) {
    const workout = findWorkout(op.workout_name);
    switch (op.op) {
      case 'add_exercise': {
        validate(op.sets, op.reps_min, op.reps_max);
        workout.exercises.push({ exercise_id: op.exercise_id, sets: op.sets, reps_min: op.reps_min, reps_max: op.reps_max });
        nameMap[op.exercise_id] = op.exercise_name;
        changes.push({ kind: 'add', label: `+ ${workout.name}: ${op.exercise_name} ${scheme(op.sets, op.reps_min, op.reps_max)}` });
        break;
      }
      case 'remove_exercise': {
        const [removed] = workout.exercises.splice(findExerciseIndex(workout, op.exercise_name), 1);
        changes.push({ kind: 'remove', label: `− ${workout.name}: ${nameOf(removed)}` });
        break;
      }
      case 'modify_exercise': {
        const exercise = workout.exercises[findExerciseIndex(workout, op.exercise_name)];
        const before = scheme(exercise.sets, exercise.reps_min, exercise.reps_max);
        const sets = op.sets ?? exercise.sets;
        const min = op.reps_min ?? exercise.reps_min;
        const max = op.reps_max ?? exercise.reps_max;
        validate(sets, min, max);
        exercise.sets = sets;
        exercise.reps_min = min;
        exercise.reps_max = max;
        changes.push({ kind: 'modify', label: `~ ${workout.name}: ${nameOf(exercise)} ${before} → ${scheme(sets, min, max)}` });
        break;
      }
      case 'rename_workout': {
        const newName = op.new_name.trim();
        if (newName.length === 0 || newName.length > 50) throw new ProgramOpError('new_name must be 1-50 characters');
        changes.push({ kind: 'rename', label: `✎ ${workout.name} → ${newName}` });
        workout.name = newName;
        break;
      }
    }
  }
  return { program, changes };
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `deno test supabase/functions/coach-chat/program_ops.test.ts`
Expected: PASS — 9 test.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/coach-chat/program_ops.ts supabase/functions/coach-chat/program_ops.test.ts
git commit -m "feat(coach): add pure program edit operations"
```

---
### Task 7: Araç tanımları, doğrulama ve hazırlama

**Files:**
- Create: `supabase/functions/coach-chat/tools.ts`
- Test: `supabase/functions/coach-chat/tools.test.ts`

**Interfaces:**
- Consumes: `ContextData`, `Locale`, `ToolName`, `TOOL_NAMES` (Task 5); `localDate` (Task 5); `applyProgramOperations`, `ProgramOpError`, `ProgramSnapshot`, `ProgramOperation` (Task 6); `ToolDefinition` (Task 4); `UsdaFood`, `Macros` (Task 3).
- Produces:

```ts
export interface ToolDeps {
  findExercises(query: string): Promise<Array<{ id: string; name: string }>>;
  exerciseNames(ids: string[]): Promise<Record<string, string>>;
  programSnapshot(programId: string): Promise<ProgramSnapshot | null>;
  findBestMatch(query: string): Promise<UsdaFood | null>;
  fetchMacrosPer100g(fdcId: number): Promise<Macros>;
  newId(): string;
}
export interface ToolContext { data: ContextData; now: Date; utcOffsetMinutes: number; locale: Locale }
export type PreparedTool =
  | { ok: true; tool: ToolName; summary: string; payload: Record<string, unknown> }
  | { ok: false; error: string; candidates?: string[] };
export const TOOL_DEFINITIONS: ToolDefinition[];   // TOOL_NAMES sırasıyla
export function prepareToolCall(name: string, args: Record<string, unknown>, ctx: ToolContext, deps: ToolDeps): Promise<PreparedTool>;
```

Payload'lar spec §3.2'deki gibidir; ek olarak `log_set` payload'ı kart için `exercise_name` ve `set_number` taşır (SQL bunları yok sayar).

- [ ] **Step 1: Testleri yaz**

`supabase/functions/coach-chat/tools.test.ts`:

```ts
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import type { ProgramSnapshot } from './program_ops.ts';
import { sampleContext } from './test_fixtures.ts';
import { prepareToolCall, TOOL_DEFINITIONS } from './tools.ts';
import type { ToolContext, ToolDeps } from './tools.ts';
import { TOOL_NAMES } from './types.ts';

const EXERCISES = [
  { id: 'squat', name: 'Barbell Squat' },
  { id: 'bench', name: 'Barbell Bench Press - Medium Grip' },
  { id: 'dl', name: 'Barbell Deadlift' },
  { id: 'rdl', name: 'Romanian Deadlift' },
];

function snapshot(): ProgramSnapshot {
  return {
    id: 'prog-1', name: 'My 5x5', description: null, level: null, schedule_mode: 'rotation',
    days_per_week: 3, source_program_id: null,
    workouts: [{
      name: 'A', weekday: null,
      exercises: [
        { exercise_id: 'squat', sets: 5, reps_min: 5, reps_max: 5 },
        { exercise_id: 'bench', sets: 3, reps_min: 8, reps_max: 12 },
      ],
    }],
  };
}

function deps(overrides: Partial<ToolDeps> = {}): ToolDeps {
  return {
    findExercises: async (q) => EXERCISES.filter((e) => e.name.toLowerCase().includes(q.toLowerCase())),
    exerciseNames: async (ids) => Object.fromEntries(EXERCISES.filter((e) => ids.includes(e.id)).map((e) => [e.id, e.name])),
    programSnapshot: async () => snapshot(),
    findBestMatch: async (q) => (q.includes('chicken') ? { fdcId: 171077, description: 'Chicken breast', dataType: 'Foundation' } : null),
    fetchMacrosPer100g: async () => ({ calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6 }),
    newId: () => 'meal-uuid',
    ...overrides,
  };
}

// 2026-09-30 22:30 UTC = 2026-10-01 01:30, UTC+3
function ctx(overrides: Partial<ToolContext> = {}): ToolContext {
  return { data: sampleContext(), now: new Date('2026-09-30T22:30:00Z'), utcOffsetMinutes: 180, locale: 'tr', ...overrides };
}

Deno.test('tool definitions follow TOOL_NAMES', () => {
  assertEquals(TOOL_DEFINITIONS.map((t) => t.name), [...TOOL_NAMES]);
});

Deno.test('unknown tool is rejected', async () => {
  assertEquals(await prepareToolCall('delete_everything', {}, ctx(), deps()), { ok: false, error: 'unknown tool delete_everything' });
});

Deno.test('log_body_weight defaults to the local day and rounds to 0.1', async () => {
  assertEquals(await prepareToolCall('log_body_weight', { weight_kg: 82.04 }, ctx(), deps()), {
    ok: true, tool: 'log_body_weight', summary: 'Kilo kaydı: 82 kg (2026-10-01)', payload: { date: '2026-10-01', kg: 82 },
  });
});

Deno.test('log_body_weight validates range and date', async () => {
  const future = await prepareToolCall('log_body_weight', { weight_kg: 80, date: '2026-10-02' }, ctx(), deps());
  assertEquals(future, { ok: false, error: 'date cannot be in the future' });
  const invalid = await prepareToolCall('log_body_weight', { weight_kg: 80, date: '2026-02-30' }, ctx(), deps());
  assertEquals(invalid, { ok: false, error: 'date must be a valid YYYY-MM-DD' });
  const heavy = await prepareToolCall('log_body_weight', { weight_kg: 900 }, ctx(), deps());
  assertEquals(heavy, { ok: false, error: 'weight_kg must be between 20 and 400' });
});

Deno.test('update_profile collects changes and lists them in the summary', async () => {
  const result = await prepareToolCall('update_profile', { height_cm: 185, activity_level: 'active', sport_type: '' }, ctx(), deps());
  assertEquals(result, {
    ok: true, tool: 'update_profile', summary: 'Profil güncelleme: boy, aktivite, spor türü',
    payload: { changes: { height_cm: 185, activity_level: 'active', sport_type: null } },
  });
});

Deno.test('update_profile rejects weight and empty changes', async () => {
  const weight = await prepareToolCall('update_profile', { weight_kg: 80 }, ctx(), deps());
  assertEquals(weight.ok, false);
  assertEquals(await prepareToolCall('update_profile', {}, ctx(), deps()), { ok: false, error: 'at least one field is required' });
  const days = await prepareToolCall('update_profile', { exercise_days_per_week: 2.5 }, ctx(), deps());
  assertEquals(days, { ok: false, error: 'exercise_days_per_week must be an integer' });
});

Deno.test('set_goal rejects the current goal and summarizes in the locale', async () => {
  assertEquals(await prepareToolCall('set_goal', { goal: 'gain_muscle' }, ctx(), deps()), { ok: false, error: 'goal is already gain_muscle' });
  assertEquals(await prepareToolCall('set_goal', { goal: 'lose_weight' }, ctx({ locale: 'en' }), deps()), {
    ok: true, tool: 'set_goal', summary: 'Change goal: Lose weight', payload: { goal: 'lose_weight' },
  });
});

Deno.test('create_meal looks up USDA per-100 g macros and marks misses for review', async () => {
  const result = await prepareToolCall('create_meal', {
    meal_type: 'lunch',
    time: '12:30',
    items: [
      { name: 'Tavuk', grams: 200, usda_query: 'grilled chicken breast' },
      { name: 'Ayran', grams: 200.4, usda_query: 'ayran' },
    ],
  }, ctx(), deps());
  assertEquals(result, {
    ok: true,
    tool: 'create_meal',
    summary: 'Öğün: Öğle — Tavuk (200 g), Ayran (200 g)',
    payload: {
      meal_id: 'meal-uuid',
      meal_type: 'lunch',
      logged_at: '2026-10-01T09:30:00.000Z',
      items: [
        { name: 'Tavuk', grams: 200, per100: { calories: 165, protein_g: 31, carbs_g: 0, fat_g: 3.6 }, usda_fdc_id: '171077', needs_review: false },
        { name: 'Ayran', grams: 200, per100: { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }, usda_fdc_id: null, needs_review: true },
      ],
    },
  });
});

Deno.test('create_meal defaults to now and survives a USDA failure', async () => {
  const result = await prepareToolCall('create_meal', {
    meal_type: 'snack', items: [{ name: 'Tavuk', grams: 100, usda_query: 'chicken' }],
  }, ctx(), deps({ findBestMatch: () => Promise.reject(new Error('USDA down')) }));
  assertEquals(result.ok && result.payload.logged_at, '2026-09-30T22:30:00.000Z');
  assertEquals(result.ok && (result.payload.items as Array<{ needs_review: boolean }>)[0].needs_review, true);
});

Deno.test('create_meal validates items and time', async () => {
  assertEquals(await prepareToolCall('create_meal', { meal_type: 'lunch', items: [] }, ctx(), deps()), { ok: false, error: 'items must have 1-15 entries' });
  const badTime = await prepareToolCall('create_meal', { meal_type: 'lunch', time: '25:00', items: [{ name: 'x', grams: 1, usda_query: 'x' }] }, ctx(), deps());
  assertEquals(badTime, { ok: false, error: 'time must be HH:MM' });
});

Deno.test('log_set maps the 1-based set number to the in-progress set', async () => {
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'barbell squat', set_number: 2, weight_kg: 100, reps: 5 }, ctx(), deps()), {
    ok: true, tool: 'log_set', summary: 'Set kaydı: Barbell Squat 2. set — 100 kg × 5',
    payload: { session_id: 'session-1', exercise_position: 0, set_index: 1, weight_kg: 100, reps: 5, exercise_name: 'Barbell Squat', set_number: 2 },
  });
});

Deno.test('log_set errors list candidates or explain the problem', async () => {
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'Deadlift', set_number: 1, weight_kg: 100, reps: 5 }, ctx(), deps()), {
    ok: false, error: 'exercise "Deadlift" is not in the in-progress workout', candidates: ['Barbell Squat'],
  });
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'Barbell Squat', set_number: 3, weight_kg: 100, reps: 5 }, ctx(), deps()), {
    ok: false, error: 'Barbell Squat has no set 3 (it has 2 sets)',
  });
  const idle = ctx({ data: { ...sampleContext(), inProgress: null } });
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'Barbell Squat', set_number: 1, weight_kg: 100, reps: 5 }, idle, deps()), {
    ok: false, error: 'there is no workout in progress',
  });
});

Deno.test('edit_program resolves exercise names and returns the full new program', async () => {
  const result = await prepareToolCall('edit_program', {
    operations: [
      { op: 'add_exercise', workout_name: 'A', exercise_name: 'Barbell Deadlift', sets: 1, reps_min: 5 },
      { op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', sets: 3 },
    ],
  }, ctx(), deps());
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.summary, 'Program düzenleme: My 5x5 (2 değişiklik)');
  assertEquals(result.payload.program_id, 'prog-1');
  const program = result.payload.program as ProgramSnapshot;
  assertEquals(program.workouts[0].exercises.map((e) => [e.exercise_id, e.sets, e.reps_min, e.reps_max]), [
    ['squat', 3, 5, 5], ['bench', 3, 8, 12], ['dl', 1, 5, 5],
  ]);
  assertEquals(result.payload.changes, [
    { kind: 'add', label: '+ A: Barbell Deadlift 1×5' },
    { kind: 'modify', label: '~ A: Barbell Squat 5×5 → 3×5' },
  ]);
});

Deno.test('edit_program defaults new exercises to 3x8-12', async () => {
  const result = await prepareToolCall('edit_program', {
    operations: [{ op: 'add_exercise', workout_name: 'A', exercise_name: 'Romanian Deadlift' }],
  }, ctx(), deps());
  assertEquals(result.ok && result.payload.changes, [{ kind: 'add', label: '+ A: Romanian Deadlift 3×8–12' }]);
});

Deno.test('edit_program returns candidates for ambiguous names and rejects built-in programs', async () => {
  assertEquals(await prepareToolCall('edit_program', {
    operations: [{ op: 'add_exercise', workout_name: 'A', exercise_name: 'deadlift' }],
  }, ctx(), deps()), {
    ok: false, error: '"deadlift" matches several exercises; pick one', candidates: ['Barbell Deadlift', 'Romanian Deadlift'],
  });
  const data = sampleContext();
  data.activeProgram = { ...data.activeProgram!, is_builtin: true };
  const builtIn = await prepareToolCall('edit_program', { operations: [{ op: 'rename_workout', workout_name: 'A', new_name: 'B' }] }, ctx({ data }), deps());
  assertEquals(builtIn.ok, false);
});

Deno.test('edit_program passes program operation errors back with candidates', async () => {
  assertEquals(await prepareToolCall('edit_program', {
    operations: [{ op: 'remove_exercise', workout_name: 'A', exercise_name: 'Pullups' }],
  }, ctx(), deps()), {
    ok: false,
    error: 'exercise "Pullups" not found in workout "A"',
    candidates: ['Barbell Squat', 'Barbell Bench Press - Medium Grip'],
  });
});
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `deno test supabase/functions/coach-chat/tools.test.ts`
Expected: FAIL — `Module not found ".../tools.ts"`.

- [ ] **Step 3: `tools.ts`'i yaz**

```ts
import type { Macros, UsdaFood } from '../_shared/usda_client.ts';
import { localDate } from './context.ts';
import type { ToolDefinition } from './llm/types.ts';
import { applyProgramOperations, ProgramOpError } from './program_ops.ts';
import type { ProgramOperation, ProgramSnapshot } from './program_ops.ts';
import type { ContextData, Locale, ToolName } from './types.ts';

export interface ToolDeps {
  findExercises(query: string): Promise<Array<{ id: string; name: string }>>;
  exerciseNames(ids: string[]): Promise<Record<string, string>>;
  programSnapshot(programId: string): Promise<ProgramSnapshot | null>;
  findBestMatch(query: string): Promise<UsdaFood | null>;
  fetchMacrosPer100g(fdcId: number): Promise<Macros>;
  newId(): string;
}

export interface ToolContext {
  data: ContextData;
  now: Date;
  utcOffsetMinutes: number;
  locale: Locale;
}

export type PreparedTool =
  | { ok: true; tool: ToolName; summary: string; payload: Record<string, unknown> }
  | { ok: false; error: string; candidates?: string[] };

type Args = Record<string, unknown>;

const GOALS = ['lose_weight', 'gain_muscle', 'maintain'] as const;
const ACTIVITY_LEVELS = ['sedentary', 'light', 'moderate', 'active', 'very_active'] as const;
const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'] as const;
const PROGRAM_OPS = ['add_exercise', 'remove_exercise', 'modify_exercise', 'rename_workout'] as const;
const PROFILE_FIELDS = ['height_cm', 'activity_level', 'does_exercise', 'sport_type', 'exercise_days_per_week', 'health_notes'];

export const TOOL_DEFINITIONS: ToolDefinition[] = [
  {
    name: 'log_body_weight',
    description: "Log the user's body weight for a day (default today). If it is the newest entry it also " +
      'updates the profile weight and the calorie/protein targets.',
    parameters: {
      type: 'object',
      properties: {
        weight_kg: { type: 'number', description: 'Body weight in kg (20-400).' },
        date: { type: 'string', description: 'Local date YYYY-MM-DD; omit for today. Cannot be in the future.' },
      },
      required: ['weight_kg'],
    },
  },
  {
    name: 'update_profile',
    description: 'Change profile fields other than weight and goal. The app recalculates the calorie/protein targets.',
    parameters: {
      type: 'object',
      properties: {
        height_cm: { type: 'number', description: 'Height in cm (100-250).' },
        activity_level: { type: 'string', enum: [...ACTIVITY_LEVELS] },
        does_exercise: { type: 'boolean' },
        sport_type: { type: 'string', description: 'For example fitness, running, swimming.' },
        exercise_days_per_week: { type: 'integer', description: '0-7' },
        health_notes: { type: 'string' },
      },
    },
  },
  {
    name: 'set_goal',
    description: "Change the user's goal. The app recalculates the calorie/protein targets.",
    parameters: {
      type: 'object',
      properties: { goal: { type: 'string', enum: [...GOALS] } },
      required: ['goal'],
    },
  },
  {
    name: 'create_meal',
    description: 'Log a meal the user describes. Do not estimate calories or macros: they are looked up from USDA.',
    parameters: {
      type: 'object',
      properties: {
        meal_type: { type: 'string', enum: [...MEAL_TYPES] },
        time: { type: 'string', description: 'Local time today as HH:MM; omit for now.' },
        items: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              name: { type: 'string', description: "Food name in the user's language (shown to the user)." },
              grams: { type: 'number', description: 'Estimated portion in grams (1-2000).' },
              usda_query: { type: 'string', description: 'Generic English USDA search query incl. raw/cooked, e.g. "cooked white rice".' },
            },
            required: ['name', 'grams', 'usda_query'],
          },
        },
      },
      required: ['meal_type', 'items'],
    },
  },
  {
    name: 'log_set',
    description: 'Record weight and reps for one set of the in-progress workout and mark it done.',
    parameters: {
      type: 'object',
      properties: {
        exercise_name: { type: 'string', description: 'Exercise name exactly as listed in the in-progress workout.' },
        set_number: { type: 'integer', description: '1-based set number.' },
        weight_kg: { type: 'number', description: 'Weight in kg; 0 for bodyweight.' },
        reps: { type: 'integer' },
      },
      required: ['exercise_name', 'set_number', 'weight_kg', 'reps'],
    },
  },
  {
    name: 'edit_program',
    description: "Edit the user's own active program with one or more operations.",
    parameters: {
      type: 'object',
      properties: {
        operations: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              op: { type: 'string', enum: [...PROGRAM_OPS] },
              workout_name: { type: 'string', description: 'Workout name as listed in the active program.' },
              exercise_name: { type: 'string', description: 'English exercise name (add/remove/modify).' },
              sets: { type: 'integer', description: '1-10' },
              reps_min: { type: 'integer', description: '1-100' },
              reps_max: { type: 'integer', description: '1-100, at least reps_min' },
              new_name: { type: 'string', description: 'New workout name (rename_workout).' },
            },
            required: ['op', 'workout_name'],
          },
        },
      },
      required: ['operations'],
    },
  },
];

const LABELS = {
  tr: {
    weight: 'Kilo kaydı',
    profile: 'Profil güncelleme',
    goal: 'Amaç değişikliği',
    meal: 'Öğün',
    program: 'Program düzenleme',
    changes: 'değişiklik',
    set: (name: string, n: number, kg: number, reps: number) => `Set kaydı: ${name} ${n}. set — ${kg} kg × ${reps}`,
    goals: { lose_weight: 'Kilo vermek', gain_muscle: 'Kas kazanmak', maintain: 'Formda kalmak' },
    meals: { breakfast: 'Kahvaltı', lunch: 'Öğle', dinner: 'Akşam', snack: 'Atıştırmalık' },
    fields: {
      height_cm: 'boy', activity_level: 'aktivite', does_exercise: 'spor yapma', sport_type: 'spor türü',
      exercise_days_per_week: 'haftalık spor günü', health_notes: 'sağlık notları',
    } as Record<string, string>,
  },
  en: {
    weight: 'Log weight',
    profile: 'Update profile',
    goal: 'Change goal',
    meal: 'Meal',
    program: 'Edit program',
    changes: 'changes',
    set: (name: string, n: number, kg: number, reps: number) => `Log set: ${name} set ${n} — ${kg} kg × ${reps}`,
    goals: { lose_weight: 'Lose weight', gain_muscle: 'Gain muscle', maintain: 'Stay fit' },
    meals: { breakfast: 'Breakfast', lunch: 'Lunch', dinner: 'Dinner', snack: 'Snack' },
    fields: {
      height_cm: 'height', activity_level: 'activity', does_exercise: 'exercising', sport_type: 'sport',
      exercise_days_per_week: 'weekly training days', health_notes: 'health notes',
    } as Record<string, string>,
  },
};

class ToolArgError extends Error {
  constructor(message: string, readonly candidates: string[] = []) {
    super(message);
  }
}

function present(args: Args, key: string): boolean {
  return args[key] !== undefined && args[key] !== null;
}

function num(args: Args, key: string, min: number, max: number, integer = false): number {
  const value = args[key];
  if (typeof value !== 'number' || !Number.isFinite(value)) throw new ToolArgError(`${key} must be a number`);
  if (integer && !Number.isInteger(value)) throw new ToolArgError(`${key} must be an integer`);
  if (value < min || value > max) throw new ToolArgError(`${key} must be between ${min} and ${max}`);
  return value;
}

function optNum(args: Args, key: string, min: number, max: number, integer = false): number | undefined {
  return present(args, key) ? num(args, key, min, max, integer) : undefined;
}

function str(args: Args, key: string, maxLength: number): string {
  const value = args[key];
  if (typeof value !== 'string' || value.trim().length === 0 || value.length > maxLength) {
    throw new ToolArgError(`${key} must be a non-empty string of at most ${maxLength} characters`);
  }
  return value.trim();
}

/** Boş metin veya null → null (alanı temizler). */
function optText(args: Args, key: string, maxLength: number): string | null {
  return args[key] === null || args[key] === '' ? null : str(args, key, maxLength);
}

function oneOf<T extends string>(args: Args, key: string, values: readonly T[]): T {
  const value = args[key];
  if (typeof value !== 'string' || !(values as readonly string[]).includes(value)) {
    throw new ToolArgError(`${key} must be one of: ${values.join(', ')}`);
  }
  return value as T;
}

function objectAt(value: unknown, what: string): Args {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new ToolArgError(`each ${what} must be an object`);
  return value as Args;
}

function same(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase();
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

export async function prepareToolCall(name: string, args: Args, ctx: ToolContext, deps: ToolDeps): Promise<PreparedTool> {
  try {
    switch (name) {
      case 'log_body_weight':
        return prepareWeight(args, ctx);
      case 'update_profile':
        return prepareProfile(args, ctx);
      case 'set_goal':
        return prepareGoal(args, ctx);
      case 'create_meal':
        return await prepareMeal(args, ctx, deps);
      case 'log_set':
        return prepareSet(args, ctx);
      case 'edit_program':
        return await prepareProgram(args, ctx, deps);
      default:
        return { ok: false, error: `unknown tool ${name}` };
    }
  } catch (error) {
    if (error instanceof ToolArgError || error instanceof ProgramOpError) {
      return error.candidates.length > 0
        ? { ok: false, error: error.message, candidates: error.candidates }
        : { ok: false, error: error.message };
    }
    throw error;
  }
}

function prepareWeight(args: Args, ctx: ToolContext): PreparedTool {
  const kg = round1(num(args, 'weight_kg', 20, 400));
  const today = localDate(ctx.now, ctx.utcOffsetMinutes);
  let date = today;
  if (present(args, 'date')) {
    date = str(args, 'date', 10);
    const parsed = new Date(`${date}T00:00:00Z`);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
      throw new ToolArgError('date must be a valid YYYY-MM-DD');
    }
    if (date > today) throw new ToolArgError('date cannot be in the future');
  }
  return {
    ok: true,
    tool: 'log_body_weight',
    summary: `${LABELS[ctx.locale].weight}: ${kg} kg (${date})`,
    payload: { date, kg },
  };
}

function prepareProfile(args: Args, ctx: ToolContext): PreparedTool {
  for (const key of Object.keys(args)) {
    if (!PROFILE_FIELDS.includes(key)) {
      throw new ToolArgError(`unknown field ${key}; weight changes go through log_body_weight and the goal through set_goal`);
    }
  }
  const changes: Record<string, unknown> = {};
  if (present(args, 'height_cm')) changes.height_cm = round1(num(args, 'height_cm', 100, 250));
  if (present(args, 'activity_level')) changes.activity_level = oneOf(args, 'activity_level', ACTIVITY_LEVELS);
  if (present(args, 'does_exercise')) {
    if (typeof args.does_exercise !== 'boolean') throw new ToolArgError('does_exercise must be a boolean');
    changes.does_exercise = args.does_exercise;
  }
  if (args.sport_type !== undefined) changes.sport_type = optText(args, 'sport_type', 100);
  if (present(args, 'exercise_days_per_week')) changes.exercise_days_per_week = num(args, 'exercise_days_per_week', 0, 7, true);
  if (args.health_notes !== undefined) changes.health_notes = optText(args, 'health_notes', 500);

  const keys = Object.keys(changes);
  if (keys.length === 0) throw new ToolArgError('at least one field is required');
  const labels = LABELS[ctx.locale];
  return {
    ok: true,
    tool: 'update_profile',
    summary: `${labels.profile}: ${keys.map((k) => labels.fields[k]).join(', ')}`,
    payload: { changes },
  };
}

function prepareGoal(args: Args, ctx: ToolContext): PreparedTool {
  const goal = oneOf(args, 'goal', GOALS);
  if (ctx.data.profile?.goal === goal) throw new ToolArgError(`goal is already ${goal}`);
  const labels = LABELS[ctx.locale];
  return { ok: true, tool: 'set_goal', summary: `${labels.goal}: ${labels.goals[goal]}`, payload: { goal } };
}

/** Bugünün yerel saati (HH:MM) → UTC ISO; saat yoksa şimdi. */
function mealTime(args: Args, ctx: ToolContext): string {
  if (!present(args, 'time')) return ctx.now.toISOString();
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(String(args.time));
  if (!match) throw new ToolArgError('time must be HH:MM');
  const [year, month, day] = localDate(ctx.now, ctx.utcOffsetMinutes).split('-').map(Number);
  const localMs = Date.UTC(year, month - 1, day, Number(match[1]), Number(match[2]));
  return new Date(localMs - ctx.utcOffsetMinutes * 60_000).toISOString();
}

async function lookupMacros(query: string, deps: ToolDeps) {
  try {
    const match = await deps.findBestMatch(query);
    if (match) {
      const macros = await deps.fetchMacrosPer100g(match.fdcId);
      return {
        per100: { calories: macros.calories, protein_g: macros.proteinG, carbs_g: macros.carbsG, fat_g: macros.fatG },
        usda_fdc_id: String(match.fdcId),
        needs_review: false,
      };
    }
    console.warn(`No USDA match for "${query}"`);
  } catch (error) {
    console.error(`USDA lookup failed for "${query}":`, error);
  }
  return { per100: { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }, usda_fdc_id: null, needs_review: true };
}

async function prepareMeal(args: Args, ctx: ToolContext, deps: ToolDeps): Promise<PreparedTool> {
  const mealType = oneOf(args, 'meal_type', MEAL_TYPES);
  if (!Array.isArray(args.items) || args.items.length < 1 || args.items.length > 15) {
    throw new ToolArgError('items must have 1-15 entries');
  }
  const loggedAt = mealTime(args, ctx);
  const parsed = args.items.map((raw) => {
    const item = objectAt(raw, 'item');
    return { name: str(item, 'name', 100), grams: Math.round(num(item, 'grams', 1, 2000)), query: str(item, 'usda_query', 200) };
  });
  const items = [];
  for (const item of parsed) {
    items.push({ name: item.name, grams: item.grams, ...(await lookupMacros(item.query, deps)) });
  }
  const labels = LABELS[ctx.locale];
  return {
    ok: true,
    tool: 'create_meal',
    summary: `${labels.meal}: ${labels.meals[mealType]} — ${items.map((i) => `${i.name} (${i.grams} g)`).join(', ')}`,
    payload: { meal_id: deps.newId(), meal_type: mealType, logged_at: loggedAt, items },
  };
}

function prepareSet(args: Args, ctx: ToolContext): PreparedTool {
  const live = ctx.data.inProgress;
  if (!live) throw new ToolArgError('there is no workout in progress');
  const name = str(args, 'exercise_name', 100);
  const setNumber = num(args, 'set_number', 1, 50, true);
  const weightKg = round1(num(args, 'weight_kg', 0, 1000));
  const reps = num(args, 'reps', 0, 100, true);

  const matching = live.sets.filter((s) => same(s.exercise_name, name));
  if (matching.length === 0) {
    throw new ToolArgError(`exercise "${name}" is not in the in-progress workout`, unique(live.sets.map((s) => s.exercise_name)));
  }
  const position = matching[0].exercise_position;
  const ofExercise = matching.filter((s) => s.exercise_position === position);
  const target = ofExercise.find((s) => s.set_index === setNumber - 1);
  if (!target) {
    throw new ToolArgError(`${matching[0].exercise_name} has no set ${setNumber} (it has ${ofExercise.length} sets)`);
  }
  return {
    ok: true,
    tool: 'log_set',
    summary: LABELS[ctx.locale].set(target.exercise_name, setNumber, weightKg, reps),
    payload: {
      session_id: live.id,
      exercise_position: position,
      set_index: setNumber - 1,
      weight_kg: weightKg,
      reps,
      exercise_name: target.exercise_name,
      set_number: setNumber,
    },
  };
}

async function resolveExercise(query: string, deps: ToolDeps): Promise<{ id: string; name: string }> {
  const found = await deps.findExercises(query);
  const exact = found.filter((e) => same(e.name, query));
  if (exact.length > 0) return exact[0];
  if (found.length === 1) return found[0];
  throw new ToolArgError(
    found.length === 0 ? `no exercise matches "${query}"` : `"${query}" matches several exercises; pick one`,
    found.slice(0, 10).map((e) => e.name),
  );
}

async function prepareProgram(args: Args, ctx: ToolContext, deps: ToolDeps): Promise<PreparedTool> {
  const active = ctx.data.activeProgram;
  if (!active) throw new ToolArgError('the user has no active program');
  if (active.is_builtin) {
    throw new ToolArgError('the active program is built-in and read-only; tell the user to copy it in the Workout tab first');
  }
  if (!Array.isArray(args.operations) || args.operations.length < 1 || args.operations.length > 10) {
    throw new ToolArgError('operations must have 1-10 entries');
  }
  const snapshot = await deps.programSnapshot(active.id);
  if (!snapshot) throw new ToolArgError('the active program was not found');
  const ids = unique(snapshot.workouts.flatMap((w) => w.exercises.map((e) => e.exercise_id)));
  const names = ids.length > 0 ? await deps.exerciseNames(ids) : {};

  const ops: ProgramOperation[] = [];
  for (const raw of args.operations) {
    const o = objectAt(raw, 'operation');
    const op = oneOf(o, 'op', PROGRAM_OPS);
    const workoutName = str(o, 'workout_name', 50);
    switch (op) {
      case 'add_exercise': {
        const exercise = await resolveExercise(str(o, 'exercise_name', 100), deps);
        const repsMin = optNum(o, 'reps_min', 1, 100, true) ?? 8;
        ops.push({
          op,
          workout_name: workoutName,
          exercise_id: exercise.id,
          exercise_name: exercise.name,
          sets: optNum(o, 'sets', 1, 10, true) ?? 3,
          reps_min: repsMin,
          reps_max: optNum(o, 'reps_max', 1, 100, true) ?? (present(o, 'reps_min') ? repsMin : 12),
        });
        break;
      }
      case 'remove_exercise':
        ops.push({ op, workout_name: workoutName, exercise_name: str(o, 'exercise_name', 100) });
        break;
      case 'modify_exercise': {
        const sets = optNum(o, 'sets', 1, 10, true);
        const repsMin = optNum(o, 'reps_min', 1, 100, true);
        const repsMax = optNum(o, 'reps_max', 1, 100, true);
        if (sets === undefined && repsMin === undefined && repsMax === undefined) {
          throw new ToolArgError('modify_exercise needs sets, reps_min or reps_max');
        }
        ops.push({ op, workout_name: workoutName, exercise_name: str(o, 'exercise_name', 100), sets, reps_min: repsMin, reps_max: repsMax });
        break;
      }
      case 'rename_workout':
        ops.push({ op, workout_name: workoutName, new_name: str(o, 'new_name', 50) });
        break;
    }
  }

  const { program, changes } = applyProgramOperations(snapshot, ops, names);
  const labels = LABELS[ctx.locale];
  return {
    ok: true,
    tool: 'edit_program',
    summary: `${labels.program}: ${program.name} (${changes.length} ${labels.changes})`,
    payload: { program_id: active.id, program, changes },
  };
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `deno test supabase/functions/coach-chat/tools.test.ts`
Expected: PASS — 16 test.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/coach-chat/tools.ts supabase/functions/coach-chat/tools.test.ts
git commit -m "feat(coach): add tool definitions, validation and payload preparation"
```

---

### Task 8: İstek akışı (handler), Supabase deposu ve giriş noktası

**Files:**
- Create: `supabase/functions/coach-chat/handler.ts`
- Create: `supabase/functions/coach-chat/store.ts`
- Create: `supabase/functions/coach-chat/index.ts`
- Test: `supabase/functions/coach-chat/handler.test.ts`

**Interfaces:**
- Consumes: Task 1–2 SQL fonksiyonları (`recent_chat_messages`, `chat_target_snapshot`, `save_chat_exchange`, `program_snapshot`); Task 3 `_shared/http.ts`, `_shared/usda_client.ts`; Task 4 `createLlmClient`, `LlmQuotaError`, `LlmUnavailableError`; Task 5 `buildContextText`, `historyToLlmMessages`, `localDate`, `systemPrompt`, `fallbackReply`; Task 7 `prepareToolCall`, `TOOL_DEFINITIONS`, `ToolDeps`.
- Produces (`handler.ts`):

```ts
export const HISTORY_LIMIT = 20;
export const MAX_LLM_CALLS = 3;
export const MAX_MESSAGE_LENGTH = 2000;
export interface ChatStore {
  countUsageSince(since: Date): Promise<number>;
  recentMessages(limit: number): Promise<StoredMessage[]>;
  loadContext(range: { today: string; dayStart: Date; dayEnd: Date }): Promise<ContextData>;
  targetSnapshot(tool: ToolName, payload: Record<string, unknown>): Promise<unknown>;
  saveExchange(userText: string, assistantText: string, event: NewEvent | null): Promise<StoredMessage[]>;
}
export interface HandlerDeps { store: ChatStore; tools: ToolDeps; llm: LlmClient; dailyLimit: number; now: () => Date }
export function handleChatRequest(raw: unknown, deps: HandlerDeps): Promise<{ status: number; body: unknown }>;
```

- HTTP sözleşmesi (uygulama Task 10'da kullanır):
  - İstek `{action: 'status'}` → `200 {remaining}`
  - İstek `{message, locale: 'tr'|'en', utc_offset_minutes}` → `200 {messages: [userMsg, assistantMsg], remaining}`; mesaj biçimi `chat_message_json` ile aynı
  - Hatalar: `400 {code: 'INVALID_MESSAGE'}`, `401 {code: 'UNAUTHORIZED'}`, `429 {code: 'DAILY_LIMIT', remaining: 0}`, `429 {code: 'LLM_QUOTA'}`, `503 {code: 'LLM_UNAVAILABLE'}`, `500 {code: 'INTERNAL_ERROR'}`

- [ ] **Step 1: Handler testlerini yaz**

`supabase/functions/coach-chat/handler.test.ts`:

```ts
import { assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { handleChatRequest } from './handler.ts';
import type { ChatStore, HandlerDeps } from './handler.ts';
import { LlmQuotaError, LlmUnavailableError } from './llm/types.ts';
import type { LlmClient, LlmRequest, LlmResponse } from './llm/types.ts';
import { sampleContext } from './test_fixtures.ts';
import { TOOL_DEFINITIONS } from './tools.ts';
import type { ToolDeps } from './tools.ts';
import type { ContextData, NewEvent, StoredMessage, ToolName } from './types.ts';

class FakeStore implements ChatStore {
  used = 0;
  history: StoredMessage[] = [];
  since?: Date;
  historyLimit?: number;
  ranges: Array<{ today: string; dayStart: Date; dayEnd: Date }> = [];
  snapshots: Array<{ tool: ToolName; payload: Record<string, unknown> }> = [];
  saved: Array<{ userText: string; assistantText: string; event: NewEvent | null }> = [];

  countUsageSince(since: Date) {
    this.since = since;
    return Promise.resolve(this.used);
  }
  recentMessages(limit: number) {
    this.historyLimit = limit;
    return Promise.resolve(this.history);
  }
  loadContext(range: { today: string; dayStart: Date; dayEnd: Date }): Promise<ContextData> {
    this.ranges.push(range);
    return Promise.resolve(sampleContext());
  }
  targetSnapshot(tool: ToolName, payload: Record<string, unknown>) {
    this.snapshots.push({ tool, payload });
    return Promise.resolve({ snapshot: tool });
  }
  saveExchange(userText: string, assistantText: string, event: NewEvent | null): Promise<StoredMessage[]> {
    this.saved.push({ userText, assistantText, event });
    return Promise.resolve([
      { id: 'u', role: 'user', content: userText, created_at: 't1', event: null },
      { id: 'a', role: 'assistant', content: assistantText, created_at: 't2', event: event && { id: 'e1', status: 'pending', ...event } },
    ]);
  }
}

class ScriptedLlm implements LlmClient {
  requests: LlmRequest[] = [];
  constructor(private readonly responses: Array<LlmResponse | Error>) {}
  generate(req: LlmRequest): Promise<LlmResponse> {
    this.requests.push(structuredClone(req));
    const next = this.responses.shift();
    if (next === undefined) return Promise.reject(new Error('no scripted response'));
    return next instanceof Error ? Promise.reject(next) : Promise.resolve(next);
  }
}

const unusedTools: ToolDeps = {
  findExercises: () => Promise.resolve([]),
  exerciseNames: () => Promise.resolve({}),
  programSnapshot: () => Promise.resolve(null),
  findBestMatch: () => Promise.resolve(null),
  fetchMacrosPer100g: () => Promise.reject(new Error('unused')),
  newId: () => 'id',
};

const NOW = new Date('2026-09-30T22:30:00Z');

function setup(responses: Array<LlmResponse | Error>) {
  const store = new FakeStore();
  const llm = new ScriptedLlm(responses);
  const deps: HandlerDeps = { store, tools: unusedTools, llm, dailyLimit: 30, now: () => NOW };
  return { store, llm, deps };
}

const request = { message: '  Bugün ne yemeliyim?  ', locale: 'tr', utc_offset_minutes: 180 };

Deno.test('status returns the remaining quota without calling the model', async () => {
  const { store, llm, deps } = setup([]);
  store.used = 5;
  assertEquals(await handleChatRequest({ action: 'status' }, deps), { status: 200, body: { remaining: 25 } });
  assertEquals(store.since, new Date('2026-09-29T22:30:00Z'));
  assertEquals(llm.requests.length, 0);
});

Deno.test('rejects an empty or too long message', async () => {
  const { deps } = setup([]);
  assertEquals((await handleChatRequest({ message: '   ' }, deps)).status, 400);
  assertEquals((await handleChatRequest({ message: 'x'.repeat(2001) }, deps)).status, 400);
});

Deno.test('daily limit stops the request before the model', async () => {
  const { store, llm, deps } = setup([]);
  store.used = 30;
  const result = await handleChatRequest(request, deps);
  assertEquals(result, { status: 429, body: { code: 'DAILY_LIMIT', message: 'Günlük mesaj hakkı doldu', remaining: 0 } });
  assertEquals(llm.requests.length, 0);
  assertEquals(store.saved.length, 0);
});

Deno.test('a text reply is saved with the trimmed message and the remaining quota drops', async () => {
  const { store, llm, deps } = setup([{ type: 'text', text: 'Protein ağırlıklı bir akşam yemeği öneririm.' }]);
  const result = await handleChatRequest(request, deps);

  assertEquals(result.status, 200);
  assertEquals((result.body as { remaining: number }).remaining, 29);
  assertEquals(store.saved, [{ userText: 'Bugün ne yemeliyim?', assistantText: 'Protein ağırlıklı bir akşam yemeği öneririm.', event: null }]);
  assertEquals(store.historyLimit, 20);
  assertEquals(store.ranges, [{ today: '2026-10-01', dayStart: new Date('2026-09-30T21:00:00Z'), dayEnd: new Date('2026-10-01T21:00:00Z') }]);

  const sent = llm.requests[0];
  assertStringIncludes(sent.system, 'Always reply in Turkish.');
  assertStringIncludes(sent.system, '## Active program: My 5x5');
  assertEquals(sent.messages.at(-1), { role: 'user', text: 'Bugün ne yemeliyim?' });
  assertEquals(sent.tools, TOOL_DEFINITIONS);
});

Deno.test('history is passed before the new message', async () => {
  const { store, llm, deps } = setup([{ type: 'text', text: 'ok' }]);
  store.history = [
    { id: '1', role: 'user', content: 'selam', created_at: 't', event: null },
    { id: '2', role: 'assistant', content: 'merhaba', created_at: 't', event: null },
  ];
  await handleChatRequest(request, deps);
  assertEquals(llm.requests[0].messages.slice(0, 2), [{ role: 'user', text: 'selam' }, { role: 'assistant', text: 'merhaba' }]);
});

Deno.test('a valid tool call becomes a pending event with a base snapshot', async () => {
  const { store, deps } = setup([{ type: 'tool_call', name: 'set_goal', args: { goal: 'lose_weight' }, text: '' }]);
  const result = await handleChatRequest({ ...request, message: 'kilo vermek istiyorum' }, deps);

  assertEquals(result.status, 200);
  assertEquals(store.snapshots, [{ tool: 'set_goal', payload: { goal: 'lose_weight' } }]);
  assertEquals(store.saved[0], {
    userText: 'kilo vermek istiyorum',
    assistantText: 'Amaç değişikliği: Kilo vermek',
    event: { tool: 'set_goal', summary: 'Amaç değişikliği: Kilo vermek', payload: { goal: 'lose_weight' }, base: { snapshot: 'set_goal' } },
  });
});

Deno.test('the model text accompanies the card when present', async () => {
  const { store, deps } = setup([{ type: 'tool_call', name: 'set_goal', args: { goal: 'maintain' }, text: 'Şunu önereyim:' }]);
  await handleChatRequest(request, deps);
  assertEquals(store.saved[0].assistantText, 'Şunu önereyim:');
});

Deno.test('an invalid tool call is sent back to the model with the error, then corrected', async () => {
  const raw = { functionCall: { name: 'set_goal', args: { goal: 'gain_muscle' } }, thoughtSignature: 'SIG' };
  const { store, llm, deps } = setup([
    { type: 'tool_call', name: 'set_goal', args: { goal: 'gain_muscle' }, text: '', raw },
    { type: 'tool_call', name: 'set_goal', args: { goal: 'maintain' }, text: '' },
  ]);
  await handleChatRequest(request, deps);

  assertEquals(llm.requests.length, 2);
  assertEquals(llm.requests[1].messages.slice(-2), [
    { role: 'assistant_tool_call', name: 'set_goal', args: { goal: 'gain_muscle' }, raw },
    { role: 'tool_result', name: 'set_goal', result: { error: 'goal is already gain_muscle', candidates: [] } },
  ]);
  assertEquals(store.saved[0].event?.payload, { goal: 'maintain' });
});

Deno.test('after three invalid calls a fixed reply is saved without an event', async () => {
  const bad: LlmResponse = { type: 'tool_call', name: 'set_goal', args: { goal: 'fly' }, text: '' };
  const { store, llm, deps } = setup([bad, bad, bad, { type: 'text', text: 'never used' }]);
  await handleChatRequest({ ...request, locale: 'en' }, deps);

  assertEquals(llm.requests.length, 3);
  assertEquals(store.saved, [{
    userText: 'Bugün ne yemeliyim?',
    assistantText: "I couldn't quite understand that. Could you say it a bit more clearly?",
    event: null,
  }]);
});

Deno.test('model quota and availability errors map to 429 and 503 and save nothing', async () => {
  const quota = setup([new LlmQuotaError('quota')]);
  assertEquals(await handleChatRequest(request, quota.deps), {
    status: 429, body: { code: 'LLM_QUOTA', message: 'Antrenör şu an çok yoğun' },
  });
  assertEquals(quota.store.saved.length, 0);

  const down = setup([new LlmUnavailableError('down')]);
  assertEquals(await handleChatRequest(request, down.deps), {
    status: 503, body: { code: 'LLM_UNAVAILABLE', message: 'Antrenöre şu an ulaşılamıyor' },
  });
  assertEquals(down.store.saved.length, 0);
});
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `deno test supabase/functions/coach-chat/handler.test.ts`
Expected: FAIL — `Module not found ".../handler.ts"`.

- [ ] **Step 3: `handler.ts`'i yaz**

```ts
import { buildContextText, historyToLlmMessages, localDate } from './context.ts';
import { LlmQuotaError, LlmUnavailableError } from './llm/types.ts';
import type { LlmClient, LlmMessage } from './llm/types.ts';
import { fallbackReply, systemPrompt } from './prompts.ts';
import { prepareToolCall, TOOL_DEFINITIONS } from './tools.ts';
import type { ToolDeps } from './tools.ts';
import type { ContextData, Locale, NewEvent, StoredMessage, ToolName } from './types.ts';

export const HISTORY_LIMIT = 20;
export const MAX_LLM_CALLS = 3;
export const MAX_MESSAGE_LENGTH = 2000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_OFFSET_MINUTES = 14 * 60;

export interface ChatStore {
  countUsageSince(since: Date): Promise<number>;
  recentMessages(limit: number): Promise<StoredMessage[]>;
  loadContext(range: { today: string; dayStart: Date; dayEnd: Date }): Promise<ContextData>;
  targetSnapshot(tool: ToolName, payload: Record<string, unknown>): Promise<unknown>;
  saveExchange(userText: string, assistantText: string, event: NewEvent | null): Promise<StoredMessage[]>;
}

export interface HandlerDeps {
  store: ChatStore;
  tools: ToolDeps;
  llm: LlmClient;
  dailyLimit: number;
  now: () => Date;
}

export interface HandlerResult {
  status: number;
  body: unknown;
}

function failure(status: number, code: string, message: string): HandlerResult {
  return { status, body: { code, message } };
}

export async function handleChatRequest(raw: unknown, deps: HandlerDeps): Promise<HandlerResult> {
  const body = (typeof raw === 'object' && raw !== null ? raw : {}) as Record<string, unknown>;
  const now = deps.now();
  const used = await deps.store.countUsageSince(new Date(now.getTime() - DAY_MS));
  const remaining = Math.max(0, deps.dailyLimit - used);
  if (body.action === 'status') return { status: 200, body: { remaining } };

  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (message.length === 0 || message.length > MAX_MESSAGE_LENGTH) {
    return failure(400, 'INVALID_MESSAGE', 'Mesaj 1-2000 karakter olmalı');
  }
  if (remaining === 0) {
    return { status: 429, body: { code: 'DAILY_LIMIT', message: 'Günlük mesaj hakkı doldu', remaining: 0 } };
  }
  const locale: Locale = body.locale === 'en' ? 'en' : 'tr';
  const offset = typeof body.utc_offset_minutes === 'number' && Math.abs(body.utc_offset_minutes) <= MAX_OFFSET_MINUTES
    ? Math.round(body.utc_offset_minutes)
    : 0;

  const today = localDate(now, offset);
  const dayStart = new Date(Date.parse(`${today}T00:00:00Z`) - offset * 60_000);
  const dayEnd = new Date(dayStart.getTime() + DAY_MS);
  const [history, data] = await Promise.all([
    deps.store.recentMessages(HISTORY_LIMIT),
    deps.store.loadContext({ today, dayStart, dayEnd }),
  ]);

  const system = systemPrompt(locale, buildContextText(data, offset));
  const messages: LlmMessage[] = [...historyToLlmMessages(history), { role: 'user', text: message }];
  const toolContext = { data, now, utcOffsetMinutes: offset, locale };

  let reply = '';
  let event: NewEvent | null = null;
  try {
    for (let call = 0; call < MAX_LLM_CALLS; call++) {
      const response = await deps.llm.generate({ system, messages, tools: TOOL_DEFINITIONS });
      if (response.type === 'text') {
        reply = response.text;
        break;
      }
      const prepared = await prepareToolCall(response.name, response.args, toolContext, deps.tools);
      if (prepared.ok) {
        const base = await deps.store.targetSnapshot(prepared.tool, prepared.payload);
        event = { tool: prepared.tool, summary: prepared.summary, payload: prepared.payload, base };
        reply = response.text || prepared.summary;
        break;
      }
      console.warn(`Tool call rejected (${response.name}): ${prepared.error}`);
      messages.push({ role: 'assistant_tool_call', name: response.name, args: response.args, raw: response.raw });
      messages.push({
        role: 'tool_result',
        name: response.name,
        result: { error: prepared.error, candidates: prepared.candidates ?? [] },
      });
    }
  } catch (error) {
    if (error instanceof LlmQuotaError) {
      console.error(error);
      return failure(429, 'LLM_QUOTA', 'Antrenör şu an çok yoğun');
    }
    if (error instanceof LlmUnavailableError) {
      console.error(error);
      return failure(503, 'LLM_UNAVAILABLE', 'Antrenöre şu an ulaşılamıyor');
    }
    throw error;
  }

  if (!reply) reply = fallbackReply(locale);
  const saved = await deps.store.saveExchange(message, reply, event);
  return { status: 200, body: { messages: saved, remaining: remaining - 1 } };
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `deno test supabase/functions/coach-chat/handler.test.ts`
Expected: PASS — 10 test.

- [ ] **Step 5: Supabase deposunu yaz**

`supabase/functions/coach-chat/store.ts` (unit test edilmez; Task 13'te uçtan uca doğrulanır):

```ts
import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { fetchMacrosPer100g, findBestMatch } from '../_shared/usda_client.ts';
import type { ChatStore } from './handler.ts';
import type { ProgramSnapshot } from './program_ops.ts';
import type { ToolDeps } from './tools.ts';
import type {
  ContextData,
  InProgressSession,
  MealRow,
  NewEvent,
  ProfileRow,
  ProgramView,
  SessionSummary,
  StoredMessage,
  ToolName,
} from './types.ts';

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

const DAY_MS = 24 * 60 * 60 * 1000;

function check<T>(result: { data: unknown; error: unknown }, what: string): T {
  if (result.error) throw new Error(`${what} failed: ${JSON.stringify(result.error)}`);
  return result.data as T;
}

function byPosition(rows: Row[]): Row[] {
  return [...rows].sort((a, b) => a.exercise_position - b.exercise_position || a.set_index - b.set_index);
}

/** Tüm sorgular kullanıcının JWT'siyle gider; RLS kullanıcıyı sınırlar. */
export class SupabaseChatStore implements ChatStore {
  constructor(private readonly client: SupabaseClient) {}

  async countUsageSince(since: Date): Promise<number> {
    const { count, error } = await this.client
      .from('chat_usage')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', since.toISOString());
    if (error) throw new Error(`chat_usage count failed: ${JSON.stringify(error)}`);
    return count ?? 0;
  }

  async recentMessages(limit: number): Promise<StoredMessage[]> {
    return check(await this.client.rpc('recent_chat_messages', { p_limit: limit }), 'recent_chat_messages');
  }

  async targetSnapshot(tool: ToolName, payload: Record<string, unknown>): Promise<unknown> {
    return check(await this.client.rpc('chat_target_snapshot', { p_tool: tool, p_payload: payload }), 'chat_target_snapshot');
  }

  async saveExchange(userText: string, assistantText: string, event: NewEvent | null): Promise<StoredMessage[]> {
    return check(
      await this.client.rpc('save_chat_exchange', { p_user_text: userText, p_assistant_text: assistantText, p_event: event }),
      'save_chat_exchange',
    );
  }

  async loadContext(range: { today: string; dayStart: Date; dayEnd: Date }): Promise<ContextData> {
    const weightsSince = new Date(Date.parse(`${range.today}T00:00:00Z`) - 30 * DAY_MS).toISOString().slice(0, 10);
    const [profileRes, mealsRes, weightsRes, sessionsRes, liveRes, ormRes] = await Promise.all([
      this.client.from('profiles').select('*').maybeSingle(),
      this.client
        .from('meals')
        .select('meal_type, logged_at, meal_items(name, grams, calories, protein_g, carbs_g, fat_g)')
        .gte('logged_at', range.dayStart.toISOString())
        .lt('logged_at', range.dayEnd.toISOString())
        .order('logged_at'),
      this.client.from('body_weight_logs').select('logged_on, weight_kg').gte('logged_on', weightsSince).order('logged_on'),
      this.client
        .from('workout_sessions')
        .select('workout_name, finished_at, session_sets(exercise_position, set_index, weight_kg, reps, completed_at, exercises!exercise_id(name))')
        .not('finished_at', 'is', null)
        .order('finished_at', { ascending: false })
        .limit(5),
      this.client
        .from('workout_sessions')
        .select('id, workout_name, session_sets(exercise_position, set_index, target_reps_min, target_reps_max, weight_kg, reps, completed_at, exercises!exercise_id(name))')
        .is('finished_at', null)
        .maybeSingle(),
      this.client.from('user_one_rep_maxes').select('weight_kg, exercises(name)'),
    ]);

    const profile = check<ProfileRow | null>(profileRes, 'profiles');
    const todayMeals: MealRow[] = check<Row[]>(mealsRes, 'meals').map((m) => ({
      meal_type: m.meal_type,
      logged_at: m.logged_at,
      items: m.meal_items ?? [],
    }));
    const weights = check<Array<{ logged_on: string; weight_kg: number }>>(weightsRes, 'body_weight_logs');
    const recentSessions: SessionSummary[] = check<Row[]>(sessionsRes, 'workout_sessions').map((s) => ({
      workout_name: s.workout_name,
      finished_at: s.finished_at,
      sets: byPosition(s.session_sets ?? [])
        .filter((set) => set.completed_at !== null)
        .map((set) => ({ exercise_name: set.exercises?.name ?? '?', weight_kg: set.weight_kg, reps: set.reps })),
    }));
    const live = check<Row | null>(liveRes, 'in-progress session');
    const inProgress: InProgressSession | null = live && {
      id: live.id,
      workout_name: live.workout_name,
      sets: byPosition(live.session_sets ?? []).map((set) => ({
        exercise_position: set.exercise_position,
        set_index: set.set_index,
        exercise_name: set.exercises?.name ?? '?',
        target_reps_min: set.target_reps_min,
        target_reps_max: set.target_reps_max,
        weight_kg: set.weight_kg,
        reps: set.reps,
        completed: set.completed_at !== null,
      })),
    };
    const oneRepMaxes = check<Row[]>(ormRes, 'user_one_rep_maxes').map((r) => ({
      exercise_name: r.exercises?.name ?? '?',
      weight_kg: r.weight_kg,
    }));
    const activeProgram = profile?.active_program_id ? await this.programView(profile.active_program_id) : null;

    return { today: range.today, profile, todayMeals, weights, recentSessions, activeProgram, inProgress, oneRepMaxes };
  }

  private async programView(id: string): Promise<ProgramView | null> {
    const row = check<Row | null>(
      await this.client
        .from('programs')
        .select('id, name, user_id, program_workouts(name, position, workout_exercises(position, sets, reps_min, reps_max, exercises!exercise_id(name)))')
        .eq('id', id)
        .maybeSingle(),
      'programs',
    );
    if (!row) return null;
    const workouts = [...(row.program_workouts ?? [])]
      .sort((a: Row, b: Row) => a.position - b.position)
      .map((w: Row) => ({
        name: w.name,
        exercises: [...(w.workout_exercises ?? [])]
          .sort((a: Row, b: Row) => a.position - b.position)
          .map((e: Row) => ({ name: e.exercises?.name ?? '?', sets: e.sets, reps_min: e.reps_min, reps_max: e.reps_max })),
      }));
    return { id: row.id, name: row.name, is_builtin: row.user_id === null, workouts };
  }
}

export function supabaseToolDeps(client: SupabaseClient, usdaApiKey: string): ToolDeps {
  return {
    findExercises: async (query) => {
      const pattern = `%${query.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
      return check(await client.from('exercises').select('id, name').ilike('name', pattern).limit(10), 'exercises');
    },
    exerciseNames: async (ids) => {
      const rows = check<Array<{ id: string; name: string }>>(
        await client.from('exercises').select('id, name').in('id', ids),
        'exercises',
      );
      return Object.fromEntries(rows.map((r) => [r.id, r.name]));
    },
    programSnapshot: async (programId) =>
      check<ProgramSnapshot | null>(await client.rpc('program_snapshot', { p_program_id: programId }), 'program_snapshot'),
    findBestMatch: (query) => findBestMatch(query, usdaApiKey),
    fetchMacrosPer100g: (fdcId) => fetchMacrosPer100g(fdcId, usdaApiKey),
    newId: () => crypto.randomUUID(),
  };
}
```

- [ ] **Step 6: Giriş noktasını yaz**

`supabase/functions/coach-chat/index.ts`:

```ts
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders, getUserIdFromAuthHeader, jsonResponse } from '../_shared/http.ts';
import { handleChatRequest } from './handler.ts';
import { createLlmClient } from './llm/factory.ts';
import { SupabaseChatStore, supabaseToolDeps } from './store.ts';

const DEFAULT_DAILY_LIMIT = 30;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !getUserIdFromAuthHeader(req)) {
    return jsonResponse(401, { code: 'UNAUTHORIZED', message: 'Oturum gerekli' });
  }

  try {
    // Kullanıcının JWT'si: tüm okuma/yazmalar RLS'ten geçer (service role yok).
    // COACH_ANON_KEY: projede eski anon key kapalıysa publishable key buraya secret olarak verilir.
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('COACH_ANON_KEY');
    if (!anonKey) throw new Error('SUPABASE_ANON_KEY / COACH_ANON_KEY eksik');
    const client = createClient(Deno.env.get('SUPABASE_URL')!, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const limit = Number.parseInt(Deno.env.get('COACH_DAILY_LIMIT') ?? '', 10);
    const body = await req.json().catch(() => ({}));
    const result = await handleChatRequest(body, {
      store: new SupabaseChatStore(client),
      tools: supabaseToolDeps(client, Deno.env.get('USDA_FDC_API_KEY')!),
      llm: createLlmClient({
        provider: Deno.env.get('LLM_PROVIDER'),
        model: Deno.env.get('LLM_MODEL'),
        geminiApiKey: Deno.env.get('GEMINI_API_KEY'),
      }),
      dailyLimit: Number.isFinite(limit) && limit > 0 ? limit : DEFAULT_DAILY_LIMIT,
      now: () => new Date(),
    });
    return jsonResponse(result.status, result.body);
  } catch (error) {
    console.error(error);
    return jsonResponse(500, { code: 'INTERNAL_ERROR', message: 'Beklenmeyen bir hata oluştu' });
  }
});
```

- [ ] **Step 7: Tip kontrolü ve tüm Deno testleri**

Run: `deno check supabase/functions/coach-chat/index.ts`
Expected: hata yok. (İlk çalıştırmada `jsr:@supabase/supabase-js` indirilir. Ağ yüzünden 3 dakikada bitmezse durdur, durumu not et; tip kontrolü Task 13'teki deploy sırasında yapılır.)

Run: `deno test supabase/functions/`
Expected: PASS — 29 + 14 + 7 + 9 + 16 + 10 = 85 test.

- [ ] **Step 8: Commit**

```bash
git add supabase/functions/coach-chat/handler.ts supabase/functions/coach-chat/handler.test.ts supabase/functions/coach-chat/store.ts supabase/functions/coach-chat/index.ts
git commit -m "feat(coach): add coach-chat request flow, Supabase store and entry point"
```

---
### Task 9: Profil yardımcıları, sohbet modelleri ve kart verisi (saf Dart)

**Files:**
- Modify: `lib/features/onboarding/domain/profile.dart`
- Create: `lib/features/chat/domain/chat_models.dart`
- Create: `lib/features/chat/domain/card_data.dart`
- Test: `test/features/onboarding/domain/profile_copy_test.dart`
- Test: `test/features/chat/fixtures.dart`
- Test: `test/features/chat/domain/chat_models_test.dart`
- Test: `test/features/chat/domain/card_data_test.dart`

**Interfaces:**
- Produces (`profile.dart`, eklenen/açılan):
  - `Profile copyWith({double? weightKg, double? heightCm, ActivityLevel? activityLevel, bool? doesExercise, int? exerciseDaysPerWeek, Goal? goal})`
  - `String activityLevelToDb(ActivityLevel)`, `ActivityLevel activityLevelFromDb(String)`, `String goalToDb(Goal)`, `Goal goalFromDb(String)` (eskiden `_` önekliydi; davranış aynı)
- Produces (`chat_models.dart`):

```dart
enum ChatRole { user, assistant }
enum ChatTool { logBodyWeight, updateProfile, setGoal, createMeal, logSet, editProgram; String get dbName; static ChatTool fromDb(String) }
enum ChatEventStatus { pending, applied, cancelled, undone, stale }
class ChatEvent { String id; ChatTool tool; ChatEventStatus status; String summary; Map<String, dynamic> payload; Map<String, dynamic> base; factory fromJson; ChatEvent withStatus(ChatEventStatus) }
class ChatMessage { String id; ChatRole role; String content; DateTime createdAt; ChatEvent? event; factory fromJson; ChatMessage withEvent(ChatEvent) }
```

- Produces (`card_data.dart`):

```dart
const Set<ChatTool> profileTools;   // logBodyWeight, updateProfile, setGoal
class FieldChange { final String field; final Object? before; final Object? after; }
List<FieldChange> profileFieldChanges(ChatEvent event);           // updateProfile / setGoal
Profile profileAfter(Profile profile, ChatEvent event);
TdeeResult? targetsAfter(Profile profile, ChatEvent event, {required int currentYear, TdeeCalculator calculator = const TdeeCalculator()});
DateTime weightDate(ChatEvent event);
double weightBefore(ChatEvent event);   // o tarihteki kayıt, yoksa profildeki kilo
double weightAfter(ChatEvent event);
bool isNewestWeight(ChatEvent event, List<BodyWeightLog> logs);
class MealCardItem { String name; double grams; double per100Calories, per100ProteinG, per100CarbsG, per100FatG; bool needsReview; double get calories, proteinG, carbsG, fatG; MealCardItem withGrams(double) }
List<MealCardItem> mealItems(ChatEvent event);
double round1(double value);
Map<String, dynamic> applyExtras({TdeeResult? targets, List<double>? itemGrams});
List<String> programChangeLabels(ChatEvent event);
```

- [ ] **Step 1: Profil testini yaz**

`test/features/onboarding/domain/profile_copy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

import '../../progress/fixtures.dart';

void main() {
  test('copyWith replaces only the given fields', () {
    final copy = testProfile.copyWith(weightKg: 82, goal: Goal.loseWeight, activityLevel: ActivityLevel.active);

    expect(copy.weightKg, 82);
    expect(copy.goal, Goal.loseWeight);
    expect(copy.activityLevel, ActivityLevel.active);
    expect(copy.userId, testProfile.userId);
    expect(copy.heightCm, testProfile.heightCm);
    expect(copy.dailyCalorieTarget, testProfile.dailyCalorieTarget);
  });

  test('database names round-trip', () {
    for (final level in ActivityLevel.values) {
      expect(activityLevelFromDb(activityLevelToDb(level)), level);
    }
    for (final goal in Goal.values) {
      expect(goalFromDb(goalToDb(goal)), goal);
    }
    expect(activityLevelToDb(ActivityLevel.veryActive), 'very_active');
    expect(goalToDb(Goal.gainMuscle), 'gain_muscle');
  });
}
```

- [ ] **Step 2: Başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/onboarding/domain/profile_copy_test.dart`
Expected: FAIL — `The method 'copyWith' isn't defined for the type 'Profile'`.

- [ ] **Step 3: `profile.dart`'ı güncelle**

`lib/features/onboarding/domain/profile.dart` içinde dört fonksiyonun `_` önekini kaldır (`_activityLevelToDb` → `activityLevelToDb`, `_activityLevelFromDb` → `activityLevelFromDb`, `_goalToDb` → `goalToDb`, `_goalFromDb` → `goalFromDb`) ve `fromJson` / `toJson` içindeki çağrıları da buna göre değiştir. `toJson`'dan sonra `Profile` sınıfına ekle:

```dart
  /// Hedef hesabı gibi "ya böyle olsaydı" durumları için kopya.
  Profile copyWith({
    double? weightKg,
    double? heightCm,
    ActivityLevel? activityLevel,
    bool? doesExercise,
    int? exerciseDaysPerWeek,
    Goal? goal,
  }) {
    return Profile(
      userId: userId,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      birthYear: birthYear,
      gender: gender,
      activityLevel: activityLevel ?? this.activityLevel,
      doesExercise: doesExercise ?? this.doesExercise,
      sportType: sportType,
      exerciseDaysPerWeek: exerciseDaysPerWeek ?? this.exerciseDaysPerWeek,
      goal: goal ?? this.goal,
      healthNotes: healthNotes,
      dailyCalorieTarget: dailyCalorieTarget,
      dailyProteinTargetG: dailyProteinTargetG,
    );
  }
```

Kontrol: `grep -rn "_goalToDb\|_goalFromDb\|_activityLevelToDb\|_activityLevelFromDb" lib test` sonuç vermemeli.

- [ ] **Step 4: Geçtiğini gör**

Run: `flutter test --no-pub test/features/onboarding/domain/`
Expected: PASS (mevcut profil testleri dahil).

- [ ] **Step 5: Ortak test verisini yaz**

`test/features/chat/fixtures.dart`:

```dart
import 'package:spor_takip/features/chat/domain/chat_models.dart';

const _targets = {'daily_calorie_target': 2700, 'daily_protein_target_g': 176};

/// Profil kilosu 80; [logBefore] o tarihteki eski kayıt.
ChatEvent weightEvent({
  String date = '2026-10-01',
  num kg = 82,
  num? logBefore,
  ChatEventStatus status = ChatEventStatus.pending,
}) {
  return ChatEvent(
    id: 'e-weight',
    tool: ChatTool.logBodyWeight,
    status: status,
    summary: 'Kilo kaydı: $kg kg ($date)',
    payload: {'date': date, 'kg': kg},
    base: {
      'log': logBefore,
      'profile': {'weight_kg': 80, ..._targets},
    },
  );
}

ChatEvent profileEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-profile',
    tool: ChatTool.updateProfile,
    status: status,
    summary: 'Profil güncelleme: boy, aktivite',
    payload: {
      'changes': {'height_cm': 185, 'activity_level': 'active'},
    },
    base: {'activity_level': 'moderate', 'height_cm': 180, ..._targets},
  );
}

ChatEvent goalEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-goal',
    tool: ChatTool.setGoal,
    status: status,
    summary: 'Amaç değişikliği: Kilo vermek',
    payload: {'goal': 'lose_weight'},
    base: {'goal': 'gain_muscle', ..._targets},
  );
}

ChatEvent mealEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-meal',
    tool: ChatTool.createMeal,
    status: status,
    summary: 'Öğün: Öğle — Tavuk (200 g), Ayran (200 g)',
    payload: {
      'meal_id': 'meal-1',
      'meal_type': 'lunch',
      'logged_at': '2026-10-01T09:30:00.000Z',
      'items': [
        {
          'name': 'Tavuk',
          'grams': 200,
          'per100': {'calories': 165, 'protein_g': 31, 'carbs_g': 0, 'fat_g': 3.6},
          'usda_fdc_id': '171077',
          'needs_review': false,
        },
        {
          'name': 'Ayran',
          'grams': 200,
          'per100': {'calories': 0, 'protein_g': 0, 'carbs_g': 0, 'fat_g': 0},
          'usda_fdc_id': null,
          'needs_review': true,
        },
      ],
    },
    base: {'meal': null},
  );
}

ChatEvent setEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-set',
    tool: ChatTool.logSet,
    status: status,
    summary: 'Set kaydı: Barbell Squat 3. set — 80 kg × 5',
    payload: {
      'session_id': 'session-1',
      'exercise_position': 0,
      'set_index': 2,
      'weight_kg': 80,
      'reps': 5,
      'exercise_name': 'Barbell Squat',
      'set_number': 3,
    },
    base: {
      'set': {'weight_kg': null, 'reps': null, 'completed_at': null, 'finished_at': null},
    },
  );
}

ChatEvent programEvent({ChatEventStatus status = ChatEventStatus.pending}) {
  return ChatEvent(
    id: 'e-program',
    tool: ChatTool.editProgram,
    status: status,
    summary: 'Program düzenleme: My 5x5 (2 değişiklik)',
    payload: {
      'program_id': 'prog-1',
      'program': {'id': 'prog-1', 'name': 'My 5x5', 'workouts': []},
      'changes': [
        {'kind': 'add', 'label': '+ A: Barbell Deadlift 1×5'},
        {'kind': 'remove', 'label': '− A: Barbell Squat'},
      ],
    },
    base: {
      'program': {'id': 'prog-1'},
    },
  );
}

ChatMessage userMessage(String content, {String id = 'u1'}) {
  return ChatMessage(id: id, role: ChatRole.user, content: content, createdAt: DateTime.utc(2026, 10, 1, 9));
}

ChatMessage assistantMessage(ChatEvent? event, {String id = 'a1', String content = 'Kaydedeyim mi?'}) {
  return ChatMessage(
    id: id,
    role: ChatRole.assistant,
    content: content,
    createdAt: DateTime.utc(2026, 10, 1, 9, 1),
    event: event,
  );
}
```

- [ ] **Step 6: Model testlerini yaz**

`test/features/chat/domain/chat_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';

void main() {
  test('parses a message with an embedded event (chat_message_json shape)', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'role': 'assistant',
      'content': 'Kaydedeyim mi?',
      'created_at': '2026-10-01T09:01:00+00:00',
      'event': {
        'id': 'e1',
        'tool': 'log_body_weight',
        'status': 'pending',
        'summary': 'Kilo kaydı: 82 kg (2026-10-01)',
        'payload': {'date': '2026-10-01', 'kg': 82},
        'base': {'log': null},
      },
    });

    expect(message.role, ChatRole.assistant);
    expect(message.createdAt, DateTime.utc(2026, 10, 1, 9, 1));
    expect(message.event!.tool, ChatTool.logBodyWeight);
    expect(message.event!.status, ChatEventStatus.pending);
    expect(message.event!.payload['kg'], 82);
    expect(message.event!.base, {'log': null});
  });

  test('parses a message without an event', () {
    final message = ChatMessage.fromJson({
      'id': 'm2',
      'role': 'user',
      'content': 'selam',
      'created_at': '2026-10-01T09:00:00Z',
      'event': null,
    });
    expect(message.role, ChatRole.user);
    expect(message.event, isNull);
  });

  test('tool names map to and from the database', () {
    for (final tool in ChatTool.values) {
      expect(ChatTool.fromDb(tool.dbName), tool);
    }
    expect(ChatTool.editProgram.dbName, 'edit_program');
    expect(() => ChatTool.fromDb('nope'), throwsArgumentError);
  });

  test('withStatus and withEvent copy everything else', () {
    final event = ChatEvent.fromJson({
      'id': 'e1',
      'tool': 'set_goal',
      'status': 'pending',
      'summary': 's',
      'payload': {'goal': 'maintain'},
      'base': {'goal': 'gain_muscle'},
    });
    final applied = event.withStatus(ChatEventStatus.applied);
    expect(applied.status, ChatEventStatus.applied);
    expect(applied.payload, event.payload);

    final message = ChatMessage(id: 'm', role: ChatRole.assistant, content: 'c', createdAt: DateTime.utc(2026), event: event);
    expect(message.withEvent(applied).event!.status, ChatEventStatus.applied);
    expect(message.withEvent(applied).content, 'c');
  });
}
```

- [ ] **Step 7: Kart verisi testlerini yaz**

`test/features/chat/domain/card_data_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/domain/card_data.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';

import '../../progress/fixtures.dart';
import '../fixtures.dart';

void main() {
  test('profile field changes pair the base value with the proposed one', () {
    final changes = profileFieldChanges(profileEvent());
    expect([for (final c in changes) (c.field, c.before, c.after)], [
      ('height_cm', 180, 185),
      ('activity_level', 'moderate', 'active'),
    ]);
    final goal = profileFieldChanges(goalEvent()).single;
    expect((goal.field, goal.before, goal.after), ('goal', 'gain_muscle', 'lose_weight'));
  });

  test('profileAfter applies the proposed change', () {
    expect(profileAfter(testProfile, weightEvent(kg: 82)).weightKg, 82);
    final updated = profileAfter(testProfile, profileEvent());
    expect(updated.heightCm, 185);
    expect(updated.activityLevel, ActivityLevel.active);
    expect(profileAfter(testProfile, goalEvent()).goal, Goal.loseWeight);
    expect(profileAfter(testProfile, mealEvent()), same(testProfile));
  });

  test('targetsAfter uses TdeeCalculator on the changed profile', () {
    final expected = const TdeeCalculator().calculate(
      weightKg: 82,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: Gender.male,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.gainMuscle,
    );
    final targets = targetsAfter(testProfile, weightEvent(kg: 82), currentYear: 2026)!;
    expect(targets.calorieTarget, expected.calorieTarget);
    expect(targets.proteinTargetG, expected.proteinTargetG);
    expect(targetsAfter(testProfile, mealEvent(), currentYear: 2026), isNull);
  });

  test('weight before is the same-day log, else the profile weight', () {
    expect(weightBefore(weightEvent()), 80);
    expect(weightBefore(weightEvent(logBefore: 81.5)), 81.5);
    expect(weightAfter(weightEvent(kg: 82)), 82);
    expect(weightDate(weightEvent(date: '2026-09-15')), DateTime(2026, 9, 15));
  });

  test('a weight entry is newest when it is not before the last log', () {
    final logs = [BodyWeightLog(date: DateTime(2026, 9, 30), weightKg: 80)];
    expect(isNewestWeight(weightEvent(date: '2026-10-01'), logs), isTrue);
    expect(isNewestWeight(weightEvent(date: '2026-09-30'), logs), isTrue);
    expect(isNewestWeight(weightEvent(date: '2026-09-01'), logs), isFalse);
    expect(isNewestWeight(weightEvent(), const []), isTrue);
  });

  test('meal items scale per-100 g values by grams with one decimal', () {
    final items = mealItems(mealEvent());
    expect(items.first.calories, 330);
    expect(items.first.proteinG, 62);
    expect(items.first.fatG, 7.2);
    expect(items.first.withGrams(150).calories, 247.5);
    expect(items.first.withGrams(150).name, 'Tavuk');
    expect(items.last.needsReview, isTrue);
    expect(round1(0.25), 0.3);
  });

  test('apply extras carry targets and edited grams', () {
    expect(applyExtras(), <String, dynamic>{});
    expect(
      applyExtras(targets: const TdeeResult(calorieTarget: 2800, proteinTargetG: 170)),
      {'calorie_target': 2800, 'protein_target': 170},
    );
    expect(applyExtras(itemGrams: [150, 200]), {
      'item_grams': [150, 200],
    });
  });

  test('program change labels come from the payload', () {
    expect(programChangeLabels(programEvent()), ['+ A: Barbell Deadlift 1×5', '− A: Barbell Squat']);
  });
}
```

- [ ] **Step 8: Başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/chat/domain/`
Expected: FAIL — `chat_models.dart` / `card_data.dart` bulunamıyor.

- [ ] **Step 9: `chat_models.dart`'ı yaz**

```dart
enum ChatRole { user, assistant }

/// Sohbetin araçları; [dbName] `chat_events.tool` değeridir.
enum ChatTool {
  logBodyWeight('log_body_weight'),
  updateProfile('update_profile'),
  setGoal('set_goal'),
  createMeal('create_meal'),
  logSet('log_set'),
  editProgram('edit_program');

  const ChatTool(this.dbName);

  final String dbName;

  static ChatTool fromDb(String value) {
    for (final tool in values) {
      if (tool.dbName == value) return tool;
    }
    throw ArgumentError('Unknown chat tool: $value');
  }
}

enum ChatEventStatus { pending, applied, cancelled, undone, stale }

/// Sohbetin önerdiği bir değişiklik (`chat_events`). [base]: öneri anındaki
/// verinin görüntüsü; kartta "önce" değerleri buradan okunur.
class ChatEvent {
  const ChatEvent({
    required this.id,
    required this.tool,
    required this.status,
    required this.summary,
    required this.payload,
    required this.base,
  });

  final String id;
  final ChatTool tool;
  final ChatEventStatus status;
  final String summary;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> base;

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    return ChatEvent(
      id: json['id'] as String,
      tool: ChatTool.fromDb(json['tool'] as String),
      status: ChatEventStatus.values.byName(json['status'] as String),
      summary: json['summary'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      base: Map<String, dynamic>.from(json['base'] as Map),
    );
  }

  ChatEvent withStatus(ChatEventStatus status) {
    return ChatEvent(id: id, tool: tool, status: status, summary: summary, payload: payload, base: base);
  }
}

/// `chat_message_json` biçimindeki bir mesaj.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.event,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final ChatEvent? event;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    return ChatMessage(
      id: json['id'] as String,
      role: ChatRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      event: event == null ? null : ChatEvent.fromJson(Map<String, dynamic>.from(event as Map)),
    );
  }

  ChatMessage withEvent(ChatEvent event) {
    return ChatMessage(id: id, role: role, content: content, createdAt: createdAt, event: event);
  }
}
```

- [ ] **Step 10: `card_data.dart`'ı yaz**

```dart
import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';
import '../../progress/domain/body_weight_log.dart';
import '../../progress/domain/progress_format.dart';
import 'chat_models.dart';

/// Onayda yeni kalori/protein hedefi gönderen araçlar.
const profileTools = {ChatTool.logBodyWeight, ChatTool.updateProfile, ChatTool.setGoal};

/// Kartta bir profil alanının önce → sonra satırı.
class FieldChange {
  const FieldChange(this.field, this.before, this.after);

  final String field;
  final Object? before;
  final Object? after;
}

List<FieldChange> profileFieldChanges(ChatEvent event) {
  final changes = event.tool == ChatTool.setGoal
      ? {'goal': event.payload['goal']}
      : Map<String, dynamic>.from(event.payload['changes'] as Map);
  return [for (final e in changes.entries) FieldChange(e.key, event.base[e.key], e.value)];
}

/// Değişiklik uygulanmış profil (yalnız hedefi etkileyen alanlar).
Profile profileAfter(Profile profile, ChatEvent event) {
  switch (event.tool) {
    case ChatTool.logBodyWeight:
      return profile.copyWith(weightKg: weightAfter(event));
    case ChatTool.setGoal:
      return profile.copyWith(goal: goalFromDb(event.payload['goal'] as String));
    case ChatTool.updateProfile:
      final changes = Map<String, dynamic>.from(event.payload['changes'] as Map);
      final activity = changes['activity_level'] as String?;
      return profile.copyWith(
        heightCm: (changes['height_cm'] as num?)?.toDouble(),
        activityLevel: activity == null ? null : activityLevelFromDb(activity),
        doesExercise: changes['does_exercise'] as bool?,
        exerciseDaysPerWeek: changes['exercise_days_per_week'] as int?,
      );
    case ChatTool.createMeal || ChatTool.logSet || ChatTool.editProgram:
      return profile;
  }
}

/// Profil araçlarında onayla gönderilecek yeni hedefler; diğerlerinde null.
TdeeResult? targetsAfter(
  Profile profile,
  ChatEvent event, {
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  if (!profileTools.contains(event.tool)) return null;
  final after = profileAfter(profile, event);
  return calculator.calculate(
    weightKg: after.weightKg,
    heightCm: after.heightCm,
    birthYear: after.birthYear,
    currentYear: currentYear,
    gender: after.gender,
    activityLevel: after.activityLevel,
    goal: after.goal,
  );
}

DateTime weightDate(ChatEvent event) => parseDbDate(event.payload['date'] as String);

double weightAfter(ChatEvent event) => (event.payload['kg'] as num).toDouble();

/// O tarihte kayıt varsa onun kilosu, yoksa profildeki kilo.
double weightBefore(ChatEvent event) {
  final log = event.base['log'] as num?;
  final profile = Map<String, dynamic>.from(event.base['profile'] as Map);
  return (log ?? profile['weight_kg'] as num).toDouble();
}

/// Kayıt en yeniyse profili ve hedefleri değiştirir (log_body_weight kuralı).
bool isNewestWeight(ChatEvent event, List<BodyWeightLog> logs) {
  return logs.isEmpty || !weightDate(event).isBefore(logs.last.date);
}

double round1(double value) => (value * 10).roundToDouble() / 10;

/// Öğün kartındaki bir kalem; makrolar 100 g değerlerinden hesaplanır (SQL ile aynı yuvarlama).
class MealCardItem {
  const MealCardItem({
    required this.name,
    required this.grams,
    required this.per100Calories,
    required this.per100ProteinG,
    required this.per100CarbsG,
    required this.per100FatG,
    required this.needsReview,
  });

  factory MealCardItem.fromPayload(Map<String, dynamic> json) {
    final per100 = Map<String, dynamic>.from(json['per100'] as Map);
    return MealCardItem(
      name: json['name'] as String,
      grams: (json['grams'] as num).toDouble(),
      per100Calories: (per100['calories'] as num).toDouble(),
      per100ProteinG: (per100['protein_g'] as num).toDouble(),
      per100CarbsG: (per100['carbs_g'] as num).toDouble(),
      per100FatG: (per100['fat_g'] as num).toDouble(),
      needsReview: json['needs_review'] as bool? ?? false,
    );
  }

  final String name;
  final double grams;
  final double per100Calories;
  final double per100ProteinG;
  final double per100CarbsG;
  final double per100FatG;
  final bool needsReview;

  double _scale(double per100) => round1(grams * per100 / 100);

  double get calories => _scale(per100Calories);
  double get proteinG => _scale(per100ProteinG);
  double get carbsG => _scale(per100CarbsG);
  double get fatG => _scale(per100FatG);

  MealCardItem withGrams(double grams) {
    return MealCardItem(
      name: name,
      grams: grams,
      per100Calories: per100Calories,
      per100ProteinG: per100ProteinG,
      per100CarbsG: per100CarbsG,
      per100FatG: per100FatG,
      needsReview: needsReview,
    );
  }
}

List<MealCardItem> mealItems(ChatEvent event) {
  return [
    for (final item in event.payload['items'] as List) MealCardItem.fromPayload(Map<String, dynamic>.from(item as Map)),
  ];
}

/// `apply_chat_action`'ın `p_extras` parametresi.
Map<String, dynamic> applyExtras({TdeeResult? targets, List<double>? itemGrams}) {
  return {
    if (targets != null) ...{'calorie_target': targets.calorieTarget, 'protein_target': targets.proteinTargetG},
    if (itemGrams != null) 'item_grams': itemGrams,
  };
}

List<String> programChangeLabels(ChatEvent event) {
  return [for (final change in event.payload['changes'] as List) (change as Map)['label'] as String];
}
```

- [ ] **Step 11: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/chat/domain/ test/features/onboarding/domain/`
Expected: PASS.

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

- [ ] **Step 12: Commit**

```bash
git add lib/features/onboarding/domain/profile.dart lib/features/chat/domain test/features/chat test/features/onboarding/domain/profile_copy_test.dart
git commit -m "feat(coach): add chat models and confirm card data helpers"
```

---

### Task 10: Sohbet deposu, notifier ve yenileme

**Files:**
- Create: `lib/features/chat/data/chat_repository.dart`
- Create: `lib/features/chat/application/chat_providers.dart`
- Create: `lib/features/chat/application/chat_refresh.dart`
- Create: `lib/features/chat/application/chat_notifier.dart`
- Test: `test/features/chat/fakes.dart`
- Test: `test/features/chat/application/chat_notifier_test.dart`

**Interfaces:**
- Consumes: `ChatMessage`, `ChatEvent`, `ChatEventStatus`, `ChatTool` (Task 9); Edge Function HTTP sözleşmesi (Task 8); SQL RPC'leri (Task 1–2); mevcut provider'lar: `weightLogsProvider`, `weeklyMealsProvider` (`progress_providers.dart`), `profileProvider`, `todayMealsProvider`, `inProgressSessionProvider`, `nowProvider` (`session_providers.dart`), `sessionNotifierProvider` (`session_notifier.dart`), `programsProvider`, `programDetailProvider` (`workout_providers.dart`).
- Produces (`chat_repository.dart`):

```dart
enum ChatSendError { dailyLimit, busy, unavailable }
class ChatSendException implements Exception { const ChatSendException(this.error); final ChatSendError error; }
enum ApplyOutcome { applied, stale }
enum UndoOutcome { undone, modified }
class ChatSendResult { const ChatSendResult({required this.messages, required this.remaining}); final List<ChatMessage> messages; final int remaining; }
abstract interface class ChatRepository {
  Future<List<ChatMessage>> fetchMessages();
  Future<int?> fetchRemaining();
  Future<ChatSendResult> send({required String message, required String locale, required int utcOffsetMinutes});
  Future<ApplyOutcome> apply(String eventId, Map<String, dynamic> extras);
  Future<void> cancel(String eventId);
  Future<UndoOutcome> undo(String eventId);
  Future<void> clear();
}
class SupabaseChatRepository implements ChatRepository { SupabaseChatRepository(SupabaseClient client); }
```

- Produces (`chat_providers.dart`): `final chatRepositoryProvider = Provider<ChatRepository>(...)`
- Produces (`chat_refresh.dart`): `void refreshAfterChatChange(Ref ref, ChatEvent event)`
- Produces (`chat_notifier.dart`):

```dart
class ChatState { const ChatState({this.messages = const [], this.sending = false, this.unsentText, this.sendError, this.remaining}); List<ChatMessage> messages; bool sending; String? unsentText; ChatSendError? sendError; int? remaining; }
final chatNotifierProvider = AsyncNotifierProvider.autoDispose<ChatNotifier, ChatState>(ChatNotifier.new);
class ChatNotifier extends AsyncNotifier<ChatState> {
  Future<void> send(String text, {required String locale});
  Future<void> retry({required String locale});
  Future<ApplyOutcome> apply(ChatEvent event, Map<String, dynamic> extras);
  Future<void> cancel(ChatEvent event);
  Future<UndoOutcome> undo(ChatEvent event);
  Future<void> clear();
}
```

- Produces (`test/features/chat/fakes.dart`): `FakeChatRepository` (Task 11–12 testleri de kullanır)

- [ ] **Step 1: Depoyu yaz**

`lib/features/chat/data/chat_repository.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_models.dart';

enum ChatSendError { dailyLimit, busy, unavailable }

class ChatSendException implements Exception {
  const ChatSendException(this.error);

  final ChatSendError error;
}

enum ApplyOutcome { applied, stale }

enum UndoOutcome { undone, modified }

class ChatSendResult {
  const ChatSendResult({required this.messages, required this.remaining});

  /// Kaydedilen kullanıcı ve asistan mesajı, eskiden yeniye.
  final List<ChatMessage> messages;
  final int remaining;
}

abstract interface class ChatRepository {
  /// Son 200 mesaj, eskiden yeniye.
  Future<List<ChatMessage>> fetchMessages();

  /// Son 24 saatte kalan mesaj hakkı; öğrenilemezse null.
  Future<int?> fetchRemaining();

  /// Hata durumunda [ChatSendException]; hiçbir şey kaydedilmez.
  Future<ChatSendResult> send({required String message, required String locale, required int utcOffsetMinutes});

  Future<ApplyOutcome> apply(String eventId, Map<String, dynamic> extras);

  Future<void> cancel(String eventId);

  Future<UndoOutcome> undo(String eventId);

  /// Mesajları siler (öneri kayıtları ve sayaç kalır).
  Future<void> clear();
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  static const _function = 'coach-chat';
  static const _historyLimit = 200;

  List<ChatMessage> _parse(Object? data) {
    return [for (final row in data as List) ChatMessage.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<List<ChatMessage>> fetchMessages() async {
    return _parse(await _client.rpc('recent_chat_messages', params: {'p_limit': _historyLimit}));
  }

  @override
  Future<int?> fetchRemaining() async {
    try {
      final response = await _client.functions.invoke(_function, body: {'action': 'status'});
      return (response.data as Map)['remaining'] as int;
    } catch (error) {
      debugPrint('coach-chat status failed: $error');
      return null;
    }
  }

  @override
  Future<ChatSendResult> send({required String message, required String locale, required int utcOffsetMinutes}) async {
    try {
      final response = await _client.functions.invoke(
        _function,
        body: {'message': message, 'locale': locale, 'utc_offset_minutes': utcOffsetMinutes},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return ChatSendResult(messages: _parse(data['messages']), remaining: data['remaining'] as int);
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['code'] as String? : null;
      debugPrint('coach-chat send failed: ${error.status} $code');
      throw ChatSendException(switch (code) {
        'DAILY_LIMIT' => ChatSendError.dailyLimit,
        'LLM_QUOTA' => ChatSendError.busy,
        _ => ChatSendError.unavailable,
      });
    } catch (error) {
      debugPrint('coach-chat send failed: $error');
      throw const ChatSendException(ChatSendError.unavailable);
    }
  }

  @override
  Future<ApplyOutcome> apply(String eventId, Map<String, dynamic> extras) async {
    final result = await _client.rpc('apply_chat_action', params: {'p_event_id': eventId, 'p_extras': extras});
    return result == 'stale' ? ApplyOutcome.stale : ApplyOutcome.applied;
  }

  @override
  Future<void> cancel(String eventId) async {
    await _client.rpc('cancel_chat_action', params: {'p_event_id': eventId});
  }

  @override
  Future<UndoOutcome> undo(String eventId) async {
    final result = await _client.rpc('undo_chat_action', params: {'p_event_id': eventId});
    return result == 'modified' ? UndoOutcome.modified : UndoOutcome.undone;
  }

  @override
  Future<void> clear() async {
    await _client.rpc('clear_chat');
  }
}
```

- [ ] **Step 2: Provider ve yenilemeyi yaz**

`lib/features/chat/application/chat_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(AppSupabase.client);
});
```

`lib/features/chat/application/chat_refresh.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/application/today_meals_provider.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/session_notifier.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../domain/chat_models.dart';

/// Sohbetten uygulanan / geri alınan bir değişiklikten sonra etkilenen
/// ekranların verisini yeniler (spec §5.4).
void refreshAfterChatChange(Ref ref, ChatEvent event) {
  switch (event.tool) {
    case ChatTool.logBodyWeight:
      ref
        ..invalidate(weightLogsProvider)
        ..invalidate(profileProvider);
    case ChatTool.updateProfile || ChatTool.setGoal:
      ref.invalidate(profileProvider);
    case ChatTool.createMeal:
      ref
        ..invalidate(todayMealsProvider)
        ..invalidate(weeklyMealsProvider);
    case ChatTool.logSet:
      ref
        ..invalidate(inProgressSessionProvider)
        ..invalidate(sessionNotifierProvider(event.payload['session_id'] as String));
    case ChatTool.editProgram:
      ref
        ..invalidate(programsProvider)
        ..invalidate(programDetailProvider(event.payload['program_id'] as String));
  }
}
```

- [ ] **Step 3: Fake depoyu yaz**

`test/features/chat/fakes.dart`:

```dart
import 'dart:async';

import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({List<ChatMessage>? messages, this.remaining = 30}) : messages = [...?messages];

  final List<ChatMessage> messages;
  int? remaining;

  final List<({String message, String locale, int utcOffsetMinutes})> sent = [];
  final List<({String eventId, Map<String, dynamic> extras})> applied = [];
  final List<String> cancelled = [];
  final List<String> undone = [];
  int clearCount = 0;

  /// Doluysa fetchMessages bu hatayı fırlatır.
  Object? loadError;

  /// Doluysa send bu hatayı fırlatır.
  ChatSendException? sendError;

  /// Doluysa apply/cancel/undo bu hatayı fırlatır.
  Object? actionError;

  /// Doluysa send bu tamamlanana kadar bekler ("yazıyor" durumunu görmek için).
  Completer<void>? sendGate;

  ApplyOutcome applyOutcome = ApplyOutcome.applied;
  UndoOutcome undoOutcome = UndoOutcome.undone;

  /// Asistan cevabının taşıyacağı öneri.
  ChatEvent? replyEvent;
  String reply = 'Tamam';

  @override
  Future<List<ChatMessage>> fetchMessages() async {
    if (loadError != null) throw loadError!;
    return [...messages];
  }

  @override
  Future<int?> fetchRemaining() async => remaining;

  @override
  Future<ChatSendResult> send({required String message, required String locale, required int utcOffsetMinutes}) async {
    sent.add((message: message, locale: locale, utcOffsetMinutes: utcOffsetMinutes));
    if (sendGate != null) await sendGate!.future;
    if (sendError != null) throw sendError!;
    final n = sent.length;
    final result = [
      ChatMessage(id: 'u$n', role: ChatRole.user, content: message, createdAt: DateTime.utc(2026, 10, 1, 10, n)),
      ChatMessage(
        id: 'a$n',
        role: ChatRole.assistant,
        content: reply,
        createdAt: DateTime.utc(2026, 10, 1, 10, n, 1),
        event: replyEvent,
      ),
    ];
    messages.addAll(result);
    remaining = (remaining ?? 30) - 1;
    return ChatSendResult(messages: result, remaining: remaining!);
  }

  @override
  Future<ApplyOutcome> apply(String eventId, Map<String, dynamic> extras) async {
    if (actionError != null) throw actionError!;
    applied.add((eventId: eventId, extras: extras));
    return applyOutcome;
  }

  @override
  Future<void> cancel(String eventId) async {
    if (actionError != null) throw actionError!;
    cancelled.add(eventId);
  }

  @override
  Future<UndoOutcome> undo(String eventId) async {
    if (actionError != null) throw actionError!;
    undone.add(eventId);
    return undoOutcome;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    messages.clear();
  }
}
```

- [ ] **Step 4: Notifier testlerini yaz**

`test/features/chat/application/chat_notifier_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/application/chat_notifier.dart';
import 'package:spor_takip/features/chat/application/chat_providers.dart';
import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../fakes.dart';
import '../fixtures.dart';

void main() {
  late FakeChatRepository repo;
  late ProviderContainer container;
  late int weightFetches;

  setUp(() {
    weightFetches = 0;
    repo = FakeChatRepository(messages: [userMessage('kilom 82'), assistantMessage(weightEvent())], remaining: 12);
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      chatRepositoryProvider.overrideWithValue(repo),
      // UTC "şimdi": saat farkı makineden bağımsız 0 olur.
      nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 9)),
      profileProvider.overrideWith((ref) async => testProfile),
      weightLogsProvider.overrideWith((ref) async {
        weightFetches++;
        return const <BodyWeightLog>[];
      }),
    ]);
    addTearDown(container.dispose);
  });

  Future<ChatNotifier> ready() async {
    container.listen(chatNotifierProvider, (_, _) {});
    await container.read(chatNotifierProvider.future);
    return container.read(chatNotifierProvider.notifier);
  }

  ChatState current() => container.read(chatNotifierProvider).requireValue;

  test('loads the history and the remaining quota', () async {
    await ready();
    expect(current().messages.map((m) => m.id), ['u1', 'a1']);
    expect(current().remaining, 12);
    expect(current().sending, isFalse);
  });

  test('send appends the saved exchange and updates the quota', () async {
    final notifier = await ready();
    await notifier.send('  Bugün ne yemeliyim? ', locale: 'tr');

    expect(repo.sent.single, (message: 'Bugün ne yemeliyim?', locale: 'tr', utcOffsetMinutes: 0));
    expect(current().messages.map((m) => m.content).toList().sublist(2), ['Bugün ne yemeliyim?', 'Tamam']);
    expect(current().remaining, 11);
    expect(current().unsentText, isNull);
    expect(current().sendError, isNull);
  });

  test('send ignores blank text', () async {
    final notifier = await ready();
    await notifier.send('   ', locale: 'tr');
    expect(repo.sent, isEmpty);
  });

  test('a failed send keeps the text for retry; daily limit zeroes the quota', () async {
    final notifier = await ready();
    repo.sendError = const ChatSendException(ChatSendError.dailyLimit);
    await notifier.send('selam', locale: 'tr');

    expect(current().messages.length, 2);
    expect(current().unsentText, 'selam');
    expect(current().sendError, ChatSendError.dailyLimit);
    expect(current().remaining, 0);

    repo.sendError = null;
    await notifier.retry(locale: 'en');
    expect(repo.sent.last.message, 'selam');
    expect(repo.sent.last.locale, 'en');
    expect(current().unsentText, isNull);
    expect(current().messages.length, 4);
  });

  test('a busy error keeps the known quota', () async {
    final notifier = await ready();
    repo.sendError = const ChatSendException(ChatSendError.busy);
    await notifier.send('selam', locale: 'tr');
    expect(current().sendError, ChatSendError.busy);
    expect(current().remaining, 12);
  });

  test('apply forwards extras, marks the event applied and refreshes weight logs', () async {
    final notifier = await ready();
    container.listen(weightLogsProvider, (_, _) {});
    await container.read(weightLogsProvider.future);
    expect(weightFetches, 1);

    final outcome = await notifier.apply(weightEvent(), {'calorie_target': 2800, 'protein_target': 180});

    expect(outcome, ApplyOutcome.applied);
    expect(repo.applied.single, (eventId: 'e-weight', extras: {'calorie_target': 2800, 'protein_target': 180}));
    expect(current().messages.last.event!.status, ChatEventStatus.applied);
    await container.read(weightLogsProvider.future);
    expect(weightFetches, 2);
  });

  test('a stale apply marks the event stale and refreshes nothing', () async {
    final notifier = await ready();
    container.listen(weightLogsProvider, (_, _) {});
    await container.read(weightLogsProvider.future);
    repo.applyOutcome = ApplyOutcome.stale;

    expect(await notifier.apply(weightEvent(), const {}), ApplyOutcome.stale);
    expect(current().messages.last.event!.status, ChatEventStatus.stale);
    await container.read(weightLogsProvider.future);
    expect(weightFetches, 1);
  });

  test('cancel marks the event cancelled', () async {
    final notifier = await ready();
    await notifier.cancel(weightEvent());
    expect(repo.cancelled, ['e-weight']);
    expect(current().messages.last.event!.status, ChatEventStatus.cancelled);
  });

  test('undo marks the event undone; a modified undo leaves it applied', () async {
    final notifier = await ready();
    final applied = weightEvent(status: ChatEventStatus.applied);

    repo.undoOutcome = UndoOutcome.modified;
    expect(await notifier.undo(applied), UndoOutcome.modified);
    expect(current().messages.last.event!.status, ChatEventStatus.pending);

    repo.undoOutcome = UndoOutcome.undone;
    expect(await notifier.undo(applied), UndoOutcome.undone);
    expect(current().messages.last.event!.status, ChatEventStatus.undone);
  });

  test('clear empties the chat but keeps the quota', () async {
    final notifier = await ready();
    await notifier.clear();
    expect(repo.clearCount, 1);
    expect(current().messages, isEmpty);
    expect(current().remaining, 12);
  });
}
```

Not: "modified" testinde mesajdaki olay `pending` kalır, çünkü fixture'daki mesaj `pending` durumla yüklenmiştir ve `modified` hiçbir şeyi değiştirmez.

- [ ] **Step 5: Başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/chat/application/chat_notifier_test.dart`
Expected: FAIL — `chat_notifier.dart` bulunamıyor.

- [ ] **Step 6: Notifier'ı yaz**

`lib/features/chat/application/chat_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';
import 'chat_refresh.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.sending = false,
    this.unsentText,
    this.sendError,
    this.remaining,
  });

  /// Eskiden yeniye.
  final List<ChatMessage> messages;
  final bool sending;

  /// Gönderilmekte olan veya gönderilemeyen mesaj; başarıda temizlenir.
  final String? unsentText;
  final ChatSendError? sendError;

  /// Son 24 saatte kalan mesaj hakkı; bilinmiyorsa null.
  final int? remaining;
}

final chatNotifierProvider = AsyncNotifierProvider.autoDispose<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends AsyncNotifier<ChatState> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  ChatState get _current => state.requireValue;

  @override
  Future<ChatState> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    final (messages, remaining) = await (repo.fetchMessages(), repo.fetchRemaining()).wait;
    return ChatState(messages: messages, remaining: remaining);
  }

  Future<void> send(String text, {required String locale}) async {
    final message = text.trim();
    final before = _current;
    if (message.isEmpty || before.sending) return;
    state = AsyncData(ChatState(messages: before.messages, sending: true, unsentText: message, remaining: before.remaining));
    try {
      final result = await _repo.send(
        message: message,
        locale: locale,
        utcOffsetMinutes: ref.read(nowProvider)().timeZoneOffset.inMinutes,
      );
      if (!ref.mounted) return;
      state = AsyncData(ChatState(messages: [..._current.messages, ...result.messages], remaining: result.remaining));
    } on ChatSendException catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(ChatState(
        messages: _current.messages,
        unsentText: message,
        sendError: error.error,
        remaining: error.error == ChatSendError.dailyLimit ? 0 : _current.remaining,
      ));
    }
  }

  Future<void> retry({required String locale}) async {
    final text = _current.unsentText;
    if (text != null) await send(text, locale: locale);
  }

  Future<ApplyOutcome> apply(ChatEvent event, Map<String, dynamic> extras) async {
    final outcome = await _repo.apply(event.id, extras);
    if (!ref.mounted) return outcome;
    final applied = outcome == ApplyOutcome.applied;
    _replaceEvent(event.withStatus(applied ? ChatEventStatus.applied : ChatEventStatus.stale));
    if (applied) refreshAfterChatChange(ref, event);
    return outcome;
  }

  Future<void> cancel(ChatEvent event) async {
    await _repo.cancel(event.id);
    if (!ref.mounted) return;
    _replaceEvent(event.withStatus(ChatEventStatus.cancelled));
  }

  Future<UndoOutcome> undo(ChatEvent event) async {
    final outcome = await _repo.undo(event.id);
    if (!ref.mounted || outcome == UndoOutcome.modified) return outcome;
    _replaceEvent(event.withStatus(ChatEventStatus.undone));
    refreshAfterChatChange(ref, event);
    return outcome;
  }

  Future<void> clear() async {
    await _repo.clear();
    if (!ref.mounted) return;
    state = AsyncData(ChatState(remaining: _current.remaining));
  }

  void _replaceEvent(ChatEvent event) {
    final current = _current;
    state = AsyncData(ChatState(
      messages: [for (final m in current.messages) m.event?.id == event.id ? m.withEvent(event) : m],
      sending: current.sending,
      unsentText: current.unsentText,
      sendError: current.sendError,
      remaining: current.remaining,
    ));
  }
}
```

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/chat/`
Expected: PASS.

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/chat/data lib/features/chat/application test/features/chat/fakes.dart test/features/chat/application
git commit -m "feat(coach): add chat repository, notifier and post-change refresh"
```

---
### Task 11: Onay kartları

**Files:**
- Create: `lib/features/chat/presentation/widgets/card_bodies.dart`
- Create: `lib/features/chat/presentation/widgets/confirm_card.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`coach.card`, `coach.field`)
- Test: `test/features/chat/presentation/confirm_card_test.dart`

**Interfaces:**
- Consumes: Task 9 kart verisi fonksiyonları, Task 10 `chatNotifierProvider`, `ChatNotifier.apply/cancel/undo`, `UndoOutcome`, `FakeChatRepository`; mevcut `profileProvider`, `weightLogsProvider`, `nowProvider`, `formatOneDecimal`, `formatShortDate`, `parseDecimal` (`progress_format.dart`); test yardımcıları `testApp`, `initTestLocalization` (`test/features/progress/presentation/test_app.dart`).
- Produces: `class ConfirmCard extends ConsumerStatefulWidget { const ConfirmCard({super.key, required ChatEvent event}); }` (Task 12'de mesaj balonu kullanır). Test anahtarları: `confirm_card_<eventId>`, `card_apply`, `card_cancel`, `card_undo`, `card_applied`, `card_modified`, `card_status_cancelled|undone|stale`, `card_targets`, `card_weight_change`, `card_field_<alan>`, `card_meal_grams_<i>`, `card_meal_macros_<i>`, `card_meal_review_<i>`, `card_meal_total`, `card_set_exercise`, `card_set_value`, `card_program_change_<i>`.

Kart durumu (`ChatEvent.status`) notifier'dan gelir: mesaj balonu yeni olayla kartı yeniden çizer; kartın yerel durumu (meşgul, "sonradan değişti", düzenlenen gramlar) olay id'siyle anahtarlanan state'te kalır.

- [ ] **Step 1: Çevirileri ekle**

```bash
python - <<'EOF'
import json

def merge(path, card, field):
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    coach = data.setdefault('coach', {})
    coach['card'] = card
    coach['field'] = field
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

merge('assets/translations/tr.json', {
    'apply': 'Onayla', 'cancel': 'Vazgeç', 'undo': 'Geri al',
    'applied': 'Uygulandı', 'cancelled': 'Vazgeçildi', 'undone': 'Geri alındı',
    'stale': 'Veri bu arada değişti, tekrar iste',
    'modified': 'Sonradan değişti, geri alınamaz',
    'error': 'İşlem yapılamadı, tekrar dene',
    'new_targets': 'Yeni hedefin: {kcal} kcal, {protein} g protein',
    'needs_review': 'Besin değeri bulunamadı (0 kcal sayılır)',
    'set_number': '{n}. set', 'total': 'Toplam',
}, {
    'height_cm': 'Boy (cm)', 'activity_level': 'Aktivite', 'does_exercise': 'Spor yapıyor',
    'sport_type': 'Spor türü', 'exercise_days_per_week': 'Haftalık spor günü',
    'health_notes': 'Sağlık notları', 'goal': 'Amaç',
})

merge('assets/translations/en.json', {
    'apply': 'Confirm', 'cancel': 'Cancel', 'undo': 'Undo',
    'applied': 'Applied', 'cancelled': 'Cancelled', 'undone': 'Undone',
    'stale': 'Your data changed meanwhile, ask again',
    'modified': "Changed since, can't be undone",
    'error': "Couldn't complete that, try again",
    'new_targets': 'New target: {kcal} kcal, {protein} g protein',
    'needs_review': 'No nutrition data found (counted as 0 kcal)',
    'set_number': 'Set {n}', 'total': 'Total',
}, {
    'height_cm': 'Height (cm)', 'activity_level': 'Activity', 'does_exercise': 'Exercises',
    'sport_type': 'Sport', 'exercise_days_per_week': 'Training days per week',
    'health_notes': 'Health notes', 'goal': 'Goal',
})
EOF
git diff --stat assets/translations
```

Expected: iki dosyada yalnız ekleme (`coach` bölümü dosyanın sonunda), diğer satırlar değişmemiş.

- [ ] **Step 2: Widget testlerini yaz**

`test/features/chat/presentation/confirm_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/application/chat_notifier.dart';
import 'package:spor_takip/features/chat/application/chat_providers.dart';
import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/card_data.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';
import 'package:spor_takip/features/chat/presentation/widgets/confirm_card.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../fixtures.dart';

/// Kartı notifier'daki son mesajın olayıyla çizer (gerçek balondaki gibi).
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatNotifierProvider).value;
    if (state == null) return const SizedBox();
    final event = state.messages.last.event!;
    return ConfirmCard(key: ValueKey(event.id), event: event);
  }
}

void main() {
  setUpAll(initTestLocalization);

  late FakeChatRepository repo;

  Future<void> pumpCard(WidgetTester tester, ChatEvent event) async {
    repo = FakeChatRepository(messages: [assistantMessage(event)]);
    await tester.pumpWidget(testApp(const _Host(), overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      profileProvider.overrideWith((ref) async => testProfile),
      weightLogsProvider.overrideWith((ref) async => [BodyWeightLog(date: DateTime(2026, 9, 30), weightKg: 80)]),
      nowProvider.overrideWithValue(() => DateTime(2026, 10, 1, 12)),
    ]));
    await tester.pumpAndSettle();
  }

  Text text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key)));

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('weight card shows before → after with new targets and applies them', (tester) async {
    await pumpCard(tester, weightEvent(kg: 82));

    expect(text(tester, 'card_weight_change').data, '80 → 82 kg');
    expect(find.byKey(const Key('card_targets')), findsOneWidget);

    await tapKey(tester, 'card_apply');

    final expected = targetsAfter(testProfile, weightEvent(kg: 82), currentYear: 2026)!;
    expect(repo.applied.single.extras, {
      'calorie_target': expected.calorieTarget,
      'protein_target': expected.proteinTargetG,
    });
    expect(find.byKey(const Key('card_applied')), findsOneWidget);
    expect(find.byKey(const Key('card_undo')), findsOneWidget);
  });

  testWidgets('a past-dated weight hides the targets but still sends them', (tester) async {
    await pumpCard(tester, weightEvent(date: '2026-09-01', kg: 79, logBefore: 81));

    expect(text(tester, 'card_weight_change').data, '81 → 79 kg');
    expect(find.byKey(const Key('card_targets')), findsNothing);

    await tapKey(tester, 'card_apply');
    expect(repo.applied.single.extras.keys, containsAll(['calorie_target', 'protein_target']));
  });

  testWidgets('cancel marks the card cancelled', (tester) async {
    await pumpCard(tester, goalEvent());
    await tapKey(tester, 'card_cancel');

    expect(repo.cancelled, ['e-goal']);
    expect(find.byKey(const Key('card_status_cancelled')), findsOneWidget);
    expect(find.byKey(const Key('card_apply')), findsNothing);
  });

  testWidgets('undo after a later change shows "changed since" and disables undo', (tester) async {
    await pumpCard(tester, weightEvent(status: ChatEventStatus.applied));
    repo.undoOutcome = UndoOutcome.modified;

    await tapKey(tester, 'card_undo');

    expect(find.byKey(const Key('card_modified')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('card_undo'))).onPressed, isNull);
  });

  testWidgets('undo reverts the card to undone', (tester) async {
    await pumpCard(tester, weightEvent(status: ChatEventStatus.applied));
    await tapKey(tester, 'card_undo');

    expect(repo.undone, ['e-weight']);
    expect(find.byKey(const Key('card_status_undone')), findsOneWidget);
  });

  testWidgets('meal card recomputes macros for edited grams and sends them', (tester) async {
    await pumpCard(tester, mealEvent());

    expect(text(tester, 'card_meal_macros_0').data, '330 kcal · P 62 g · C 0 g · F 7.2 g');
    expect(find.byKey(const Key('card_meal_review_1')), findsOneWidget);
    expect(find.byKey(const Key('card_meal_review_0')), findsNothing);

    await tester.enterText(find.byKey(const Key('card_meal_grams_0')), '150');
    await tester.pump();
    expect(text(tester, 'card_meal_macros_0').data, '247.5 kcal · P 46.5 g · C 0 g · F 5.4 g');
    expect(text(tester, 'card_meal_total').data, contains('247.5 kcal'));

    await tapKey(tester, 'card_apply');
    expect(repo.applied.single.extras, {
      'item_grams': [150.0, 200.0],
    });
  });

  testWidgets('invalid grams disable confirm', (tester) async {
    await pumpCard(tester, mealEvent());
    await tester.enterText(find.byKey(const Key('card_meal_grams_1')), '0');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('card_apply'))).onPressed, isNull);
  });

  testWidgets('profile card lists changed fields and sends new targets', (tester) async {
    await pumpCard(tester, profileEvent());

    expect(find.byKey(const Key('card_field_height_cm')), findsOneWidget);
    expect(find.byKey(const Key('card_field_activity_level')), findsOneWidget);
    expect(find.byKey(const Key('card_targets')), findsOneWidget);

    await tapKey(tester, 'card_apply');
    final expected = targetsAfter(testProfile, profileEvent(), currentYear: 2026)!;
    expect(repo.applied.single.extras['calorie_target'], expected.calorieTarget);
  });

  testWidgets('set card shows the exercise and the values', (tester) async {
    await pumpCard(tester, setEvent());
    expect(text(tester, 'card_set_exercise').data, 'Barbell Squat');
    expect(text(tester, 'card_set_value').data, '80 kg × 5');
  });

  testWidgets('program card lists the changes', (tester) async {
    await pumpCard(tester, programEvent());
    expect(text(tester, 'card_program_change_0').data, '+ A: Barbell Deadlift 1×5');
    expect(text(tester, 'card_program_change_1').data, '− A: Barbell Squat');
  });

  testWidgets('stale cards show the stale note without buttons', (tester) async {
    await pumpCard(tester, setEvent(status: ChatEventStatus.stale));
    expect(find.byKey(const Key('card_status_stale')), findsOneWidget);
    expect(find.byKey(const Key('card_apply')), findsNothing);
  });

  testWidgets('a failed action shows a snackbar and keeps the card pending', (tester) async {
    await pumpCard(tester, setEvent());
    repo.actionError = Exception('network');

    await tapKey(tester, 'card_apply');

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('card_apply')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/chat/presentation/confirm_card_test.dart`
Expected: FAIL — `confirm_card.dart` bulunamıyor.

- [ ] **Step 4: Kart gövdelerini yaz**

`lib/features/chat/presentation/widgets/card_bodies.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../onboarding/domain/tdee_calculator.dart';
import '../../../progress/domain/progress_format.dart';
import '../../domain/card_data.dart';
import '../../domain/chat_models.dart';

String _num(num value) => formatOneDecimal(value.toDouble());

String _macros(double kcal, double protein, double carbs, double fat) =>
    '${_num(kcal)} kcal · P ${_num(protein)} g · C ${_num(carbs)} g · F ${_num(fat)} g';

class TargetsLine extends StatelessWidget {
  const TargetsLine({super.key, required this.targets});

  final TdeeResult targets;

  @override
  Widget build(BuildContext context) {
    return Text(
      'coach.card.new_targets'.tr(namedArgs: {
        'kcal': targets.calorieTarget.round().toString(),
        'protein': targets.proteinTargetG.round().toString(),
      }),
      key: const Key('card_targets'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class WeightCardBody extends StatelessWidget {
  const WeightCardBody({super.key, required this.event, this.targets});

  final ChatEvent event;

  /// Yalnız kayıt en yeniyse (profil ve hedefler değişecekse) verilir.
  final TdeeResult? targets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatShortDate(weightDate(event)), style: Theme.of(context).textTheme.bodySmall),
        Text(
          '${_num(weightBefore(event))} → ${_num(weightAfter(event))} kg',
          key: const Key('card_weight_change'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (targets != null) TargetsLine(targets: targets!),
      ],
    );
  }
}

String _fieldValue(String field, Object? value) {
  if (value == null) return '—';
  switch (field) {
    case 'activity_level':
      return 'onboarding.activity_$value'.tr();
    case 'goal':
      return 'onboarding.goal_$value'.tr();
    case 'does_exercise':
      return (value == true ? 'onboarding.yes' : 'onboarding.no').tr();
  }
  return value is num ? _num(value) : value.toString();
}

class ProfileCardBody extends StatelessWidget {
  const ProfileCardBody({super.key, required this.event, this.targets});

  final ChatEvent event;
  final TdeeResult? targets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final change in profileFieldChanges(event))
          Text(
            '${'coach.field.${change.field}'.tr()}: '
            '${_fieldValue(change.field, change.before)} → ${_fieldValue(change.field, change.after)}',
            key: Key('card_field_${change.field}'),
          ),
        if (targets != null) TargetsLine(targets: targets!),
      ],
    );
  }
}

class MealCardBody extends StatelessWidget {
  const MealCardBody({
    super.key,
    required this.mealType,
    required this.items,
    required this.editable,
    required this.onGramsChanged,
  });

  final String mealType;
  final List<MealCardItem> items;
  final bool editable;

  /// Geçersiz girişte gram null gelir.
  final void Function(int index, double? grams) onGramsChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    double sum(double Function(MealCardItem) of) => round1(items.fold(0, (total, item) => total + of(item)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('nutrition.meal_type_$mealType'.tr(), style: textTheme.labelLarge),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(items[i].name)),
                    if (editable)
                      SizedBox(
                        width: 88,
                        child: TextFormField(
                          key: Key('card_meal_grams_$i'),
                          initialValue: _num(items[i].grams),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(isDense: true, suffixText: 'g'),
                          onChanged: (text) {
                            final grams = parseDecimal(text);
                            onGramsChanged(i, grams != null && grams > 0 && grams <= 2000 ? grams : null);
                          },
                        ),
                      )
                    else
                      Text('${_num(items[i].grams)} g'),
                  ],
                ),
                Text(
                  _macros(items[i].calories, items[i].proteinG, items[i].carbsG, items[i].fatG),
                  key: Key('card_meal_macros_$i'),
                  style: textTheme.bodySmall,
                ),
                if (items[i].needsReview)
                  Row(
                    key: Key('card_meal_review_$i'),
                    children: [
                      const Icon(Icons.warning_amber, size: 16),
                      const SizedBox(width: 4),
                      Flexible(child: Text('coach.card.needs_review'.tr(), style: textTheme.bodySmall)),
                    ],
                  ),
              ],
            ),
          ),
        const Divider(height: 12),
        Text(
          '${'coach.card.total'.tr()}: '
          '${_macros(sum((i) => i.calories), sum((i) => i.proteinG), sum((i) => i.carbsG), sum((i) => i.fatG))}',
          key: const Key('card_meal_total'),
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class SetCardBody extends StatelessWidget {
  const SetCardBody({super.key, required this.event});

  final ChatEvent event;

  @override
  Widget build(BuildContext context) {
    final payload = event.payload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(payload['exercise_name'] as String, key: const Key('card_set_exercise')),
        Text('coach.card.set_number'.tr(namedArgs: {'n': '${payload['set_number']}'})),
        Text(
          '${_num(payload['weight_kg'] as num)} kg × ${payload['reps']}',
          key: const Key('card_set_value'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class ProgramCardBody extends StatelessWidget {
  const ProgramCardBody({super.key, required this.event});

  final ChatEvent event;

  @override
  Widget build(BuildContext context) {
    final labels = programChangeLabels(event);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) Text(labels[i], key: Key('card_program_change_$i')),
      ],
    );
  }
}
```

- [ ] **Step 5: Onay kartını yaz**

`lib/features/chat/presentation/widgets/confirm_card.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/application/profile_providers.dart';
import '../../../onboarding/domain/tdee_calculator.dart';
import '../../../progress/application/progress_providers.dart';
import '../../../progress/domain/body_weight_log.dart';
import '../../../workout/application/session_providers.dart';
import '../../application/chat_notifier.dart';
import '../../data/chat_repository.dart';
import '../../domain/card_data.dart';
import '../../domain/chat_models.dart';
import 'card_bodies.dart';

/// Sohbetteki öneri kartı: önce → sonra, Onayla / Vazgeç, Geri al (spec §5.3).
class ConfirmCard extends ConsumerStatefulWidget {
  const ConfirmCard({super.key, required this.event});

  final ChatEvent event;

  @override
  ConsumerState<ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends ConsumerState<ConfirmCard> {
  static const _icons = {
    ChatTool.logBodyWeight: Icons.monitor_weight_outlined,
    ChatTool.updateProfile: Icons.person_outline,
    ChatTool.setGoal: Icons.flag_outlined,
    ChatTool.createMeal: Icons.restaurant_outlined,
    ChatTool.logSet: Icons.fitness_center_outlined,
    ChatTool.editProgram: Icons.edit_note,
  };

  bool _busy = false;
  bool _undoBlocked = false;
  late List<MealCardItem> _mealItems =
      widget.event.tool == ChatTool.createMeal ? mealItems(widget.event) : const [];
  final Set<int> _invalidGrams = {};

  ChatEvent get _event => widget.event;

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final needsTargets = profileTools.contains(event.tool);
    final profile = needsTargets ? ref.watch(profileProvider).value : null;
    final targets = profile == null ? null : targetsAfter(profile, event, currentYear: ref.read(nowProvider)().year);
    final canApply = !_busy && (!needsTargets || targets != null) && _invalidGrams.isEmpty;

    return Card(
      key: Key('confirm_card_${event.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icons[event.tool], size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(event.summary, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            _body(targets),
            const SizedBox(height: 8),
            _footer(canApply, targets),
          ],
        ),
      ),
    );
  }

  Widget _body(TdeeResult? targets) {
    final event = _event;
    switch (event.tool) {
      case ChatTool.logBodyWeight:
        final logs = ref.watch(weightLogsProvider).value ?? const <BodyWeightLog>[];
        return WeightCardBody(event: event, targets: isNewestWeight(event, logs) ? targets : null);
      case ChatTool.updateProfile || ChatTool.setGoal:
        return ProfileCardBody(event: event, targets: targets);
      case ChatTool.createMeal:
        return MealCardBody(
          mealType: event.payload['meal_type'] as String,
          items: _mealItems,
          editable: event.status == ChatEventStatus.pending,
          onGramsChanged: _onGramsChanged,
        );
      case ChatTool.logSet:
        return SetCardBody(event: event);
      case ChatTool.editProgram:
        return ProgramCardBody(event: event);
    }
  }

  void _onGramsChanged(int index, double? grams) {
    setState(() {
      if (grams == null) {
        _invalidGrams.add(index);
        return;
      }
      _invalidGrams.remove(index);
      _mealItems = [
        for (var i = 0; i < _mealItems.length; i++) i == index ? _mealItems[i].withGrams(grams) : _mealItems[i],
      ];
    });
  }

  Widget _footer(bool canApply, TdeeResult? targets) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    switch (_event.status) {
      case ChatEventStatus.pending:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const Key('card_cancel'),
              onPressed: _busy ? null : _cancel,
              child: Text('coach.card.cancel'.tr()),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('card_apply'),
              onPressed: canApply ? () => _apply(targets) : null,
              child: Text('coach.card.apply'.tr()),
            ),
          ],
        );
      case ChatEventStatus.applied:
        return Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: _undoBlocked
                  ? Text('coach.card.modified'.tr(), key: const Key('card_modified'), style: muted)
                  : Text('coach.card.applied'.tr(), key: const Key('card_applied')),
            ),
            TextButton(
              key: const Key('card_undo'),
              onPressed: _busy || _undoBlocked ? null : _undo,
              child: Text('coach.card.undo'.tr()),
            ),
          ],
        );
      case ChatEventStatus.cancelled:
        return Text('coach.card.cancelled'.tr(), key: const Key('card_status_cancelled'), style: muted);
      case ChatEventStatus.undone:
        return Text('coach.card.undone'.tr(), key: const Key('card_status_undone'), style: muted);
      case ChatEventStatus.stale:
        return Text('coach.card.stale'.tr(), key: const Key('card_status_stale'), style: muted);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error, stack) {
      debugPrint('ConfirmCard action failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('coach.card.error'.tr())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(TdeeResult? targets) => _run(() async {
        final extras = applyExtras(
          targets: targets,
          itemGrams: _event.tool == ChatTool.createMeal ? [for (final item in _mealItems) item.grams] : null,
        );
        await ref.read(chatNotifierProvider.notifier).apply(_event, extras);
      });

  Future<void> _cancel() => _run(() => ref.read(chatNotifierProvider.notifier).cancel(_event));

  Future<void> _undo() => _run(() async {
        final outcome = await ref.read(chatNotifierProvider.notifier).undo(_event);
        if (outcome == UndoOutcome.modified && mounted) setState(() => _undoBlocked = true);
      });
}
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/chat/`
Expected: PASS.

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/presentation/widgets/card_bodies.dart lib/features/chat/presentation/widgets/confirm_card.dart assets/translations test/features/chat/presentation/confirm_card_test.dart
git commit -m "feat(coach): add confirm cards with apply, cancel and undo"
```

---

### Task 12: Antrenör sekmesi, sohbet ekranı ve gezinme

**Files:**
- Create: `lib/features/chat/presentation/widgets/message_bubble.dart`
- Create: `lib/features/chat/presentation/coach_screen.dart`
- Modify: `lib/core/app_shell.dart`
- Modify: `lib/core/router.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`nav.coach` + `coach` üst düzey anahtarlar)
- Modify: `test/core/app_shell_test.dart`
- Test: `test/features/chat/presentation/coach_screen_test.dart`

**Interfaces:**
- Consumes: `ConfirmCard` (Task 11), `chatNotifierProvider`, `ChatState`, `ChatSendError` (Task 10), `FakeChatRepository` (Task 10).
- Produces: `class CoachScreen extends ConsumerStatefulWidget { const CoachScreen({super.key}); }`, `class MessageBubble extends StatelessWidget { const MessageBubble({super.key, required ChatMessage message}); }`, rota `/coach` (dördüncü dal). Test anahtarları: `coach_input`, `coach_send`, `coach_typing`, `coach_remaining`, `coach_unsent_text`, `coach_send_error`, `coach_retry`, `coach_suggestion_<i>`, `coach_menu`, `coach_clear`, `coach_clear_confirm`, `coach_reload`, `bubble_<messageId>`.

- [ ] **Step 1: Çevirileri ekle**

```bash
python - <<'EOF'
import json

def merge(path, nav, coach):
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    data['nav']['coach'] = nav
    data.setdefault('coach', {}).update(coach)
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

merge('assets/translations/tr.json', 'Antrenör', {
    'title': 'AI Antrenör',
    'empty': 'Antrenörüne beslenme, antrenman ya da ilerlemenle ilgili her şeyi sorabilirsin.',
    'suggestion_1': 'Bugün ne yemeliyim?',
    'suggestion_2': 'Programımı değerlendir',
    'suggestion_3': 'Kilomu kaydet',
    'input_hint': 'Mesaj yaz…',
    'typing': 'Antrenör yazıyor…',
    'remaining': '{count} mesaj hakkın kaldı',
    'retry': 'Tekrar dene',
    'load_error': 'Sohbet yüklenemedi',
    'error_daily_limit': 'Mesaj hakkın doldu, biraz sonra tekrar dene',
    'error_busy': 'Antrenör şu an çok yoğun, biraz sonra tekrar dene',
    'error_unavailable': 'Gönderilemedi, antrenöre şu an ulaşılamıyor',
    'clear': 'Sohbeti temizle',
    'clear_title': 'Sohbet temizlensin mi?',
    'clear_body': 'Mesajlar silinir. Sohbetten yapılan değişiklikler artık geri alınamaz.',
    'cancel': 'Vazgeç',
})

merge('assets/translations/en.json', 'Coach', {
    'title': 'AI Coach',
    'empty': 'Ask your coach anything about nutrition, training or your progress.',
    'suggestion_1': 'What should I eat today?',
    'suggestion_2': 'Review my program',
    'suggestion_3': 'Log my weight',
    'input_hint': 'Type a message…',
    'typing': 'Coach is typing…',
    'remaining': '{count} messages left',
    'retry': 'Retry',
    'load_error': "Couldn't load the chat",
    'error_daily_limit': "You've used all your messages, try again later",
    'error_busy': 'The coach is very busy right now, try again soon',
    'error_unavailable': "Not sent, the coach can't be reached right now",
    'clear': 'Clear chat',
    'clear_title': 'Clear the chat?',
    'clear_body': 'Messages are deleted. Changes made from the chat can no longer be undone.',
    'cancel': 'Cancel',
})
EOF
git diff --stat assets/translations
```

- [ ] **Step 2: Ekran testlerini yaz**

`test/features/chat/presentation/coach_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/application/chat_providers.dart';
import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';
import 'package:spor_takip/features/chat/presentation/coach_screen.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<FakeChatRepository> pumpScreen(WidgetTester tester, {List<ChatMessage>? messages, int? remaining = 30, Object? loadError}) async {
    final repo = FakeChatRepository(messages: messages, remaining: remaining)..loadError = loadError;
    await tester.pumpWidget(testApp(
      const CoachScreen(),
      scaffold: false,
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) async => testProfile),
        weightLogsProvider.overrideWith((ref) async => const <BodyWeightLog>[]),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 9)),
      ],
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('coach_input')), text);
    await tester.tap(find.byKey(const Key('coach_send')));
  }

  testWidgets('empty chat shows suggestions; tapping one sends it', (tester) async {
    final repo = await pumpScreen(tester);

    expect(find.byKey(const Key('coach_suggestion_0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach_suggestion_0')));
    await tester.pumpAndSettle();

    expect(repo.sent.single.message, isNotEmpty);
    expect(find.byKey(const Key('bubble_u1')), findsOneWidget);
    expect(find.byKey(const Key('bubble_a1')), findsOneWidget);
    expect(find.byKey(const Key('coach_suggestion_0')), findsNothing);
  });

  testWidgets('history shows bubbles and the proposal card', (tester) async {
    await pumpScreen(tester, messages: [userMessage('kilom 82'), assistantMessage(weightEvent())]);

    expect(find.text('kilom 82'), findsOneWidget);
    expect(find.text('Kaydedeyim mi?'), findsOneWidget);
    expect(find.byKey(const Key('confirm_card_e-weight')), findsOneWidget);
  });

  testWidgets('shows a typing indicator while sending and clears the input', (tester) async {
    final repo = await pumpScreen(tester);
    repo.sendGate = Completer<void>();

    await typeAndSend(tester, 'selam');
    await tester.pump();

    expect(find.byKey(const Key('coach_typing')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('coach_input'))).controller!.text, isEmpty);

    repo.sendGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach_typing')), findsNothing);
    expect(find.text('selam'), findsOneWidget);
    expect(repo.sent.single.locale, 'tr');
  });

  testWidgets('a failed message stays with a retry button', (tester) async {
    final repo = await pumpScreen(tester);
    repo.sendError = const ChatSendException(ChatSendError.busy);

    await typeAndSend(tester, 'selam');
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('coach_unsent_text'))).data, 'selam');
    expect(find.byKey(const Key('coach_send_error')), findsOneWidget);

    repo.sendError = null;
    await tester.tap(find.byKey(const Key('coach_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach_unsent_text')), findsNothing);
    expect(find.byKey(const Key('bubble_a2')), findsOneWidget);
  });

  testWidgets('a high remaining quota is not shown', (tester) async {
    await pumpScreen(tester, remaining: 12);
    expect(find.byKey(const Key('coach_remaining')), findsNothing);
  });

  testWidgets('a low remaining quota is shown and input stays enabled', (tester) async {
    await pumpScreen(tester, remaining: 5);
    expect(find.byKey(const Key('coach_remaining')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('coach_input'))).enabled, isTrue);
  });

  testWidgets('no remaining quota locks the input', (tester) async {
    await pumpScreen(tester, remaining: 0);
    expect(tester.widget<TextField>(find.byKey(const Key('coach_input'))).enabled, isFalse);
    expect(tester.widget<IconButton>(find.byKey(const Key('coach_send'))).onPressed, isNull);
  });

  testWidgets('clear chat asks for confirmation and empties the list', (tester) async {
    final repo = await pumpScreen(tester, messages: [userMessage('selam'), assistantMessage(null, content: 'merhaba')]);

    await tester.tap(find.byKey(const Key('coach_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coach_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coach_clear_confirm')));
    await tester.pumpAndSettle();

    expect(repo.clearCount, 1);
    expect(find.text('selam'), findsNothing);
    expect(find.byKey(const Key('coach_suggestion_0')), findsOneWidget);
  });

  testWidgets('a load error offers a reload', (tester) async {
    await pumpScreen(tester, loadError: Exception('offline'));
    expect(find.byKey(const Key('coach_reload')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/chat/presentation/coach_screen_test.dart`
Expected: FAIL — `coach_screen.dart` bulunamıyor.

- [ ] **Step 4: Mesaj balonunu yaz**

`lib/features/chat/presentation/widgets/message_bubble.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/chat_models.dart';
import 'confirm_card.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final scheme = Theme.of(context).colorScheme;
    final event = message.event;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                key: Key('bubble_${message.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(message.content),
              ),
              if (event != null) ConfirmCard(key: ValueKey(event.id), event: event),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Sohbet ekranını yaz**

`lib/features/chat/presentation/coach_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/chat_notifier.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import 'widgets/message_bubble.dart';

const _lowQuotaThreshold = 5;
const _suggestions = ['coach.suggestion_1', 'coach.suggestion_2', 'coach.suggestion_3'];
const _sendErrorKeys = {
  ChatSendError.dailyLimit: 'coach.error_daily_limit',
  ChatSendError.busy: 'coach.error_busy',
  ChatSendError.unavailable: 'coach.error_unavailable',
};

/// Alt menüdeki "Antrenör" sekmesi (spec §5.2).
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _locale => context.locale.languageCode;

  Future<void> _send([String? text]) async {
    final message = (text ?? _controller.text).trim();
    if (message.isEmpty) return;
    _controller.clear();
    await ref.read(chatNotifierProvider.notifier).send(message, locale: _locale);
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('coach.clear_title'.tr()),
        content: Text('coach.clear_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('coach.cancel'.tr())),
          FilledButton(
            key: const Key('coach_clear_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('coach.clear'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(chatNotifierProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('coach.title'.tr()),
        actions: [
          PopupMenuButton<String>(
            key: const Key('coach_menu'),
            onSelected: (_) => _confirmClear(),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'clear', key: const Key('coach_clear'), child: Text('coach.clear'.tr())),
            ],
          ),
        ],
      ),
      body: chat.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('coach.load_error'.tr()),
              TextButton(
                key: const Key('coach_reload'),
                onPressed: () => ref.invalidate(chatNotifierProvider),
                child: Text('coach.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (state) => Column(
          children: [
            Expanded(child: state.messages.isEmpty ? _Suggestions(onTap: _send) : _MessageList(messages: state.messages)),
            if (state.sending)
              Padding(
                key: const Key('coach_typing'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(alignment: Alignment.centerLeft, child: Text('coach.typing'.tr())),
              ),
            if (!state.sending && state.unsentText != null)
              _UnsentRow(state: state, onRetry: () => ref.read(chatNotifierProvider.notifier).retry(locale: _locale)),
            if (state.remaining != null && state.remaining! <= _lowQuotaThreshold)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'coach.remaining'.tr(namedArgs: {'count': '${state.remaining}'}),
                  key: const Key('coach_remaining'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            _InputBar(
              controller: _controller,
              enabled: !state.sending && state.remaining != 0,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    // reverse: en yeni mesaj altta ve görünür kalır.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => MessageBubble(message: messages[messages.length - 1 - index]),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});

  final void Function(String text) onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 48),
            const SizedBox(height: 12),
            Text('coach.empty'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _suggestions.length; i++)
                  ActionChip(
                    key: Key('coach_suggestion_$i'),
                    label: Text(_suggestions[i].tr()),
                    onPressed: () => onTap(_suggestions[i].tr()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsentRow extends StatelessWidget {
  const _UnsentRow({required this.state, required this.onRetry});

  final ChatState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = state.sendError;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.unsentText!, key: const Key('coach_unsent_text'), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (error != null)
                  Text(
                    _sendErrorKeys[error]!.tr(),
                    key: const Key('coach_send_error'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const Key('coach_retry'),
            onPressed: error == ChatSendError.dailyLimit ? null : onRetry,
            child: Text('coach.retry'.tr()),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('coach_input'),
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(hintText: 'coach.input_hint'.tr(), border: const OutlineInputBorder()),
              ),
            ),
            IconButton(
              key: const Key('coach_send'),
              icon: const Icon(Icons.send),
              onPressed: enabled ? onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}
```

Not: `_InputBar.onSend` bir `VoidCallback`; `_send` isteğe bağlı parametreli olduğu için doğrudan verilebilir (`onSend: _send` derleme hatası verirse `onSend: () => _send()` yaz).

- [ ] **Step 6: Sekmeyi ve rotayı ekle**

`lib/core/app_shell.dart` — `destinations` listesinin sonuna:

```dart
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: 'nav.coach'.tr(),
          ),
```

`lib/core/router.dart` — import ekle:

```dart
import '../features/chat/presentation/coach_screen.dart';
```

ve `StatefulShellRoute.indexedStack`'in `branches` listesinin sonuna (antrenman dalından sonra):

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/coach', builder: (context, state) => const CoachScreen()),
            ],
          ),
```

- [ ] **Step 7: Alt menü testini güncelle**

`test/core/app_shell_test.dart` — `buildTestRouter` içindeki `branches` listesine dördüncü dal ekle:

```dart
            StatefulShellBranch(routes: [
              GoRoute(path: '/coach', builder: (context, state) => const Text('COACH_SCREEN')),
            ]),
```

ve dosyanın sonuna (main içinde) test ekle:

```dart
  testWidgets('tapping the coach destination switches to the coach branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();

    expect(find.text('COACH_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });
```

- [ ] **Step 8: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/chat/ test/core/`
Expected: PASS.

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

- [ ] **Step 9: Tam paket**

Run: `flutter test --no-pub`
Expected: `All tests passed!` (F4 sonundaki 277 + bu fazdaki yeni testler).

Run: `deno test supabase/functions/`
Expected: PASS — 85 test.

- [ ] **Step 10: Commit**

```bash
git add lib/features/chat/presentation lib/core/app_shell.dart lib/core/router.dart assets/translations test/core/app_shell_test.dart test/features/chat/presentation/coach_screen_test.dart
git commit -m "feat(coach): add coach tab with chat screen"
```

---

### Task 13: Devreye alma, uçtan uca doğrulama ve günlük

**Files:**
- Modify: `PLAN.md`

Bu görevin 1–4. adımları kullanıcıyla birlikte yapılır (veritabanı ve deploy kullanıcının hesabında).

- [ ] **Step 1: Migration ve kontroller (kullanıcı, SQL Editor)**

1. `supabase/migrations/0010_create_coach_chat.sql` dosyasının tamamını SQL Editor'a yapıştırıp çalıştır (≈20 KB, tek parça yeterli).
2. `supabase/migrations/checks/f5_rls_checks.sql`'i çalıştır. Beklenen hata satırı:

```
SONUC kilo=t profil=t amac=t ogun=t set=t program=t bayat=stale engel=modified tekrar_engellendi=t iptal=t kayit=t B_gorulen=0 B_engellendi=t usage_silinemedi=t temizle=t
```

Farklı bir değer çıkarsa: ilgili fonksiyonu düzelt, migration'daki fonksiyonu `create or replace` ile yeniden çalıştır, kontrolü tekrarla.

- [ ] **Step 2: Edge Function deploy (kullanıcı, kendi PowerShell'i)**

`_shared` klasörünün paketlenmesi için CLI gerekir (Dashboard editörü `../_shared` importlarını paketlemez):

```powershell
cd D:\spor_takip
npx supabase login
npx supabase link --project-ref ieztwbshgxzhyajlbghy
npx supabase functions deploy coach-chat
npx supabase functions deploy analyze-meal-photo
```

İsteğe bağlı secret'lar (varsayılanlar yeterli): `npx supabase secrets set COACH_DAILY_LIMIT=30`. Fonksiyon logunda `SUPABASE_ANON_KEY / COACH_ANON_KEY eksik` görülürse: Dashboard → Settings → API'deki publishable (anon) anahtarı `npx supabase secrets set COACH_ANON_KEY=<anahtar>` ile ver.

- [ ] **Step 3: Release web build**

Run (arka planda, ~10–17 dk): `flutter build web --release --no-pub`
Kullanıcı kendi PowerShell'inde: `cd D:\spor_takip\build\web; python -m http.server 5555 --bind 127.0.0.1` → `http://127.0.0.1:5555` (Ctrl+Shift+R).

- [ ] **Step 4: Manuel kontrol listesi (kullanıcı)**

1. Alt menüde **Antrenör** sekmesi; boş sohbette öneri çipleri. "Bugün ne yemeliyim?" → bugünkü öğünlerine ve hedefine değinen Türkçe cevap.
2. "Bugün kilom 82" → kilo kartı (önce → 82 kg, yeni hedef) → **Onayla** → ✓. Ana sayfada kilo kartı ve hedefler güncellendi. **Geri al** → eski kilo ve hedefler.
3. "Öğlen 200 g tavuk göğsü ve 150 g pilav yedim" → öğün kartı (makrolar dolu). Bir gramı değiştir → makrolar güncelleniyor → **Onayla** → Beslenme sekmesinde öğün var. **Geri al** → öğün silindi.
4. "Amacım kilo vermek" → amaç kartı → **Vazgeç** → kart soluk. Tekrar iste → **Onayla** → hedefler değişti.
5. "Boyum 182" → profil kartı (Boy 180 → 182, yeni hedef) → **Onayla**.
6. Bir antrenman başlat; sohbete "squat 1. set 100 kg 5 tekrar" → set kartı → **Onayla** → antrenman ekranında set yeşil.
7. Kendi programın aktifken "A antrenmanına romanian deadlift ekle" → program kartı (+ satırı) → **Onayla** → program detayında görünüyor → **Geri al** → gitti. Hazır bir program aktifken aynı istek → kart yok, kopyalama önerisi.
8. Bir kilo önerisini onayla, sonra kilo ekranından daha yeni bir tarih için kilo gir → sohbette **Geri al** → "Sonradan değişti, geri alınamaz".
9. Bir kilo önerisini **onaylamadan** kilo ekranından yeni kilo gir → karta dön, **Onayla** → "Veri bu arada değişti, tekrar iste".
10. `npx supabase secrets set COACH_DAILY_LIMIT=3` → 3 cevaptan sonra "N mesaj hakkın kaldı" uyarısı ve yazma alanı kilitli. Sonra `npx supabase secrets unset COACH_DAILY_LIMIT`.
11. Menü → **Sohbeti temizle** → onay → mesajlar gitti; kalan hak aynı kaldı.
12. F2: fotoğraflı öğün analizi hâlâ çalışıyor (yeniden deploy edilen `analyze-meal-photo`).

Bulunan hataları düzelt (TDD: önce başarısız test), ilgili testleri ve tam paketleri yeniden çalıştır.

- [ ] **Step 5: PLAN.md ve commit**

`PLAN.md` Değişiklik Günlüğü tablosuna, doğrulama sonuçlarını gerçek bulgularla yansıtan bir satır ekle (tarih, tamamlanan kapsam, SQL kontrol sonucu, manuel listede bulunan/düzeltilen hatalar, Flutter + Deno test sayıları).

```bash
git add PLAN.md
git commit -m "Document F5 verification"
```
