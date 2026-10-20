-- =====================================================================
-- MUT-Verify : Oracle Autonomous Database schema (demo)
-- Run in: Database Actions -> SQL  (logged in as your MUTV user, NOT ADMIN)
-- NOTE: written for Oracle 19c/21c/23ai syntax. I could not run it against a live
-- Oracle database while preparing this zip, so expect to fix small typos on first run.
-- ALL DATA BELOW IS FAKE. Never load real student data into the demo.
-- =====================================================================

-- ---------- Core tables ----------
CREATE TABLE mv_students (
  student_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reg_no       VARCHAR2(40)  NOT NULL UNIQUE,
  full_name    VARCHAR2(120) NOT NULL,
  program      VARCHAR2(120) NOT NULL,
  email        VARCHAR2(120),
  phone        VARCHAR2(30)
);

CREATE TABLE mv_offices (
  office_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  office_code  VARCHAR2(20)  NOT NULL UNIQUE,
  office_name  VARCHAR2(80)  NOT NULL,
  seq_no       NUMBER NOT NULL            -- order in which offices sign (informational)
);

CREATE TABLE mv_clearance_requests (
  request_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id   NUMBER NOT NULL REFERENCES mv_students(student_id),
  status       VARCHAR2(20) DEFAULT 'IN_PROGRESS' NOT NULL
               CHECK (status IN ('IN_PROGRESS','CLEARED','REJECTED','ISSUED')),
  created_at   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at TIMESTAMP
);

CREATE TABLE mv_clearance_steps (
  step_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id   NUMBER NOT NULL REFERENCES mv_clearance_requests(request_id),
  office_id    NUMBER NOT NULL REFERENCES mv_offices(office_id),
  status       VARCHAR2(20) DEFAULT 'PENDING' NOT NULL
               CHECK (status IN ('PENDING','CLEARED','REJECTED')),
  auto_checked CHAR(1) DEFAULT 'N' NOT NULL,   -- 'Y' when the system cleared it automatically
  decided_by   VARCHAR2(120),
  decided_at   TIMESTAMP,
  remarks      VARCHAR2(400),
  CONSTRAINT uq_step UNIQUE (request_id, office_id)
);

CREATE TABLE mv_documents (
  doc_id       VARCHAR2(36)  PRIMARY KEY,          -- same UUID that is printed on the certificate
  request_id   NUMBER REFERENCES mv_clearance_requests(request_id),
  doc_type     VARCHAR2(20)  NOT NULL,
  doc_hash     VARCHAR2(66)  NOT NULL UNIQUE,      -- 0x + 64 hex  (the fingerprint on the blockchain)
  tx_hash      VARCHAR2(66),
  explorer_url VARCHAR2(300),
  status       VARCHAR2(10)  DEFAULT 'ISSUED' NOT NULL CHECK (status IN ('ISSUED','REVOKED')),
  issued_at    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  revoked_at   TIMESTAMP,
  pdf          BLOB
);

-- Demo stand-in for the real finance/library/hostel data (so we can show AUTO-clearance)
CREATE TABLE mv_fee_balance (
  student_id   NUMBER PRIMARY KEY REFERENCES mv_students(student_id),
  balance_kes  NUMBER DEFAULT 0 NOT NULL
);
CREATE TABLE mv_library_loans (
  loan_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id   NUMBER NOT NULL REFERENCES mv_students(student_id),
  book_title   VARCHAR2(200),
  returned     CHAR(1) DEFAULT 'N' NOT NULL
);

-- Everything that matters gets written here (who did what, when) - answers "who approved this?"
CREATE TABLE mv_audit_log (
  log_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  at_time      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  actor        VARCHAR2(120),
  action       VARCHAR2(60),
  detail       VARCHAR2(1000)
);

-- ---------- Fake demo data ----------
INSERT INTO mv_offices (office_code, office_name, seq_no) VALUES ('LIBRARY',    'Library',            1);
INSERT INTO mv_offices (office_code, office_name, seq_no) VALUES ('FINANCE',    'Finance',            2);
INSERT INTO mv_offices (office_code, office_name, seq_no) VALUES ('HOSTELS',    'Hostels',            3);
INSERT INTO mv_offices (office_code, office_name, seq_no) VALUES ('DEPARTMENT', 'Department (HOD)',   4);
INSERT INTO mv_offices (office_code, office_name, seq_no) VALUES ('DEAN',       'Dean of School',     5);

INSERT INTO mv_students (reg_no, full_name, program, email) VALUES ('DEMO/0001/2021', 'Jane Wanjiru', 'BSc Medical Laboratory Sciences', 'jane.demo@example.com');
INSERT INTO mv_students (reg_no, full_name, program, email) VALUES ('DEMO/0002/2021', 'Peter Kamau',  'BSc Medical Laboratory Sciences', 'peter.demo@example.com');
INSERT INTO mv_students (reg_no, full_name, program, email) VALUES ('DEMO/0003/2021', 'Amina Hassan', 'BSc Nursing',                      'amina.demo@example.com');

