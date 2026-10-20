-- =====================================================================
-- MUT-Verify : the bridge from Oracle/APEX to the anchor service (the Node app on your OCI VM)
-- Run AFTER 01_schema.sql, as your MUTV user.
-- NOT TESTED against a live Oracle DB (I had none available) - treat as a solid first draft.
--
-- BEFORE this works you must:
--  1) Have the anchor service running on a PUBLIC HTTPS address with a trusted certificate
--     (Autonomous DB refuses plain http and self-signed certs). See docs/ORACLE-GUIDE.md section 5.
--  2) In APEX:  App Builder -> Workspace Utilities -> Web Credentials -> Create
--       Name / Static ID : MUT_ANCHOR_KEY
--       Authentication   : HTTP Header   (if your APEX version does not offer it, see the fallback note below)
--       Header name      : x-api-key
--       Header value     : (the API_KEY from anchor-service/.env)
--  3) Replace YOUR-DOMAIN below.
--
-- FALLBACK if Web Credentials of type "HTTP Header" is unavailable:
--   remove p_credential_static_id and instead add
--       apex_web_service.g_request_headers(2).name  := 'x-api-key';
--       apex_web_service.g_request_headers(2).value := '<your key>';
--   (works, but then the key sits in your code - fine for a demo, not for production).
-- =====================================================================

CREATE OR REPLACE PROCEDURE mv_issue_certificate (
  p_request_id IN NUMBER
) AS
  l_url      CONSTANT VARCHAR2(300) := 'https://YOUR-DOMAIN/issue';
  l_pending  NUMBER;
  l_reg      mv_students.reg_no%TYPE;
  l_name     mv_students.full_name%TYPE;
  l_prog     mv_students.program%TYPE;
  l_existing NUMBER;
  l_body     CLOB;
  l_resp     CLOB;
  l_json     JSON_OBJECT_T;
  l_pdf      BLOB;
  l_approvals CLOB;
BEGIN
  -- Safety 1: never issue unless EVERY office has cleared
  SELECT COUNT(*) INTO l_pending
    FROM mv_clearance_steps WHERE request_id = p_request_id AND status <> 'CLEARED';
  IF l_pending > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Cannot issue: ' || l_pending || ' office(s) have not cleared this request.');
  END IF;

  -- Safety 2: never issue twice for the same request
  SELECT COUNT(*) INTO l_existing FROM mv_documents WHERE request_id = p_request_id AND status = 'ISSUED';
  IF l_existing > 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'A certificate was already issued for this request.');
  END IF;

  SELECT st.reg_no, st.full_name, st.program
    INTO l_reg, l_name, l_prog
    FROM mv_clearance_requests r JOIN mv_students st ON st.student_id = r.student_id
   WHERE r.request_id = p_request_id;

  -- Build the list of offices that cleared the student (printed on the certificate)
  SELECT JSON_ARRAYAGG(
           JSON_OBJECT('office' VALUE o.office_name,
                       'status' VALUE 'CLEARED',
                       'date'   VALUE TO_CHAR(s.decided_at, 'YYYY-MM-DD'))
           ORDER BY o.seq_no RETURNING CLOB)
    INTO l_approvals
    FROM mv_clearance_steps s JOIN mv_offices o ON o.office_id = s.office_id
   WHERE s.request_id = p_request_id;

  SELECT JSON_OBJECT('docType'   VALUE 'CLEARANCE',
                     'regNo'     VALUE l_reg,
                     'name'      VALUE l_name,
                     'program'   VALUE l_prog,
                     'approvals' VALUE JSON(l_approvals) FORMAT JSON
                     RETURNING CLOB)
    INTO l_body FROM dual;

  apex_web_service.g_request_headers.DELETE;
  apex_web_service.g_request_headers(1).name  := 'Content-Type';
  apex_web_service.g_request_headers(1).value := 'application/json';

  l_resp := apex_web_service.make_rest_request(
              p_url                  => l_url,
              p_http_method          => 'POST',
              p_body                 => l_body,
              p_credential_static_id => 'MUT_ANCHOR_KEY');

  IF apex_web_service.g_status_code <> 200 THEN
    INSERT INTO mv_audit_log (actor, action, detail)
      VALUES ('SYSTEM', 'ISSUE_FAILED', 'request_id=' || p_request_id || ' http=' || apex_web_service.g_status_code
                                        || ' ' || SUBSTR(l_resp, 1, 500));
    COMMIT;
    RAISE_APPLICATION_ERROR(-20003, 'Anchor service error (HTTP ' || apex_web_service.g_status_code || ')');
  END IF;

  l_json := JSON_OBJECT_T.parse(l_resp);
  l_pdf  := apex_web_service.clobbase642blob(l_json.get_clob('pdfBase64'));

  INSERT INTO mv_documents (doc_id, request_id, doc_type, doc_hash, tx_hash, explorer_url, pdf)
  VALUES (l_json.get_string('docId'), p_request_id, 'CLEARANCE',
          l_json.get_string('docHash'), l_json.get_string('txHash'), l_json.get_string('explorerUrl'), l_pdf);

  UPDATE mv_clearance_requests SET status = 'ISSUED' WHERE request_id = p_request_id;

  INSERT INTO mv_audit_log (actor, action, detail)
    VALUES ('SYSTEM', 'CERTIFICATE_ISSUED',
            'request_id=' || p_request_id || ' hash=' || l_json.get_string('docHash'));
  COMMIT;
END;
/

-- Revoke (registrar console button). Calls POST /revoke on the anchor service.
CREATE OR REPLACE PROCEDURE mv_revoke_document (
  p_doc_id IN VARCHAR2,
  p_actor  IN VARCHAR2
) AS
  l_url   CONSTANT VARCHAR2(300) := 'https://YOUR-DOMAIN/revoke';
  l_hash  mv_documents.doc_hash%TYPE;
  l_resp  CLOB;
BEGIN
  SELECT doc_hash INTO l_hash FROM mv_documents WHERE doc_id = p_doc_id AND status = 'ISSUED';

  apex_web_service.g_request_headers.DELETE;
  apex_web_service.g_request_headers(1).name  := 'Content-Type';
  apex_web_service.g_request_headers(1).value := 'application/json';

  l_resp := apex_web_service.make_rest_request(
              p_url                  => l_url,
              p_http_method          => 'POST',
              p_body                 => '{"docHash":"' || l_hash || '"}',
              p_credential_static_id => 'MUT_ANCHOR_KEY');

  IF apex_web_service.g_status_code <> 200 THEN
    RAISE_APPLICATION_ERROR(-20004, 'Revoke failed (HTTP ' || apex_web_service.g_status_code || ')');
  END IF;

  UPDATE mv_documents SET status = 'REVOKED', revoked_at = SYSTIMESTAMP WHERE doc_id = p_doc_id;
  INSERT INTO mv_audit_log (actor, action, detail) VALUES (p_actor, 'DOCUMENT_REVOKED', 'doc_id=' || p_doc_id);
  COMMIT;
END;
/
