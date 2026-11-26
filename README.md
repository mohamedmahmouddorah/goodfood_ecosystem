# GoodFood Ecosystem

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Menu and admin access

The customer menu reads available products from the `Firestore` `meals`
collection. Use the admin icon in the menu header to open the product list
directly. The management screen requests all products, including hidden ones.
The visibility switch changes the meal's `isAvailable` field: enabled products
are shown to customers, while disabled products remain in the admin list.
`Firestore` security rules remain responsible for deciding whether product
management operations are permitted.

`Firestore`'s built-in persistence is disabled. SQLite caches the menu and
pending admin writes on the device. Admin changes are sent to Firebase
immediately and retained in SQLite if Firebase rejects or cannot reach the
write; the queue retries periodically and at app startup. The first successful
online menu load is needed to cache existing products. Menu updates appear live
while connected. Image URLs are saved as strings in each meal document's
`imageUrl` field.

The cart is currently stored in SQLite on this device; `Firestore` cart
synchronization is not implemented.

Run the app with the `ImgBB` key:

```powershell
flutter run --dart-define=IMGBB_API_KEY=YOUR_ROTATED_KEY
```

Images are uploaded directly to `ImgBB` and their HTTPS URLs are stored in the
meal's `Firestore` `imageUrl` field. A key passed with `--dart-define` is
embedded in the compiled app and can be extracted; rotate any key shared in
chat, and prefer a server-side image upload for production.
