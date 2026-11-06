# Mac App Store submission

Everything needed to submit the App Store edition of App Vanish 1.0.0. Limits in brackets are Apple's.

The App Store edition finds files left by apps that were already deleted. The full uninstaller stays on GitHub and Homebrew, because removing apps needs access the sandbox doesn't allow.

## Checklist

1. Deploy the website, so the privacy policy URL below is live.
2. In App Store Connect, choose **Apps → + → New App**:
   - Platform: macOS
   - Name: App Vanish
   - Primary language: English (U.S.)
   - Bundle ID: `com.heysidhant.AppVanishLeftovers`
   - SKU: `appvanish-mac`
   - User Access: Full Access
3. Fill in the sections below.
4. Upload the build: `UPLOAD=1 scripts/make-appstore.sh`.
5. Install it through TestFlight and run the test list below.
6. Choose **Manually release this version**, then submit for review.

## Listing

**Name** [30]

App Vanish

**Subtitle** [30]

Clean Deleted App Leftovers

**Promotional text** [170]

Find the files deleted apps left in your Library, and move the ones you choose to the Trash. Free, with no ads, account or in-app purchases.

**Keywords** [100]

leftovers,cleaner,cleanup,uninstall,uninstaller,library,caches,preferences,storage,junk,files,remove

**Description** [4000]

```text
Deleting a Mac app usually leaves files behind in your Library. App Vanish finds them, so you can clear them out.

Allow access to your Home folder once. App Vanish compares your Library with the apps you have installed, then lists items from apps that are gone. You choose what to remove, and your choices move to the Trash, so you can put them back.

BUILT TO BE CAREFUL
Nothing is ticked for you. You review each item and decide.
Items go to the Trash, not straight to deletion.
If an app from the same company is installed, its files are left off the list.
Apple's own files are left alone.

WHAT IT CHECKS
Application Support, Caches, HTTP storage, Logs, Preferences, Saved Application State and WebKit data in your Library.

WHAT IT DOESN'T DO
App Vanish doesn't delete apps. To remove an app, move it to the Trash first, then use App Vanish to find what it left.

PRIVATE
Everything happens on your Mac. There's no account or analytics, and App Vanish makes no network connections.

FREE
No ads, no in-app purchases and no subscription. App Vanish is open source under the MIT license.
```

**URLs**

- Support: `https://github.com/heysidhant/appvanish/issues`
- Marketing: `https://appvanish.pages.dev`
- Privacy policy: `https://appvanish.pages.dev/privacy/`

**Other fields**

- Category: Utilities. Secondary: Productivity.
- Price: Free, all territories.
- Copyright: 2026 Sidhant Sinha
- Age rating: answer "None" or "No" throughout.
- Third-party content: No.
- Release: Manually release this version.

**Screenshots** (Mac, 2880 × 1800)

Use the files in `dist/app-store-screenshots/`, in numbered order. They show the app with sample data.

## App Privacy

Select **Data Not Collected**.

## App Review

**Sign-in required:** No.

**Notes:**

```text
App Vanish needs no account.

Why Home folder access is needed: the app finds files that deleted apps left in ~/Library. The person selects their Home folder in the standard open panel. A security-scoped bookmark remembers that choice, and "Forget Home Folder Access" in the File menu removes it. The app doesn't read file contents. It lists item names and sizes in specific Library folders, and it only moves items the person ticks to the Trash.

To test:
1. Run this in Terminal to create a sample leftover: mkdir ~/Library/Caches/com.example.reviewleftover
2. Open App Vanish, click Choose Home Folder, and click Allow.
3. Find "Reviewleftover" in the list, tick it, and click Move to Trash.

If the Mac has no leftovers and the sample step is skipped, the app shows "No leftovers found".

All processing is on-device, and the app has no network entitlement. Source code: https://github.com/heysidhant/appvanish
```

**Export compliance:** handled by `ITSAppUsesNonExemptEncryption = NO`.

## Test before submitting

Use the TestFlight build.

- [ ] Allow Home folder access, and confirm a wrong folder shows an error.
- [ ] Quit and reopen. It should scan without asking again.
- [ ] Tick one sample item, move it to Trash, and put it back from the Trash.
- [ ] Use File → Forget Home Folder Access, and confirm it asks again.
