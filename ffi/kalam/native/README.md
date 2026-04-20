# Warning: current ffi codes are only compatible with SwiftMTP 1.0.x

### Initial setup

```shell script
xcode-select --install
brew install pkg-config
```


### Build

- Add the required changes to the kalam kernel 

```shell script
cd ffi/kalam/native
go get -u
```

- Upgrade a go package
```shell
cd ffi/kalam/native

# go get github.com/<org-name>/<package-name>@<git-commit-hash>

#example: go get github.com/ganeshrvel/go-mtpfs@<git-commit-hash>
#example: go get github.com/ganeshrvel/go-mtpx@<git-commit-hash>
```

```shell
# cd to the project root
cd </path/to/SwiftMTP/>
chmod +x ./ffi/kalam/native/scripts/build.sh
./ffi/kalam/native/scripts/build.sh
```



**Troubleshooting**

- If you keep getting `fatal error: 'stdlib.h' file not found xcode`, then:
- Add these line to the ~/.zshrc file (`nano ~/.zshrc`)

```shell
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
```

```shell
source ~/.zshrc
```



- In case of permission error with sentry follow this url: https://docs.npmjs.com/resolving-eacces-permissions-errors-when-installing-packages-globally#manually-change-npms-default-directory


# Do not follow the instructions below. These are old commands are they are maintained just for the sake of documentation

- Remove libusb `brew remove libusb`
- Download the required versions of the `libusb`.
  - Refer `Brew download for another OS version` for more
- Copy the `/path/to/libusb/arm64_big_sur/1.0.25/lib/libusb-1.0.0.dylib` to the `build/mac/bin/libusb.dylib`
- Make a backup copy of `/path/to/libusb/arm64_big_sur/1.0.25/lib/libusb-1.0.0.dylib`
- change the `rpath` using: `install_name_tool -id @loader_path/libusb.dylib /path/to/libusb/arm64_big_sur/1.0.25/lib/libusb-1.0.0.dylib`
- Open `/path/to/libusb/arm64_big_sur/1.0.25/lib/pkgconfig/libusb-1.0.pc`
  - Edit `prefix=@@HOMEBREW_CELLAR@@/libusb/1.0.25` as `prefix=/path/to/libusb/amd64_mojave/1.0.25`
  - Save it
- Example commands to build the kalam go binaries:

##### Examples:
```shell
(
        cd ./ffi/kalam/native && CGO_ENABLED=1 \
        PKG_CONFIG_PATH='/path/to/libusb/arm64_big_sur/1.0.25/lib/pkgconfig' \
        CGO_CFLAGS='-mmacosx-version-min=12.0' \
        CGO_LDFLAGS='-mmacosx-version-min=12.0' \
        GOARCH=arm64 GOOS=darwin \
        go build \
        -v -a -trimpath \
        -o ../../../bin/arm64-kalam.dylib -buildmode=c-shared ./*.go
    )
```

```shell
(
        cd ./ffi/kalam/native && CGO_ENABLED=1 \
        PKG_CONFIG_PATH='/path/to/libusb/arm64_big_sur/1.0.25/lib/pkgconfig' \
        CGO_CFLAGS='-Wno-deprecated-declarations' \
        GOARCH=arm64 GOOS=darwin \
        go build \
        -v -a -trimpath \
        -o ../../../build/mac/bin/arm64/kalam_debug_report kalam_debug_report/*.go
    )
```


## Do not follow the sections below anymore. These commands are deprecated
### libusb otool commands:

Build:
```shell
brew install libusb
brew info libusb
```

- Copy the path in the terminal; eg: `/opt/homebrew/Cellar/libusb/1.0.25`

```shell script
sudo install_name_tool -id "@loader_path/libusb.dylib" <libusb-path>/lib/libusb-1.0.0.dylib

# eg: sudo install_name_tool -id "@loader_path/libusb.dylib" /opt/homebrew/Cellar/libusb/1.0.25/lib/libusb-1.0.0.dylib

cp /opt/homebrew/Cellar/libusb/1.0.25/lib/libusb-1.0.dylib  ./build/mac/bin/libusb.dylib
```
