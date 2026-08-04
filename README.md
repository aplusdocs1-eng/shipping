# courierwarehousing

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploying to Vercel

1. Build the web app:
```bash
flutter build web --release
```

2. Deploy the generated `build/web` output:
```bash
cd build/web
vercel --prod
```

3. Or deploy directly from the project root:
```bash
npx vercel --prod build/web
```

Optional local config file: `vercel.json` is included to serve the static `build/web` app.

## Git-based Vercel Deployment

This repository includes a GitHub Actions workflow to build Flutter web and deploy to Vercel automatically when you push to `main`.

### Setup
1. Push this repo to GitHub.
2. In Vercel, create a new project and connect the GitHub repo.
3. Add the following repository secrets in GitHub:
   - `VERCEL_TOKEN` — your Vercel personal token
   - `VERCEL_ORG_ID` — your Vercel organization ID
   - `VERCEL_PROJECT_ID` — the Vercel project ID
   - `VERCEL_SCOPE` — your Vercel team or username (usually your Personal Account)

### Workflow file
- `.github/workflows/vercel-deploy.yml`

The workflow:
- checks out code
- installs Flutter
- runs `flutter pub get`
- builds `flutter build web --release`
- deploys `build/web` to Vercel

### Notes
- If you want to deploy from a branch other than `main`, update the workflow trigger.
- If Vercel needs a custom root, you can also set the project to use `build/web` as the output directory.
# shipping
