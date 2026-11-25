# Releasing to Google Play

Releases are built and uploaded by GitHub Actions. You don't need to build anything locally.

1. Bump `version:` in `pubspec.yaml` (for example `1.0.3+5`) and merge it to `main`. Only the part before `+` matters: the workflow sets the version code.
2. On GitHub: **Actions → Release to Google Play → Run workflow**.
3. Choose the **track**: `internal` (default), `alpha` (closed testing), `beta` (open testing) or `production`. Then run it.

The workflow:
- Runs the tests.
- Builds a signed app bundle from `main`.
- Uploads it to that track.
- Keeps the `.aab` as a download on the run page for 30 days.

You'll see the new release in the Play Console a minute or two after it finishes. A production release still goes through Google's review.

**Version code.** Every upload needs a higher version code than the last. The workflow uses 100 + the workflow's run number (101, 102, …), which stays above the hand-uploaded builds. To pick one yourself, fill in **Version code** when you run it.

**Status.** Leave it on `completed`. If Play complains that the app or track has no published release yet, run it once with `draft`, then roll that draft out from the Play Console.

## One-time setup

### 1. A Google Play service account

This lets the workflow upload builds without your Google password.

1. In the [Google Cloud console](https://console.cloud.google.com/), pick or create a project, then enable the **Google Play Android Developer API** for it.
2. Go to **IAM & Admin → Service accounts → Create service account**. Give it a name like `play-uploader`; it needs no Cloud roles. Open the account, then go to **Keys → Add key → JSON**. A `.json` file downloads.
3. In the [Play Console](https://play.google.com/console/): go to **Users and permissions → Invite new users**. Enter the service account's email (from the JSON file, ending in `iam.gserviceaccount.com`).
4. Under **App permissions**, add Wavelog Portable and allow at least:
   - **Release apps to testing tracks**
   - **Release to production, exclude devices, and use Play App Signing** (only if you want production releases from GitHub)

   Then invite the account.

Keep the JSON file private. Delete it from your computer after step 2 below; you can make a new key at any time.

### 2. GitHub secrets

The workflow signs with the same upload key as your local release builds, taken from `android/key.properties`. From the repo folder, run:

```bash
tool/set_play_secrets.sh ~/Downloads/your-service-account.json
```

The script never prints the values. It sets five repository secrets:

| Secret | What it is |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The upload keystore file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | Its store password |
| `ANDROID_KEY_ALIAS` | The key alias |
| `ANDROID_KEY_PASSWORD` | The key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | The service account JSON |

You can check them under **Settings → Secrets and variables → Actions**. GitHub never shows their values again, and workflow logs mask them.

## Notes

- This is your **upload key**. If you use Play App Signing (the default for new apps), Google re-signs the app with the app signing key it holds. If the upload key is ever lost or leaked, you can ask Google to reset it from the Play Console.
- Only people with write access to the repo can run the workflow, and secrets aren't available to pull requests from forks.
