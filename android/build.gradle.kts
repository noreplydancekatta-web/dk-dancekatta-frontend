//import androidx.compose.foundation.text2.input.delete
//import androidx.compose.ui.layout.layout

// In file: android/build.gradle.kts

plugins {
    id("com.android.application") version "8.9.1" apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}

buildscript {
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1") // ✅ AGP version
        classpath("com.google.gms:google-services:4.4.2") // ✅ for Firebase/Google services
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.20") // Example, match your plugin version
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Safely relocate build directory
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // 👇 only if you actually have :app module
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
