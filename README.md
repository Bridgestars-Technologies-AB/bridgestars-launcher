# bridgestars_launcher

A launcher for the Bridgestars unity application.

## Getting Started

1. Install flutter [flutter_docs](https://docs.flutter.dev/get-started/install?gclid=CjwKCAjwyryUBhBSEiwAGN5OCCEYVlmlGoW26l56rdUzCRWFZIimvAs_iNHeEIiFRbOBxSB3LrkVnBoCU94QAvD_BwE&gclsrc=aw.ds)

### For MAC

2. Needs to build VLCKit to use dart_vlc
   To build it from source just run the following commands (-x builds for mac)

```
git clone https://code.videolan.org/videolan/VLCKit.git
cd vlckit
bash compileAndBuildVLCKit.sh -x
```

ps. it probably took an hour to build.

3. On the top level, type: `flutter build macos`
4. Go into `build/macos/Build/Products/Release` and zip the `Bridgestars Launcher.app` file for distribution,

### For WINDOWS

1. may need to first download all releases from S3
2. On the top level, type: `make build_win PASS={certpass}`
3. `make sign_win PASS={certpass}`
4. upload to S3
