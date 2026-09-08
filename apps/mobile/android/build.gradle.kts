allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Một số plugin Flutter bên thứ 3 (vd file_picker qua flutter_plugin_android_lifecycle)
// tự lấy compileSdk theo `flutter.compileSdkVersion` của bản Flutter đang cài trên máy
// build, không đọc được compileSdk=36 đã chốt ở app/build.gradle.kts (module riêng).
// Ép compileSdk=36 cho mọi subproject Android để AAR metadata check không còn kêu thiếu.
// :app đã bị evaluationDependsOn(":app") ở trên ép evaluate sớm nên không gọi afterEvaluate
// được nữa (Gradle ném lỗi "already evaluated") — áp trực tiếp cho project đã evaluate,
// còn lại (các plugin) vẫn chờ afterEvaluate như bình thường.
subprojects {
    fun applyCompileSdk36(p: Project) {
        p.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(36)
    }
    if (state.executed) applyCompileSdk36(this) else afterEvaluate { applyCompileSdk36(this) }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
