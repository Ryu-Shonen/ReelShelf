# Unstreamed uses only the Latin ML Kit text recognizer.
# The Flutter wrapper contains optional branches for these scripts, but
# their separate ML Kit artifacts are intentionally not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
