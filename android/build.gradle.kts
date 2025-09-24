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

// Workaround: some third-party plugins may not declare an Android namespace yet (required by AGP 8+).
// Set a namespace for the affected library module(s) here to unblock builds.
subprojects {
    if (project.name == "twitter_login") {
        plugins.withId("com.android.library") {
            @Suppress("UnstableApiUsage")
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                namespace = "com.twitterlogin.plugin"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
