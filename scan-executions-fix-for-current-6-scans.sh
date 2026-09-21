# One-off Postgres fixup for the 6 scans that pre-existed the v3.3.7 Phase 5 rewrite (so they
# never got a fresh "Configure AA" run to generate this SQL automatically). Regenerated with the
# v3.3.8 fix: scan_targets INSERT now has ON CONFLICT (scan_id, source_id) DO UPDATE, so re-running
# this script is crash-safe if some/all of these targets already exist — it won't hit
# uq_scan_targets_scan_source and roll back the whole batch. Still not fully idempotent: rerunning
# against scans that already have their executions will add another batch of historical rows rather
# than no-op (scan_executions itself has no uniqueness guard) — check first if that matters.
kubectl exec -i postgres-0 -n access-analyzer -- psql -U postgres -d access_analyzer << 'EOSQL'
BEGIN;

-- Creating scan_targets + 24 scan_executions (1 latest + 3 historical clones each) for 6 scans
-- CloudLab AD - dc01 - Identity Sync
WITH new_target AS (
  INSERT INTO scan_targets (scan_id, source_id, created_at) VALUES ('a50cdb8c-ccee-4040-ad6e-a4c10f924e81','1147918d-d7db-419a-9900-af7846dc82a1',NOW())
  ON CONFLICT (scan_id, source_id) DO UPDATE SET created_at = scan_targets.created_at RETURNING id
)
INSERT INTO scan_executions (scan_id, scan_type, source_id, scan_target_id, status, started_at, completed_at, created_at, updated_at, total_objects, completed_objects, error_details) VALUES
('a50cdb8c-ccee-4040-ad6e-a4c10f924e81','sync','1147918d-d7db-419a-9900-af7846dc82a1',(SELECT id FROM new_target),'completed','2026-09-17 06:57:00','2026-09-17 06:57:12','2026-09-17 06:57:00','2026-09-17 06:57:12',1441,1441,'[]'::jsonb),
('a50cdb8c-ccee-4040-ad6e-a4c10f924e81','sync','1147918d-d7db-419a-9900-af7846dc82a1',(SELECT id FROM new_target),'completed','2026-09-03 06:57:00','2026-09-03 06:57:11','2026-09-03 06:57:00','2026-09-03 06:57:11',1456,1456,'[]'::jsonb),
('a50cdb8c-ccee-4040-ad6e-a4c10f924e81','sync','1147918d-d7db-419a-9900-af7846dc82a1',(SELECT id FROM new_target),'completed','2026-08-20 06:51:00','2026-08-20 06:51:12','2026-08-20 06:51:00','2026-08-20 06:51:12',1397,1397,'[]'::jsonb),
('a50cdb8c-ccee-4040-ad6e-a4c10f924e81','sync','1147918d-d7db-419a-9900-af7846dc82a1',(SELECT id FROM new_target),'completed','2026-08-06 06:10:00','2026-08-06 06:10:14','2026-08-06 06:10:00','2026-08-06 06:10:14',1131,1131,'[]'::jsonb);
-- ACME Entra ID - Sync
WITH new_target AS (
  INSERT INTO scan_targets (scan_id, source_id, created_at) VALUES ('bd8abbbf-fb89-4fb0-b762-92bafce1bf1c','d35c1511-d80c-4d99-b3dd-dcdcc2a3f9cd',NOW())
  ON CONFLICT (scan_id, source_id) DO UPDATE SET created_at = scan_targets.created_at RETURNING id
)
INSERT INTO scan_executions (scan_id, scan_type, source_id, scan_target_id, status, started_at, completed_at, created_at, updated_at, total_objects, completed_objects, error_details) VALUES
('bd8abbbf-fb89-4fb0-b762-92bafce1bf1c','sync','d35c1511-d80c-4d99-b3dd-dcdcc2a3f9cd',(SELECT id FROM new_target),'completed','2026-09-16 07:21:00','2026-09-16 07:21:14','2026-09-16 07:21:00','2026-09-16 07:21:14',1176,1176,'[]'::jsonb),
('bd8abbbf-fb89-4fb0-b762-92bafce1bf1c','sync','d35c1511-d80c-4d99-b3dd-dcdcc2a3f9cd',(SELECT id FROM new_target),'completed','2026-09-02 07:20:00','2026-09-02 07:20:21','2026-09-02 07:20:00','2026-09-02 07:20:21',1169,1169,'[]'::jsonb),
('bd8abbbf-fb89-4fb0-b762-92bafce1bf1c','sync','d35c1511-d80c-4d99-b3dd-dcdcc2a3f9cd',(SELECT id FROM new_target),'completed','2026-08-19 07:44:00','2026-08-19 07:44:19','2026-08-19 07:44:00','2026-08-19 07:44:19',1152,1152,'[]'::jsonb),
('bd8abbbf-fb89-4fb0-b762-92bafce1bf1c','sync','d35c1511-d80c-4d99-b3dd-dcdcc2a3f9cd',(SELECT id FROM new_target),'completed','2026-08-05 07:26:00','2026-08-05 07:26:09','2026-08-05 07:26:00','2026-08-05 07:26:09',968,968,'[]'::jsonb);
-- Windows FS - fs01 - Access Scan
WITH new_target AS (
  INSERT INTO scan_targets (scan_id, source_id, created_at) VALUES ('ba723931-7903-4f13-83bc-f46fd8e51713','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',NOW())
  ON CONFLICT (scan_id, source_id) DO UPDATE SET created_at = scan_targets.created_at RETURNING id
)
INSERT INTO scan_executions (scan_id, scan_type, source_id, scan_target_id, status, started_at, completed_at, created_at, updated_at, total_objects, completed_objects, error_details) VALUES
('ba723931-7903-4f13-83bc-f46fd8e51713','access_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-09-17 08:25:00','2026-09-17 08:25:44','2026-09-17 08:25:00','2026-09-17 08:25:44',5240,5240,'[]'::jsonb),
('ba723931-7903-4f13-83bc-f46fd8e51713','access_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-09-03 08:10:00','2026-09-03 08:10:52','2026-09-03 08:10:00','2026-09-03 08:10:52',4684,4684,'[]'::jsonb),
('ba723931-7903-4f13-83bc-f46fd8e51713','access_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-08-20 08:09:00','2026-08-20 08:10:02','2026-08-20 08:09:00','2026-08-20 08:10:02',4435,4435,'[]'::jsonb),
('ba723931-7903-4f13-83bc-f46fd8e51713','access_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-08-06 08:37:00','2026-08-06 08:37:50','2026-08-06 08:37:00','2026-08-06 08:37:50',4099,4099,'[]'::jsonb);
-- Windows FS - fs01 - Sensitive Data Scan
WITH new_target AS (
  INSERT INTO scan_targets (scan_id, source_id, created_at) VALUES ('45d097af-5ec5-4fcc-8f21-1931c5eee74e','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',NOW())
  ON CONFLICT (scan_id, source_id) DO UPDATE SET created_at = scan_targets.created_at RETURNING id
)
INSERT INTO scan_executions (scan_id, scan_type, source_id, scan_target_id, status, started_at, completed_at, created_at, updated_at, total_objects, completed_objects, error_details) VALUES
('45d097af-5ec5-4fcc-8f21-1931c5eee74e','sensitive_data_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-09-17 09:32:00','2026-09-17 09:37:32','2026-09-17 09:32:00','2026-09-17 09:37:32',3844,3844,'[]'::jsonb),
('45d097af-5ec5-4fcc-8f21-1931c5eee74e','sensitive_data_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-09-03 09:37:00','2026-09-03 09:44:51','2026-09-03 09:37:00','2026-09-03 09:44:51',3818,3818,'[]'::jsonb),
('45d097af-5ec5-4fcc-8f21-1931c5eee74e','sensitive_data_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-08-20 09:07:00','2026-08-20 09:17:51','2026-08-20 09:07:00','2026-08-20 09:17:51',3301,3301,'[]'::jsonb),
('45d097af-5ec5-4fcc-8f21-1931c5eee74e','sensitive_data_scan','1c65ea6c-799b-4926-8bbb-3c19ef63dbf3',(SELECT id FROM new_target),'completed','2026-08-06 09:57:00','2026-08-06 10:03:20','2026-08-06 09:57:00','2026-08-06 10:03:20',3032,3032,'[]'::jsonb);
-- ACME SPO - Access Scan
WITH new_target AS (
  INSERT INTO scan_targets (scan_id, source_id, created_at) VALUES ('b7a18644-8968-4610-a56a-b68d52f87fe6','db5adace-100c-4573-aa28-68d780455b0d',NOW())
  ON CONFLICT (scan_id, source_id) DO UPDATE SET created_at = scan_targets.created_at RETURNING id
)
INSERT INTO scan_executions (scan_id, scan_type, source_id, scan_target_id, status, started_at, completed_at, created_at, updated_at, total_objects, completed_objects, error_details) VALUES
('b7a18644-8968-4610-a56a-b68d52f87fe6','access_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-09-16 10:47:00','2026-09-16 10:48:01','2026-09-16 10:47:00','2026-09-16 10:48:01',5086,5086,'[]'::jsonb),
('b7a18644-8968-4610-a56a-b68d52f87fe6','access_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-09-02 10:49:00','2026-09-02 10:49:35','2026-09-02 10:49:00','2026-09-02 10:49:35',4369,4369,'[]'::jsonb),
('b7a18644-8968-4610-a56a-b68d52f87fe6','access_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-08-19 10:13:00','2026-08-19 10:14:02','2026-08-19 10:13:00','2026-08-19 10:14:02',4218,4218,'[]'::jsonb),
('b7a18644-8968-4610-a56a-b68d52f87fe6','access_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-08-05 10:14:00','2026-08-05 10:14:38','2026-08-05 10:14:00','2026-08-05 10:14:38',4121,4121,'[]'::jsonb);
-- ACME SPO - Sensitive Data Scan
WITH new_target AS (
  INSERT INTO scan_targets (scan_id, source_id, created_at) VALUES ('29feda49-b593-4687-97d8-3edccab255e1','db5adace-100c-4573-aa28-68d780455b0d',NOW())
  ON CONFLICT (scan_id, source_id) DO UPDATE SET created_at = scan_targets.created_at RETURNING id
)
INSERT INTO scan_executions (scan_id, scan_type, source_id, scan_target_id, status, started_at, completed_at, created_at, updated_at, total_objects, completed_objects, error_details) VALUES
('29feda49-b593-4687-97d8-3edccab255e1','sensitive_data_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-09-16 11:30:00','2026-09-16 11:36:33','2026-09-16 11:30:00','2026-09-16 11:36:33',2763,2763,'[]'::jsonb),
('29feda49-b593-4687-97d8-3edccab255e1','sensitive_data_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-09-02 11:54:00','2026-09-02 12:08:04','2026-09-02 11:54:00','2026-09-02 12:08:04',2844,2844,'[]'::jsonb),
('29feda49-b593-4687-97d8-3edccab255e1','sensitive_data_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-08-19 11:08:00','2026-08-19 11:16:14','2026-08-19 11:08:00','2026-08-19 11:16:14',2291,2291,'[]'::jsonb),
('29feda49-b593-4687-97d8-3edccab255e1','sensitive_data_scan','db5adace-100c-4573-aa28-68d780455b0d',(SELECT id FROM new_target),'completed','2026-08-05 11:04:00','2026-08-05 11:09:58','2026-08-05 11:04:00','2026-08-05 11:09:58',2567,2567,'[]'::jsonb);
COMMIT;
EOSQL
