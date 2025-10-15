# Testing Guide for Supabase Migration

This document outlines the testing steps to verify that all localStorage has been replaced with Supabase.

## Prerequisites

1. Ensure all SQL schemas from `SUPABASE_SETUP.md` have been run in Supabase
2. Verify that `supabase-config.js` has the correct URL and API key
3. Open the app in a fresh browser session (or clear localStorage to start clean)

## Test 1: Landing Page - Teams

**Page:** landing.html

**Steps:**
1. Open landing.html
2. Add a team:
   - Team Name: "Test Team 1"
   - Chip #: "101"
   - Site #: "1"
   - Check "Legion"
   - Click "Add Team"
3. Verify:
   - Alert shows "Team saved: Test Team 1"
   - Team appears in the list below with Legion affiliation
   - Chip Entered shows "Yes"
4. Reload the page
5. Verify:
   - Team still appears in the list
   - Data persisted to Supabase

**Expected Result:** Team data is saved to and loaded from Supabase `teams` table

## Test 2: Landing Page - Judges

**Page:** landing.html

**Steps:**
1. On landing.html
2. Add a judge:
   - Judge Name: "Judge Smith"
   - Click "Add Judge" (or submit form)
3. Verify:
   - Alert shows "Judge saved: Judge Smith"
   - Judge appears in the list below
4. Reload the page
5. Verify:
   - Judge still appears in the list

**Expected Result:** Judge data is saved to and loaded from Supabase `judges` table

## Test 3: On-Site Scoring

**Page:** onsite.html

**Steps:**
1. Open onsite.html
2. Verify:
   - Team dropdown loads with teams from Supabase
   - Judge dropdown loads with judges from Supabase
3. Select a team and judge
4. Select "Suitable": YES
5. Choose scores for each category (click the button to expand options):
   - Appearance: 20
   - Color: 20
   - Skin: 40
   - Moisture: 40
   - Meat & Sauce: 40
6. Check some completeness checkboxes (e.g., Site cleanliness)
7. Verify total updates correctly
8. Click "Save Entry"
9. Verify:
   - Alert shows "Entry saved successfully!"
10. Check in Supabase dashboard:
    - Open `onsite_scores` table
    - Verify new row exists with correct data

**Expected Result:** On-site scores are saved to Supabase `onsite_scores` table

## Test 4: Blind Taste Scoring

**Page:** blind-taste.html

**Steps:**
1. Open blind-taste.html
2. Verify:
   - Judge dropdown loads from Supabase
   - Chip # dropdown loads from teams' chip_number field
3. Select a judge
4. Select a chip number
5. Enter scores:
   - Appearance: 8
   - Tenderness: 9
   - Flavor: 27
6. Verify total shows 44
7. Click "Save Blind Taste"
8. Verify:
   - Alert shows "Saved! Chip #..."
   - Form clears
9. Try to save the same judge + chip combination again
10. Verify:
    - Alert shows "This Judge + Chip # has already been saved."
11. Check in Supabase dashboard:
    - Open `blind_taste` table
    - Verify row exists with correct scores

**Expected Result:** Blind taste scores are saved to Supabase `blind_taste` table with duplicate prevention

## Test 5: Sauce Tasting

**Page:** sauce.html

**Steps:**
1. Open sauce.html
2. Verify:
   - Chip # dropdown loads from teams
   - Judge dropdown loads from judges table
3. Select a chip number
4. Select a judge
5. Enter a score (e.g., 9.5)
6. Click "Enter"
7. Verify:
   - Alert shows "Sauce score saved for chip #..."
   - Status message appears
8. Check in Supabase dashboard:
   - Open `sauce_scores` table
   - Verify row exists

**Expected Result:** Sauce scores are saved to Supabase `sauce_scores` table

## Test 6: Export Functionality

**Page:** onsite.html

**Steps:**
1. After entering some scores (from Test 3)
2. Click "Export CSV"
3. Verify:
   - CSV file downloads
   - File contains data from Supabase, not localStorage
   - Data includes team names, judge names (joined from related tables)

**Expected Result:** Export pulls data from Supabase

## Test 7: Cross-Browser Persistence

**Steps:**
1. Complete Tests 1-5 in Chrome
2. Open Firefox (or another browser)
3. Navigate to each page
4. Verify:
   - All data entered in Chrome is visible in Firefox
   - Teams, judges, and scores all load from Supabase

**Expected Result:** Data persists across browsers because it's in Supabase, not localStorage

## Test 8: Error Handling

**Steps:**
1. Temporarily break the Supabase config (change URL to invalid)
2. Open landing.html
3. Try to add a team
4. Verify:
   - Error alert is shown to user
   - Console shows clear error message
5. Restore correct config

**Expected Result:** Errors are caught and reported to the user

## Verification Checklist

- [ ] No localStorage.getItem() calls in production code paths
- [ ] No localStorage.setItem() calls for teams, judges, or scores
- [ ] All forms submit to Supabase
- [ ] All dropdowns load from Supabase
- [ ] Data persists across page reloads
- [ ] Data persists across different browsers
- [ ] Error messages are user-friendly
- [ ] Duplicate prevention works (blind taste)
- [ ] CSV export works and pulls from Supabase

## Known Issues / Notes

- `blind.html` still exists with localStorage code but is not linked from navigation
- The app uses `blind-taste.html` as the primary blind taste page
- Old localStorage data will not be automatically migrated
- Users should clear localStorage after migration: `localStorage.clear()`
