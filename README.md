# bridgestars_launcher

A launcher for the Bridgestars unity application.

## Getting Started

1. Install flutter [flutter_docs](https://docs.flutter.dev/get-started/install?gclid=CjwKCAjwyryUBhBSEiwAGN5OCCEYVlmlGoW26l56rdUzCRWFZIimvAs_iNHeEIiFRbOBxSB3LrkVnBoCU94QAvD_BwE&gclsrc=aw.ds)

### For MAC
2. On the top level, type: `flutter build macos`
3. Go into `build/macos/Build/Products/Release` and zip the `Bridgestars Launcher.app` file for distribution, 


### For WINDOWS
2. On the top level, type: `flutter build windows`
3. Follow the guide at [flutter_docs](https://docs.flutter.dev/desktop/windows#building-your-own-zip-file-for-windows)


## Guidelines
- rename the executable to `Bridgestars.exe`/`Bridgestars.app` 
- rename the `.zip` file to `Bridgestars for Mac.zip`/`Bridgestars for Windows.zip`
- when getting the download link from drive it will be formatted as. 
```
https://drive.google.com/file/d/{id}/view
But the direct download link is:
https://drive.google.com/u/0/uc?id={id}&export=download&confirm=t
```

I will later create a tool to generate that link.


