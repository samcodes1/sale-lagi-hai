-- No card numbers in free text (QA 4.7-P1). The app never asks for one,
-- but a report note or a submitted deal's details could carry one ("didn't
-- work with my card 4111 1111 1111 1111"), and moderators read them. A run
-- of 13 to 19 digits that passes the Luhn check is refused: Western, Urdu
-- (Extended Arabic-Indic) or Arabic-Indic digits, with spaces, dots or a
-- dash between the groups (QA 4.9-C1, 4.9-C2). The app checks the same before sending (CardNumbers.find).

-- Whether a digit string passes the Luhn check.
create function private.luhn_ok(digits text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select coalesce(sum(case when (length(digits) - i) % 2 = 1
                           then (substr(digits, i, 1)::int * 2) % 9
                                + case when substr(digits, i, 1) = '9' then 9 else 0 end
                           else substr(digits, i, 1)::int end) % 10 = 0, false)
  from generate_series(1, length(digits)) i;
$$;

-- A run of 13 to 19 digits that passes the Luhn check, as a whole or in
-- its first or last 15 or 16 digits (a card number next to other digits:
-- "ref 99 4111 1111 1111 1111"). Not every window inside the run: that
-- would refuse ordinary long references.
create function private.contains_card_number(input text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select coalesce(bool_or(
           (length(r.digits) between 13 and 19 and private.luhn_ok(r.digits))
           or exists (
             select 1 from unnest(array[15, 16]) n
             where length(r.digits) > n
               and (private.luhn_ok(left(r.digits, n)) or private.luhn_ok(right(r.digits, n))))),
         false)
  from (
    select regexp_replace(m[1], '[^0-9]', '', 'g') as digits
    from regexp_matches(
           translate(coalesce(input, ''), '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'),
           '((?:[0-9](?:[ .]{1,2}| ?- ?)?){12,}[0-9])', 'g') as m
  ) r;
$$;

alter table public.reports
  add constraint reports_note_no_card_number check (not private.contains_card_number(note));
alter table public.submissions
  add constraint submissions_no_card_number
  check (not private.contains_card_number(title) and not private.contains_card_number(details));

grant execute on function private.luhn_ok(text), private.contains_card_number(text)
  to anon, authenticated, service_role;
