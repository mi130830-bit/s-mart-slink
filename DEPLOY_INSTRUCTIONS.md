# Deployment Instructions

## 1. Prerequisites
- Ensure you have the Firebase CLI installed: `npm install -g firebase-tools`
- Login to Firebase: `firebase login`

## 2. Deploy Functions and Indexes
To deploy the updated functions and the new Firestore indexes, run the following command.  
**Note for Windows (PowerShell) users:** You **MUST** use quotes around the list of targets.

```powershell
firebase deploy --only "functions,firestore:indexes"
```

If you only want to deploy functions:
```powershell
firebase deploy --only functions
```

## 3. TroubleShooting
- **Billing**: The `sendBatchAlerts` function uses `onSchedule` (v2), which requires the **Blaze (Pay-as-you-go)** plan.
- **Region**: The functions are set to `asia-southeast1`. Ensure your project supports this region.
