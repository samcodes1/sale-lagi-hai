-- No card numbers in free text (QA 4.7-P1).
begin;
select plan(9);

select ok(private.contains_card_number('my card 4111 1111 1111 1111 failed'), 'a Visa test number with spaces');
select ok(private.contains_card_number('5500-0000-0000-0004'), 'a Mastercard test number with dashes');
select ok(private.contains_card_number('ref 99 4111111111111111'), 'inside other text');
select ok(not private.contains_card_number('call 0300 1234567'), 'a phone number is fine');
select ok(not private.contains_card_number('order 1234567890123'), 'a long number that fails the Luhn check is fine');
select ok(not private.contains_card_number(null), 'no text, no number');
select ok(private.contains_card_number('378282246310005'), 'an Amex test number (15 digits)');
select ok(not private.contains_card_number('tracking 1Z 9999 9999 9999 9999 991'), 'a long reference is not refused for a window inside it');

create temp table w as select * from tests.make_world();
grant select on w to authenticated;
select tests.authenticate_as((select shopper from w));
select throws_ok($$ insert into public.reports (deal_id, reason, note)
                    select live_a, 'other', 'card 4111 1111 1111 1111' from w $$,
  '23514', null, 'a report note with a card number is refused');
select tests.clear_authentication();

select * from finish();
rollback;
