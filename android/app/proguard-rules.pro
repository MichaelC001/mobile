-keep class org.bouncycastle.jcajce.provider.** { *; }
-keep class org.bouncycastle.jce.provider.BouncyCastleProvider { *; }
-checkdiscard class org.bouncycastle.est.**

-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
