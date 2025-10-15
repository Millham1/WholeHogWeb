# Quick Start Guide

## What Changed?

The WholeHog Competition Web App now uses **Supabase** instead of localStorage for all data storage. This means:

✅ Your data is saved to a database  
✅ Data persists across browsers and devices  
✅ Multiple users can access the same data  
✅ No more 5MB localStorage limits  

## Before You Start

### Step 1: Set Up the Database

1. Log into your Supabase project at https://supabase.com
2. Go to the **SQL Editor**
3. Run the SQL scripts in this order:
   - Open `SUPABASE_SETUP.md`
   - Copy and paste each CREATE TABLE statement
   - Click "Run" after each one
4. Verify tables exist in the **Table Editor**

You need these 5 tables:
- `teams`
- `judges`
- `onsite_scores`
- `blind_taste`
- `sauce_scores`

### Step 2: Verify Configuration

1. Open `supabase-config.js`
2. Confirm it has your project URL and anon key
3. This should already be configured correctly

### Step 3: Clear Old Data (Important!)

The app no longer uses localStorage. Clear it to avoid confusion:

1. Open your browser's Developer Tools (F12)
2. Go to the Console tab
3. Type: `localStorage.clear()`
4. Press Enter
5. Refresh the page

## How to Use

### 1. Landing Page (landing.html)

**Add Teams:**
1. Enter Team Name
2. Enter Chip # (optional)
3. Enter Site #
4. Select affiliation (Legion/Sons)
5. Click "Add Team"
6. Team appears in list below

**Add Judges:**
1. Enter Judge Name
2. Click "Add Judge" or press Enter
3. Judge appears in list below

All data saves to Supabase automatically!

### 2. On-Site Scoring (onsite.html)

1. Select a Team (loads from Supabase)
2. Select a Judge (loads from Supabase)
3. Choose "Suitable for public consumption"
4. Click each category to expand and select scores:
   - Appearance (2-40)
   - Color (2-40)
   - Skin (4-80)
   - Moisture (4-80)
   - Meat & Sauce (4-80)
5. Check completeness items (8 points each)
6. Click "Save Entry"
7. Score saves to Supabase!

### 3. Blind Taste (blind-taste.html)

1. Select a Judge (loads from Supabase)
2. Select a Chip # (loads from teams' chip numbers)
3. Enter scores:
   - Appearance (0-10)
   - Tenderness (0-10)
   - Flavor (0-10)
4. Total calculates automatically
5. Click "Save Blind Taste"
6. Cannot save same Judge + Chip twice (duplicate prevention)

### 4. Sauce Tasting (sauce.html)

1. Select a Chip # (loads from teams)
2. Select a Judge (loads from Supabase)
3. Enter Score (any positive number)
4. Click "Enter"
5. Score saves to Supabase!

## Troubleshooting

### "Error loading teams" or "Error loading judges"

**Solution:** Make sure you ran all the SQL scripts from `SUPABASE_SETUP.md`

### "Failed to save: [error message]"

**Possible causes:**
1. Internet connection issue
2. Supabase project is paused (free tier pauses after inactivity)
3. RLS policies not set correctly

**Solution:**
1. Check your internet connection
2. Wake up your Supabase project (visit dashboard)
3. Verify RLS policies in `SUPABASE_SETUP.md`

### Nothing appears in dropdowns

**Solution:**
1. First, add teams and judges on the Landing page
2. Check browser console (F12) for errors
3. Verify Supabase is accessible

### Old data from localStorage

If you see inconsistent data:
1. Open browser console (F12)
2. Type: `localStorage.clear()`
3. Refresh the page
4. Re-enter your teams and judges

## Exporting Data

On the On-Site page, click "Export CSV" to download all scores from Supabase as a CSV file.

## Testing

For comprehensive testing instructions, see `TESTING.md`.

## Need Help?

1. Check the browser console (F12) for error messages
2. Check Supabase dashboard → Logs for database errors
3. Review `MIGRATION_SUMMARY.md` for detailed technical info
4. Review `SUPABASE_SETUP.md` to verify database setup

## Important Notes

- **Internet required:** Unlike localStorage, you need internet to save/load
- **No auto-migration:** Old localStorage data is NOT automatically moved to Supabase
- **Multi-user:** Multiple people can now use the same data simultaneously
- **Backup:** Your data is backed up in Supabase's servers

## That's It!

Your WholeHog Competition Web App is now using Supabase for reliable, cloud-based data storage. Enjoy!