INSERT INTO mv_fee_balance (student_id, balance_kes) SELECT student_id, 0     FROM mv_students WHERE reg_no = 'DEMO/0001/2021';
INSERT INTO mv_fee_balance (student_id, balance_kes) SELECT student_id, 12500 FROM mv_students WHERE reg_no = 'DEMO/0002/2021';  -- owes fees -> finance will NOT auto-clear
INSERT INTO mv_fee_balance (student_id, balance_kes) SELECT student_id, 0     FROM mv_students WHERE reg_no = 'DEMO/0003/2021';
INSERT INTO mv_library_loans (student_id, book_title, returned) SELECT student_id, 'Clinical Chemistry', 'N' FROM mv_students WHERE reg_no = 'DEMO/0003/2021'; -- unreturned book -> library will NOT auto-clear
COMMIT;

-- ---------- The automation: create a request and auto-clear what the system can check ----------
CREATE OR REPLACE PROCEDURE mv_request_clearance (
  p_student_id IN  NUMBER,
  p_request_id OUT NUMBER
) AS
  l_bal   NUMBER;
  l_open  NUMBER;
BEGIN
  INSERT INTO mv_clearance_requests (student_id) VALUES (p_student_id)
    RETURNING request_id INTO p_request_id;

  -- one pending step per office
  INSERT INTO mv_clearance_steps (request_id, office_id)
    SELECT p_request_id, office_id FROM mv_offices;

  -- AUTO-CHECK 1: Finance clears itself when the fee balance is zero
  SELECT NVL(MAX(balance_kes), 0) INTO l_bal FROM mv_fee_balance WHERE student_id = p_student_id;
  IF l_bal = 0 THEN
    UPDATE mv_clearance_steps SET status='CLEARED', auto_checked='Y', decided_by='SYSTEM',
           decided_at=SYSTIMESTAMP, remarks='Fee balance is zero'
     WHERE request_id = p_request_id
       AND office_id = (SELECT office_id FROM mv_offices WHERE office_code='FINANCE');
  END IF;

  -- AUTO-CHECK 2: Library clears itself when there are no unreturned books
  SELECT COUNT(*) INTO l_open FROM mv_library_loans WHERE student_id = p_student_id AND returned = 'N';
  IF l_open = 0 THEN
    UPDATE mv_clearance_steps SET status='CLEARED', auto_checked='Y', decided_by='SYSTEM',
           decided_at=SYSTIMESTAMP, remarks='No unreturned books'
     WHERE request_id = p_request_id
       AND office_id = (SELECT office_id FROM mv_offices WHERE office_code='LIBRARY');
  END IF;

  INSERT INTO mv_audit_log (actor, action, detail)
    VALUES ('SYSTEM', 'REQUEST_CREATED', 'request_id=' || p_request_id || ' student_id=' || p_student_id);
END;
/

-- ---------- Office decision (APEX approve/reject buttons call this) ----------
CREATE OR REPLACE PROCEDURE mv_decide_step (
  p_step_id   IN NUMBER,
  p_decision  IN VARCHAR2,          -- 'CLEARED' or 'REJECTED'
  p_actor     IN VARCHAR2,          -- APEX passes :APP_USER
  p_remarks   IN VARCHAR2 DEFAULT NULL
) AS
  l_req NUMBER;
BEGIN
  IF p_decision NOT IN ('CLEARED','REJECTED') THEN
    RAISE_APPLICATION_ERROR(-20010, 'Decision must be CLEARED or REJECTED');
  END IF;

  UPDATE mv_clearance_steps
     SET status = p_decision, decided_by = p_actor, decided_at = SYSTIMESTAMP, remarks = p_remarks
   WHERE step_id = p_step_id
  RETURNING request_id INTO l_req;

  INSERT INTO mv_audit_log (actor, action, detail)
    VALUES (p_actor, 'STEP_' || p_decision, 'step_id=' || p_step_id || ' request_id=' || l_req);

  -- Are all offices cleared now?
  UPDATE mv_clearance_requests r
     SET status = 'CLEARED', completed_at = SYSTIMESTAMP
   WHERE r.request_id = l_req
     AND NOT EXISTS (SELECT 1 FROM mv_clearance_steps s WHERE s.request_id = r.request_id AND s.status <> 'CLEARED');
  -- (When status becomes CLEARED, the APEX process calls mv_issue_certificate - see 02_issue_procedure.sql)
END;
/

-- ---------- Handy view for the "office queue" page in APEX ----------
CREATE OR REPLACE VIEW mv_office_queue_v AS
SELECT s.step_id, s.request_id, o.office_code, o.office_name, st.reg_no, st.full_name,
       s.status, s.auto_checked, s.remarks, r.created_at
  FROM mv_clearance_steps s
  JOIN mv_offices o ON o.office_id = s.office_id
  JOIN mv_clearance_requests r ON r.request_id = s.request_id
  JOIN mv_students st ON st.student_id = r.student_id;
