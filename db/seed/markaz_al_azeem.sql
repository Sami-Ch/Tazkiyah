begin;
set local role tazkiyah_schema_owner;

do $seed$
declare
  markaz_id uuid;
  canonical_domain constant text := 'azeem-lateef.com';
begin
  insert into app.institutes (slug) values ('markaz-al-azeem')
  on conflict (slug) do nothing;

  select id into strict markaz_id from app.institutes where slug = 'markaz-al-azeem' for update;

  insert into app.institute_settings (
    institute_id, name, parent_body, theme, address, contact, founded_year, receipt_prefix
  ) values (
    markaz_id,
    '{"en":"Markaz Al Azeem","ur":"مرکز العظیم"}',
    '{"en":"Jama Masjid Al-Azeem","ur":"جامع مسجد العظیم"}',
    '{
      "version": 1,
      "direction": "night-and-paper",
      "color": {
        "bg": "#FAF8F3", "surface": "#FFFFFF", "sunken": "#F1EDE4",
        "text": "#1B2333", "text-muted": "#4F5868", "text-disabled": "#8A909B",
        "primary": "#0D254D", "primary-hover": "#1A3A6E", "on-primary": "#FFFFFF",
        "on-primary-muted": "#C9D6E8", "primary-soft": "#E6ECF5",
        "accent": "#A9CCE8", "link": "#1F5A96", "border": "#D9D4C7",
        "border-strong": "#7A808C", "focus": "#C8691C",
        "success": "#1E6B47", "success-soft": "#E4F1E9",
        "warning": "#8A5300", "warning-soft": "#FBF0DC",
        "danger": "#A8322D", "danger-soft": "#F9E5E3",
        "info": "#1F5A96", "info-soft": "#E6EEF7",
        "zakat": "#1E6B47", "zakat-soft": "#E4F1E9",
        "verified": "#7A5A12", "verified-soft": "#F6EED9", "verified-on-primary": "#D9B25C"
      },
      "font": {"latin-heading":"source-serif-4","urdu-heading":"noto-nastaliq-urdu","urdu-body":"noto-naskh-arabic"},
      "radius": {"sm":4,"md":8,"lg":12}
    }',
    '{"en":"92/6-R Road, Sahiwal, Punjab, Pakistan","ur":"92/6-R روڈ، ساہیوال، پنجاب، پاکستان"}',
    '{"map_url":"https://www.google.com/maps/search/?api=1&query=Jama%20Masjid%20Al-Azeem%2C%2092%2F6-R%20Road%2C%20Sahiwal"}',
    2019,
    'MAA'
  )
  on conflict (institute_id) do nothing;

  insert into app.institute_domains (institute_id, domain, is_primary)
  values (markaz_id, canonical_domain, not exists (
    select 1 from app.institute_domains where institute_id = markaz_id and is_primary
  ))
  on conflict (domain) do nothing;

  if not exists (
    select 1 from app.institute_domains where institute_id = markaz_id and domain = canonical_domain
  ) then
    raise exception 'The Markaz Al Azeem domain already belongs to another institute';
  end if;
end
$seed$;

commit;
