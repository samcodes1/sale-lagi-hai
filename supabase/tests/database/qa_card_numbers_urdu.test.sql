-- QA (sub-phase 4.9 gate): the database's card-number rule against the
-- ways a shopper on an Urdu phone types one (4.9-C1, 4.9-C2). The client's
-- CardNumbers mirrors this rule. Fixed after the 4.9 gate.
begin;
select plan(6);

select ok(private.contains_card_number('4111 1111 1111 1111'), 'control: Western digits are caught');
select ok(not private.contains_card_number('کال کریں ۰۳۰۰ ۱۲۳۴۵۶۷'), 'an Urdu-digit phone number is fine');

select ok(private.contains_card_number('۴۱۱۱ ۱۱۱۱ ۱۱۱۱ ۱۱۱۱'), 'Urdu (Extended Arabic-Indic) digits');
select ok(private.contains_card_number('٤١١١١١١١١١١١١١١١'), 'Arabic-Indic digits');
select ok(private.contains_card_number('4111.1111.1111.1111'), 'dots between groups');
select ok(private.contains_card_number('4111  1111  1111  1111'), 'two spaces between groups');

select * from finish();
rollback;
