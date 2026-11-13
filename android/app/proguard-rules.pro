# R8 rules for release builds. Flutter and its plugins ship their own keep
# rules; add entries here only when a plugin documents that it needs them,
# with a comment saying which plugin and why.

# google_mobile_ads -> play-services-ads -> WorkManager -> Room.
# Room creates each database (here WorkManager's WorkDatabase_Impl) by
# reflection through its no-argument constructor. R8 full mode (AGP 8+) keeps
# a class named by `-keep class X` but not its constructor, so the release
# build crashed on launch: "Failed to create an instance of
# androidx.work.impl.WorkDatabase" (Play rejection, 13 November 2026).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
