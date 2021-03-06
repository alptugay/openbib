SELECT setval('person_fields_id_seq', (SELECT MAX(id) FROM person_fields));
SELECT setval('corporatebody_fields_id_seq', (SELECT MAX(id) FROM corporatebody_fields));
SELECT setval('subject_fields_id_seq', (SELECT MAX(id) FROM subject_fields));
SELECT setval('classification_fields_id_seq', (SELECT MAX(id) FROM classification_fields));
SELECT setval('title_fields_id_seq', (SELECT MAX(id) FROM title_fields));
SELECT setval('holding_fields_id_seq', (SELECT MAX(id) FROM holding_fields));
SELECT setval('title_title_id_seq', (SELECT MAX(id) FROM title_title));
SELECT setval('title_person_id_seq', (SELECT MAX(id) FROM title_person));
SELECT setval('title_corporatebody_id_seq', (SELECT MAX(id) FROM title_corporatebody));
SELECT setval('title_subject_id_seq', (SELECT MAX(id) FROM title_subject));
SELECT setval('title_classification_id_seq', (SELECT MAX(id) FROM title_classification));
SELECT setval('title_holding_id_seq', (SELECT MAX(id) FROM title_holding));
