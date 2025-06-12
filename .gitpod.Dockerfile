FROM gitpod/workspace-full-vnc
SHELL ["/bin/bash", "-c"]

ENV ANDROID_HOME=/home/gitpod/androidsdk \
    FLUTTER_VERSION=2.2.3-stable

USER root

# Create directory for apt keyrings to store GPG keys securely
RUN mkdir -p /etc/apt/keyrings

# Attempt to remove any problematic Nginx PPA source lists.
# This PPA seems to be causing a "404 Not Found" error.
# The 'find ... -delete' ensures all matching files are removed.
RUN find /etc/apt/sources.list.d/ -name "*nginx-mainline*.list" -delete || true

# Configure Dart repository using the modern apt key handling method.
# The GPG key is downloaded and processed with 'gpg --dearmor' to ensure
# it's in the correct binary format for 'signed-by'.
RUN curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/dart-archive-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/dart-archive-keyring.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" > /etc/apt/sources.list.d/dart_stable.list

# Configure Google Chrome repository using the modern apt key handling method.
# Similar to Dart, the key is processed with 'gpg --dearmor'.
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome-keyring.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# Update package lists after all repositories have been added and configured.
RUN apt update

# Install build essential packages, Dart, and other dependencies.
# Replaced 'install-packages' with standard 'apt install -y'.
RUN apt install -y build-essential dart libkrb5-dev gcc make gradle android-tools-adb android-tools-fastboot

# Install Open JDK 8
RUN apt install -y openjdk-8-jdk \
    && update-java-alternatives --set java-1.8.0-openjdk-amd64

# Install Google Chrome stable version.
RUN apt install -y google-chrome-stable

# Install miscellaneous dependencies required for Flutter and other tools.
RUN apt install -y \
  libasound2-dev \
  libgtk-3-dev \
  libnss3-dev \
  fonts-noto \
  fonts-noto-cjk

USER gitpod

# Install Flutter: download, extract, and remove archive.
RUN cd /home/gitpod \
    && wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}.tar.xz \
    && tar -xvf flutter*.tar.xz \
    && rm -f flutter*.tar.xz

# Precache Flutter artifacts. Using absolute path for flutter command.
RUN /home/gitpod/flutter/bin/flutter precache

# Add Flutter to the user's bashrc PATH for future interactive sessions.
RUN echo 'export PATH="$PATH:/home/gitpod/flutter/bin"' >> /home/gitpod/.bashrc

# Install Android SDK Command-line Tools.
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip \
    && mkdir -p $ANDROID_HOME/cmdline-tools/latest \
    && unzip commandlinetools-linux-*.zip -d $ANDROID_HOME \
    && rm -f commandlinetools-linux-*.zip \
    && mv $ANDROID_HOME/cmdline-tools/bin $ANDROID_HOME/cmdline-tools/latest \
    && mv $ANDROID_HOME/cmdline-tools/lib $ANDROID_HOME/cmdline-tools/latest

# Add Android SDK paths to the user's bashrc for future interactive sessions.
RUN echo "export ANDROID_HOME=$ANDROID_HOME" >> /home/gitpod/.bashrc \
    && echo 'export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/cmdline-tools/bin:$ANDROID_HOME/platform-tools:$PATH' >> /home/gitpod/.bashrc

# Install Android platform-tools, platform 30, and emulator.
RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-30" "emulator"

# Install Android system image for API 30 (Google APIs, x86_64).
RUN yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-30;google_apis;x86_64"

# Create an Android Virtual Device (AVD) named avd28 using the installed system image.
RUN echo no | $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n avd28 -k "system-images;android-30;google_apis;x86_64"

# Set environment variable for Qt WebEngine, fixing the format.
ENV QTWEBENGINE_DISABLE_SANDBOX=1
