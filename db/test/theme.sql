begin;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

do $test$
declare
  seeded jsonb;
begin
  select s.theme into strict seeded
  from app.institute_settings s join app.institutes i on i.id = s.institute_id
  where i.slug = 'markaz-al-azeem';
  assert app.valid_theme(seeded), 'The Markaz Al Azeem seed theme is not valid';
  assert app.valid_theme('{}'), 'An empty theme must mean the platform default';

  assert not app.valid_theme('[]');
  assert not app.valid_theme(seeded || '{"logo": "x"}');
  assert not app.valid_theme(seeded || '{"version": 2}');
  assert not app.valid_theme(seeded || '{"direction": "neon"}');
  assert not app.valid_theme(jsonb_set(seeded, '{color,brand}', '"#000000"'));
  assert not app.valid_theme(jsonb_set(seeded, '{color,primary}', '"navy"'));
  assert not app.valid_theme(jsonb_set(seeded, '{color,primary}', '"#0D254D; x"'));
  assert not app.valid_theme(jsonb_set(seeded, '{font,urdu-body}', '"comic-sans"'));
  assert not app.valid_theme(jsonb_set(seeded, '{radius,md}', '2.5'));
  assert not app.valid_theme(jsonb_set(seeded, '{radius,md}', '"8"'));

  begin
    update app.institute_settings set theme = theme || '{"color": {"primary": "red"}}';
    raise exception 'An invalid theme was saved';
  exception when check_violation then
    null;
  end;
end
$test$;

rollback;
