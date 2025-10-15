# localStorage to Supabase Migration Summary

## Overview

This migration replaces all localStorage-based data persistence with Supabase database storage for the WholeHog Competition Web App.

## Changes Made

### Files Updated

#### 1. **landing.html**
- Added Supabase CDN and config includes
- Replaced localStorage-based team and judge management with Supabase insert/select
- Teams now save to `teams` table with fields: id, name, site_number, chip_number, affiliation
- Judges now save to `judges` table with fields: id, name
- Added proper error handling with user alerts
- Lists refresh from Supabase on page load

#### 2. **onsite.html**
- Added Supabase CDN and config includes
- Removed localStorage sync scripts
- Now references `onsite-supabase.js` for all logic
- Navigation updated to link to `blind-taste.html`

#### 3. **onsite-supabase.js** (new file)
- Complete rewrite of onsite.js using Supabase
- Loads teams and judges from Supabase tables
- Saves scores to `onsite_scores` table with proper structure
- Export CSV now queries Supabase with joins to get team/judge names
- All completeness data stored as JSONB in database
- No localStorage usage

#### 4. **blind-taste.html**
- Complete rewrite to use Supabase
- Added Supabase CDN and config includes
- Loads judges from `judges` table
- Loads chip numbers from `teams.chip_number` field
- Saves scores to `blind_taste` table
- Implements duplicate prevention (same judge + chip)
- Added navigation buttons to other pages
- All scoring logic uses Supabase

#### 5. **sauce.html**
- Added Supabase CDN and config includes
- Replaced localStorage chip list with dynamic loading from `teams.chip_number`
- Loads judges from `judges` table
- Saves scores to `sauce_scores` table
- Proper error handling and user feedback
- Navigation updated

### New Files Created

#### 1. **onsite-supabase.js**
- Replacement for onsite.js with full Supabase integration
- ~250 lines of clean, localStorage-free code

#### 2. **onsite_scores_schema.sql**
- SQL schema for onsite scoring table
- Includes RLS policies and indexes

#### 3. **sauce_scores_schema.sql**
- SQL schema for sauce tasting scores
- Includes RLS policies and indexes

#### 4. **SUPABASE_SETUP.md**
- Complete database schema documentation
- Setup instructions for all required tables
- Configuration information

#### 5. **TESTING.md**
- Comprehensive testing guide
- 8 test scenarios covering all pages
- Verification checklist

#### 6. **MIGRATION_SUMMARY.md** (this file)
- Overview of all changes made

## Database Schema

### Tables Required

1. **teams**
   - id (uuid, primary key)
   - name (text, unique, not null)
   - site_number (text)
   - chip_number (text)
   - affiliation (text)
   - created_at (timestamptz)

2. **judges**
   - id (uuid, primary key)
   - name (text, unique, not null)
   - created_at (timestamptz)

3. **onsite_scores**
   - id (uuid, primary key)
   - team_id (uuid, foreign key to teams)
   - judge_id (uuid, foreign key to judges)
   - suitable (text)
   - appearance, color, skin, moisture, meat_sauce (integers)
   - completeness (jsonb)
   - created_at (timestamptz)

4. **blind_taste**
   - id (uuid, primary key)
   - judge_id (text)
   - chip_number (integer)
   - score_appearance, score_tenderness, score_flavor, score_total (numeric)
   - created_at (timestamptz)
   - Unique constraint on (judge_id, chip_number)

5. **sauce_scores**
   - id (uuid, primary key)
   - judge_id (uuid, foreign key to judges)
   - chip_number (text)
   - score (numeric)
   - created_at (timestamptz)

All tables have RLS enabled with permissive policies for select and insert.

## Migration Notes

### What Was Removed

- All `localStorage.setItem()` calls for teams, judges, and scores
- All `localStorage.getItem()` calls for teams, judges, and scores
- Local storage keys: `wh_Teams`, `wh_Judges`, `wh_entries`, `onsiteScores`, `blindTasteEntries`, `sauceScores`, etc.
- Synchronization logic between localStorage and forms
- localStorage-based export functionality

### What Was Kept

- All UI/UX elements and styling
- Form layouts and validation logic
- Score calculation algorithms
- Navigation structure
- Export to CSV functionality (now queries Supabase)

### What's Different

- Data now persists across browsers and devices
- No data size limitations (localStorage has 5-10MB limit)
- Data is immediately available to all users
- Can be backed up server-side
- Can query with SQL for reports
- Requires internet connection to save/load data

## Breaking Changes

### For Users

- Existing localStorage data will NOT be automatically migrated
- Users should clear their localStorage: `localStorage.clear()` in browser console
- First-time users must set up teams and judges again in landing.html

### For Developers

- Old localStorage-based code is no longer active
- `onsite.js` is replaced by `onsite-supabase.js`
- `blind.html` (old version) is not linked but still exists
- Primary blind taste page is now `blind-taste.html`

## Testing Status

Automated testing not performed. Manual testing required following `TESTING.md`.

Required tests:
- [ ] Landing page: Add teams and judges
- [ ] Landing page: Reload and verify persistence
- [ ] Onsite page: Load teams/judges, save scores
- [ ] Onsite page: Verify scores in Supabase dashboard
- [ ] Blind taste: Save scores, verify duplicates blocked
- [ ] Sauce: Save scores to Supabase
- [ ] Export CSV from onsite page
- [ ] Cross-browser verification

## Rollback Plan

If issues are discovered:

1. Restore old files:
   - Use `onsite.js` instead of `onsite-supabase.js`
   - Reference `onsite.js` in `onsite.html`
   - Restore localStorage logic in other HTML files

2. Keep navigation pointing to old files

3. Users would continue with localStorage

Note: Old versions may be in backup directories or git history.

## Next Steps

1. **Run SQL Scripts**: Execute all schema files in Supabase (see SUPABASE_SETUP.md)

2. **Test Thoroughly**: Follow TESTING.md guide

3. **Monitor Errors**: Check browser console and Supabase logs for issues

4. **User Communication**: Inform users they need to:
   - Clear old data with `localStorage.clear()`
   - Re-enter teams and judges on landing page
   - All old scores in localStorage will not be migrated

5. **Backup**: Export any important localStorage data before clearing

6. **Future Enhancements**:
   - Add data migration script to import old localStorage data
   - Add leaderboard integration
   - Add real-time updates with Supabase realtime
   - Add authentication and user roles

## Configuration

The app connects to Supabase using credentials in `supabase-config.js`:
- URL: `https://wiolulxxfyetvdpnfusq.supabase.co`
- Anon Key: (stored in file)

These credentials are exposed client-side (as designed for anon access). Row Level Security (RLS) policies control data access.

## Support

For issues:
1. Check browser console for JavaScript errors
2. Check Supabase dashboard for database errors
3. Verify RLS policies are set correctly
4. Ensure all schema files have been run
5. Verify internet connection

## Conclusion

This migration successfully removes all localStorage dependencies for teams, judges, and scoring data. All data now persists to Supabase for reliable, cross-device access.
