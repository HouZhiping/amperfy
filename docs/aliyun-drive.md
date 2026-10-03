# Aliyun Drive integration

Amperfy uses Alibaba's official `AliyunpanSDK` and its PKCE authorization flow. No password or
access token is stored in this repository.

## Configuration

1. Register an application in the Aliyun Drive Open Platform.
2. Enable the scopes `user:base` and `file:all:read` for that application.
3. Set the `ALIYUN_DRIVE_APP_ID` user-defined build setting on the **Amperfy** target for both
   Debug and Release.
4. Make sure the bundle identifier registered in the Open Platform matches the app target.

For GitHub Actions builds, add a repository Actions secret named `ALIYUN_DRIVE_APP_ID`. The
workflow passes it to Xcode without committing the value to the repository.

The Info.plist declares `smartdrive$(ALIYUN_DRIVE_APP_ID)` as the callback URL scheme. The SDK
uses the official PKCE flow, so no client secret or custom backend is needed.

After configuration, open **Settings > Aliyun Drive**, authorize access, browse folders, and tap
an audio file to play it through Amperfy's existing player.

