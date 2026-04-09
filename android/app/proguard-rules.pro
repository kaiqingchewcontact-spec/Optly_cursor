# Keep TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }

# Ktor / Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
