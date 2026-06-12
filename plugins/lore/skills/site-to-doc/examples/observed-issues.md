# Observed Issues — 2026-06-12 (upload flow)

Drafted during a `site-to-doc` run of the **Upload a video** scenario.
Source summary: `lore:site-explorer`. These are *drafts* — review before filing.
Each references a screenshot already on disk under `static/img/upload/`.

---

### [Bug] Publish button stays enabled with an empty title, then fails silently

**Type:** bug
**Severity (guess):** high
**Where:** /upload — scenario step 03
**Expected:** Submitting with an empty title is blocked with an inline validation message ("Title is required").
**Actual:** The **Publish** button is clickable with an empty title; clicking it clears the form and shows no error or success message — the upload is silently lost.
**Steps to reproduce:**
1. Go to /upload and select a valid file.
2. Leave the **Title** field empty.
3. Click **Publish**.
**Screenshot:** static/img/upload/upload-03-validation.png
**Environment:** https://app.example.com/upload — Chromium, 1280×720, 2026-06-12
**Source:** observed during site-to-doc run, 2026-06-12

---

### [Bug] Max file size differs from the design (3 GB live vs. 6/12 GB designed)

**Type:** discrepancy
**Severity (guess):** medium
**Where:** /upload — scenario step 02
**Expected:** Per Figma v2.1, the limit is 6 GB (standard) / 12 GB (premium).
**Actual:** A 4 GB file is rejected with the message "حجم فایل بیش از حد مجاز است. حداکثر 3GB" — the live cap is 3 GB for all users, with no premium tier.
**Steps to reproduce:**
1. Go to /upload.
2. Choose a 4 GB file.
**Screenshot:** static/img/upload/upload-02-size-error.png
**Environment:** https://app.example.com/upload — Chromium, 1280×720, 2026-06-12
**Source:** observed during site-to-doc run, 2026-06-12
