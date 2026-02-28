# =============================================================================
# AviQuest Flutter APK Builder
# Produces a release APK for Android testing
#
# Usage:
#   docker compose up --build
#   # OR
#   docker build -t aviquest-builder . && \
#   docker run --rm -v ./build-output:/output-host aviquest-builder
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Flutter build environment
# ---------------------------------------------------------------------------
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies for Flutter + Android SDK
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip wget ca-certificates \
    libglu1-mesa openjdk-17-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# Java 17 (required by AGP 8.x)
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    cd $ANDROID_HOME/cmdline-tools && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O tools.zip && \
    unzip -q tools.zip && rm tools.zip && \
    mv cmdline-tools latest

RUN yes | sdkmanager --licenses > /dev/null 2>&1 && \
    sdkmanager --update && \
    sdkmanager \
      "platform-tools" \
      "platforms;android-34" \
      "build-tools;34.0.0" \
      "ndk;25.1.8937393"

# Flutter SDK
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

RUN git clone --depth 1 --branch 3.22.3 https://github.com/flutter/flutter.git $FLUTTER_HOME && \
    flutter precache --android && \
    flutter config --no-analytics && \
    dart --disable-analytics

# ---------------------------------------------------------------------------
# Stage 2: Build the APK
# ---------------------------------------------------------------------------
WORKDIR /app

# Copy the full Flutter project
COPY aviquest/ .

# Generate local.properties (required by settings.gradle)
RUN echo "sdk.dir=$ANDROID_HOME" > android/local.properties && \
    echo "flutter.sdk=$FLUTTER_HOME" >> android/local.properties && \
    echo "flutter.buildMode=release" >> android/local.properties && \
    echo "flutter.versionName=1.0.0" >> android/local.properties && \
    echo "flutter.versionCode=1" >> android/local.properties

# Regenerate missing scaffolding (gradlew, launcher icons, etc.)
RUN flutter create --project-name aviquest --org com.example .

# Restore our source files (flutter create overwrites lib/main.dart, build.gradle, etc.)
COPY aviquest/lib/ lib/
COPY aviquest/pubspec.yaml .
COPY aviquest/android/app/build.gradle android/app/build.gradle
COPY aviquest/android/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

# Resolve dependencies and build
RUN flutter pub get
RUN flutter build apk --release

# ---------------------------------------------------------------------------
# Stage 3: Tiny output image with just the APK
# ---------------------------------------------------------------------------
FROM alpine:3.19 AS output

COPY --from=builder /app/build/app/outputs/flutter-apk/app-release.apk /output/aviquest-release.apk

CMD ["ls", "-lh", "/output/"]
