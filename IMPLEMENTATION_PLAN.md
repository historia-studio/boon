# Powdercoating MVP Implementation Plan

## Purpose

This document captures the agreed MVP scope and implementation sequence for the Boon powdercoating tracking system so work can resume on another machine without reconstructing context.

## Current Status

- The project is still at the generated Phoenix/Ash baseline.
- No implementation work has been applied yet for the powdercoating workflow.
- The next session should begin with Phase 1 below.

## MVP Scope

The system should stay deliberately narrow and operator-friendly.

Required capabilities:

1. Track which units, POs, and work packages are physically on site.
2. Print labels and pallet tags.
3. Provide a scan-and-ship interface.

Operational constraints captured so far:

- Intake for MVP is a ZIP upload of PDFs plus a manually entered work package number.
- Printing happens from a review screen after import, not automatically on upload.
- Shipping location is parsed where possible but can be corrected by staff before printing.
- The two unit types and two shipping locations are fixed values in MVP, not admin-managed records.
- Access control is simple staff login.
- Shipping uses a staged scan list plus explicit confirmation.
- The scan UI is intended for phone-camera use, so it must be mobile-first.
- There are two printers with different colored paper, and printer/paper selection depends on shipping location.

## Proposed Domain Model

Keep the core resource set small:

- `WorkPackage`
  - Manual work package number
  - Import status
  - Created/imported timestamps
  - Summary counts for imported, printed, shipped items if useful
- `PurchaseOrder`
  - Parsed PO number
  - Source PDF filename
  - Parse status and parse errors
  - Shipping location
  - Belongs to work package
- `Unit`
  - Unit identifier or line item identifier
  - Unit type
  - Current status: imported, ready_to_print, printed, staged_for_shipment, shipped
  - QR payload/token
  - Belongs to purchase order
- `PrintJob`
  - Document type: label or pallet_tag
  - Target printer
  - Attempt status
  - Error details if failed
  - Linked resource identifier(s)
- `Shipment`
  - Confirmation timestamp
  - Confirmed by user
  - Staged scan set
  - Shipment notes or truck/load reference if later needed

Fixed reference values for MVP:

- Two unit types as constrained values in code
- Two shipping locations as constrained values in code

## Implementation Phases

### Phase 1: Core Data and App Structure

1. Create the Ash domain and resources for work packages, purchase orders, units, print jobs, and shipments.
2. Add the required Ash Postgres configuration and migrations for those resources.
3. Decide and implement the minimal state model for units and imports.
4. Replace the generated landing route with task-oriented routes.
5. Replace the starter Phoenix marketing layout with a simple operator shell.
6. Add simple authentication for staff login.

Outcome:

- The app has real domain objects and a navigable operator shell.

### Phase 2: Intake and Review

1. Build a ZIP upload LiveView.
2. Accept a work package number plus one ZIP file.
3. Extract PDFs server-side.
4. Parse each PDF according to the vendor's fixed layout.
5. Create records per parsed PO/unit.
6. Persist file-level parse failures without failing the entire batch.
7. Build a review screen for the imported work package.
8. Allow correction of shipping location before printing.

Outcome:

- Staff can import a batch and review the resulting records with minimal corrections.

### Phase 3: Printing

1. Add a review-screen action to print labels and pallet tags.
2. Generate ZPL from reviewed work package data.
3. Route printing to the correct network printer based on shipping location.
4. Record each print attempt in a `PrintJob` record.
5. Support safe reprints without duplicating business records.
6. Define and lock the QR payload used on pallet tags.

Outcome:

- Staff can print the correct documents for each location and recover from printer failures.

### Phase 4: Scan and Ship

1. Build a mobile-friendly LiveView for scanning.
2. Use a browser camera scanning hook in `assets/js/app.js`.
3. Resolve scans by a stable internal QR payload.
4. Add scanned items to a staging list.
5. Block duplicate scans within the current shipment.
6. Add one explicit confirm action to mark the staged items shipped.
7. Record who confirmed the shipment and when.

Outcome:

- Staff can scan items on a phone and confirm a shipment cleanly.

### Phase 5: Recovery and Hardening

1. Add a simple history/search screen for work packages, POs, and units.
2. Add reprint and shipment lookup paths for operational recovery.
3. Introduce background jobs only if ZIP parsing or printer dispatch needs async handling.
4. If async work is needed, wire Oban only for import and print jobs.

Outcome:

- Operators and admins can recover from errors without extra complexity.

## Recommended File Touch Points

Likely files to create or extend first:

- `mix.exs`
  - Add only the dependencies actually needed for PDF parsing and browser scanning.
- `lib/boon/application.ex`
  - Add supervised services only when import or print processing requires them.
- `lib/boon_web/router.ex`
  - Replace the starter route with authenticated task-oriented LiveView routes.
- `lib/boon_web/components/layouts.ex`
  - Replace the generated starter navigation with a simpler operator layout.
- `assets/js/app.js`
  - Register the phone-camera scanning hook.
- `assets/css/app.css`
  - Adjust the UI for large touch targets and simple operator workflows.
- `priv/repo/seeds.exs`
  - Seed initial staff/admin accounts and optional sample data.

Likely new areas to add:

- `lib/boon/operations/`
  - Ash domain and resources for work packages, POs, units, print jobs, shipments
- `lib/boon/pdf/`
  - ZIP extraction and fixed-layout PDF parsing
- `lib/boon/printing/`
  - ZPL generation and printer routing
- `lib/boon_web/live/`
  - Intake, review, print, ship, and history LiveViews

## Technical Notes

- Prefer parsing embedded PDF text first; only consider OCR if samples prove the PDFs are image-based.
- Prefer direct raw ZPL over TCP to fixed printer IPs for MVP.
- Model shipping confirmation as a shipment/load record from the start so later truck-level reporting can be added without reworking the scan semantics.
- Keep synchronous workflows where possible in the first cut to reduce moving parts.
- If Oban is added later, keep the scope narrow to import and print work.

## Verification Plan

1. Add resource tests for import state, print state, and shipment state transitions.
2. Add LiveView tests for ZIP upload, review/correction, and staged shipment confirmation.
3. Test ZIP import against valid PDFs, mixed-validity batches, and malformed files.
4. Verify ZPL generation and printer routing before using physical printers.
5. Test the scan flow on an actual phone using the chosen browser.
6. Run `mix precommit` after implementation.

## Suggested First Implementation Slice

When work resumes, start here:

1. Create the core Ash domain/resources and migrations.
2. Add simple staff authentication.
3. Replace the starter layout and router with task-oriented LiveViews.
4. Scaffold the intake, review, and ship screens with placeholder actions.
5. Implement PDF parsing and printing after the workflow shell exists.

## Deferred for Later

These items are intentionally out of MVP unless implementation proves they are necessary:

- Email inbox ingestion
- Editable reference data for unit types and shipping locations
- Complex role-based authorization
- Full reporting/dashboard features
- Broad background-job orchestration
- Print queue abstractions beyond simple printer routing