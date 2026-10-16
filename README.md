# goodfood_ecosystem

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

The customer menu reads available products from the Firestore `meals`
collection. Use the admin icon in the menu header to open the product list
directly, without a sign-in page. The list shows products visible to customers.
The management screen requests all products, including hidden ones. The
visibility switch changes the meal's `isAvailable` field: enabled products are
shown to customers, while disabled products remain in the admin list. Firestore
security rules still control access to hidden products and whether create,
update, and delete operations are allowed; opening the admin screen does not
grant cloud permissions.

Firestore offline persistence caches the menu and queues admin writes on the
device. Admin add, edit, visibility, and delete actions are also applied to the
SQLite menu cache immediately, so the management list survives app restarts
while offline. Firestore retries queued writes automatically after connectivity
returns; rejected writes are reported and the local cache is restored when
possible. The first successful online menu load is needed to cache existing
products. Menu updates appear live while connected. Image URLs are saved as
strings in each meal document's `imageUrl` field; they are not uploaded to
Firebase Storage.
