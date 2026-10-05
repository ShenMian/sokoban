# Building

This document describes how to compile GDExtension on Linux and Windows and export the project to various platforms.

## Windows

```ps1
cargo build --release --manifest-path extension/Cargo.toml
mkdir -p build/windows
godot --headless --export-release "Windows" build/windows/sokoban.exe
```

## Linux

```sh
cargo build --release --manifest-path extension/Cargo.toml
mkdir -p build/linux
godot --headless --export-release "Linux" build/linux/sokoban.x86_64
```

### From Windows

> [!WARNING]
> Manually specifying the target changes the build output path. Therefore, the paths in the `sokoban.gdextension` file must be updated accordingly.

On Windows, cross-compilation can be performed using `cross`. However, it relies on Podman, which in turn requires WSL2 (Windows Subsystem for Linux 2).

Install WSL2 using the following command and restart the operating system:

```ps1
wsl --install
```

Install the necessary dependencies with the following command:

```ps1
scoop install podman
podman machine init
cargo install cross
```

The cross-compilation can then be executed with the following command:

```ps1
podman machine start
cross build --target x86_64-unknown-linux-gnu --release --manifest-path extension/Cargo.toml
```

## Android (Experimental)

> [!WARNING]
> [gdext] support for Android is currently in its early stages. For more details, please refer to <https://github.com/godot-rust/gdext/issues/470>.

### From Linux

Install the necessary dependencies with the following command:

```sh
paru -S android-sdk android-ndk android-studio # Arch Linux
rustup target add aarch64-linux-android
cargo install cargo-ndk
```

```sh
cd extension
env ANDROID_NDK_HOME=/opt/android-ndk cargo ndk --target arm64-v8a build --release --features godot/experimental-threads
cd ..
mkdir -p build/android
```

The **Debug** build package can be exported directly via the following command:

```sh
godot --headless --export-debug "Android" build/android/sokoban.apk
```

Exporting a Release build requires generating a Keystore for signing. Install and use `archlinux-java` to specify a default JDK, then use the `keytool` command to generate the Keystore.

The following steps are also required to export the **Release** package:

```sh
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 10000 -deststoretype pkcs12
```

Open the **Export** interface and set the **Release** path under **Keystore** (`keystore/release`) to the location of the generated file. Then, configure the following two properties:

- **Release User** (`keystore/release_user`): `androiddebugkey`.
- **Release Password** (`keystore/release_password`): `android`.

Then, the Release build package can be exported via the following command:

```sh
godot --headless --export-release "Android" build/android/sokoban.apk
```

### From Windows

On Windows, the SDK and NDK can be installed via Android Studio.

```sh
scoop install android-studio
```

In Android Studio, navigate to `SDK Manager | Languages & Frameworks | Android SDK | SDK Tools` to select and install the following components:

- `Android SDK Build-Tools`
- `NDK (Side by side)`

```ps1
$Env:ANDROID_NDK_HOME="<PATH/TO/NDK>" # The default NDK path is: `$Env:LOCALAPPDATA\Android\Sdk\ndk`
cd extension
cargo ndk --target arm64-v8a build --release --features godot/experimental-threads
cd ..
```

## WASM (Experimental)

> [!WARNING]
> [gdext] support for WASM is currently in its early stages. For more details, please refer to <https://godot-rust.github.io/book/toolchain/export-web.html>.

### From Windows

> [!WARNING]
> **Do not** use the `--manifest-path` parameter here, as it will cause `.cargo/config.toml` to be ignored.

```ps1
scoop install emscripten
emsdk install latest
```

```ps1
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly
rustup target add wasm32-unknown-emscripten --toolchain nightly
```

```ps1
emsdk activate latest
cd extension
cargo +nightly build -Zbuild-std --target wasm32-unknown-emscripten --release --features godot/experimental-wasm,godot/lazy-function-tables
cd ..
mkdir -p build/wasm
godot --headless --export-release "Web" build/wasm/index.html
```

[gdext]: https://github.com/godot-rust/gdext
