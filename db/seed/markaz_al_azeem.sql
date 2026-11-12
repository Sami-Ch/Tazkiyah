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

  -- The principal reviews the illustrative targets and Zakat eligibility before publishing.
  insert into app.causes (
    institute_id, slug, cause_type, title, summary, target_paisa, target_period,
    stock_year_start_month, receipt_public_by_default, display_order
  )
  select markaz_id, draft.slug,
    case when draft.stock_month is null then 'ongoing' else 'yearly_stock' end,
    jsonb_build_object('en', draft.title_en, 'ur', draft.title_ur),
    jsonb_build_object('en', draft.summary_en, 'ur', draft.summary_ur),
    draft.target_rupees::bigint * 100,
    case when draft.stock_month is null then 'monthly' end,
    draft.stock_month, draft.public_receipt, draft.sort_order
  from (values
    ('wheat-stock', 'Wheat stock', 'گندم کا ذخیرہ',
      'Bulk wheat purchases for the madrasa’s kitchen.', 'مدرسے کے باورچی خانے کے لیے گندم کی تھوک خریداری۔',
      500000, 3, true, 1),
    ('kitchen-gas', 'Kitchen gas', 'باورچی خانے کی گیس',
      'Cooking gas for daily meals.', 'روزانہ کھانا پکانے کے لیے گیس۔', 30000, null, true, 2),
    ('electricity', 'Electricity', 'بجلی',
      'Monthly electricity bills for the madrasa.', 'مدرسے کے ماہانہ بجلی کے بل۔', 40000, null, true, 3),
    ('teacher-salaries', 'Teacher salaries', 'اساتذہ کی تنخواہیں',
      'Monthly salaries for teachers.', 'اساتذہ کی ماہانہ تنخواہیں۔', 250000, null, false, 4),
    ('pharmacy', 'Pharmacy (medicines)', 'دواخانہ',
      'Medicines for the clinic.', 'کلینک کے لیے ادویات۔', 50000, null, false, 5),
    ('clinic', 'Clinic', 'کلینک',
      'The clinic’s running costs and equipment.', 'کلینک کے جاری اخراجات اور آلات۔', null, null, false, 6),
    ('orphan-sponsorship', 'Orphan sponsorship', 'یتیم بچوں کی کفالت',
      'Shared support for meals, clothes and books.', 'کھانے، کپڑوں اور کتابوں کے لیے مشترکہ معاونت۔',
      40000, null, false, 7)
  ) as draft(slug, title_en, title_ur, summary_en, summary_ur, target_rupees, stock_month, public_receipt, sort_order)
  on conflict (institute_id, slug) do nothing;
end
$seed$;

commit;
