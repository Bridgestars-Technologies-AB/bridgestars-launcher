




import 'dart:ffi';
import 'dart:io';

import 'package:desktop_window/desktop_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'dart:convert';


enum LauncherState{
  canDownload, canInstall, canUpdate, canRun,
  waiting, downloading, installing, uninstalling, updating, running
}

class Launcher {

  //PATHS
  String root='';
  String getArchivePath() => root + "/download.zip";
  Future<bool> archiveExists() => new File(getArchivePath()).exists();
  String getExtractDir() => root + "/game";
  String getGameDir() => getExtractDir() + "";

  //EXECUTABLES
  String? macExecutablePath = null;
  String? windowsExecutablePath = null;
  bool canRun() =>
      (Platform.isMacOS && macExecutablePath != null) ||
      (Platform.isWindows && windowsExecutablePath != null);


  //VERSION CONTROL
  Version? localAppVersion = null;
  Version? remoteAppVersion = null;
  bool canUpgrade() => remoteAppVersion != null && (localAppVersion == null || localAppVersion! < remoteAppVersion!);
  String getAppVersionPath() => root + "/.appVersion";
  String getLauncherVersionPath() => root + "/.launcherVersion";


  //STATE
  LauncherState _currentState = LauncherState.waiting;
  void _setState(LauncherState s){
    _currentState = s;
    stateListener(s, null);
  }
  void _setProgress(DownloadInfo p) => stateListener(_currentState, p);
  LauncherState getState() => _currentState;
  Function(LauncherState, DownloadInfo?) stateListener = (s,d) => {};

  //CONSTRUCTOR
  Launcher._(Function(LauncherState, DownloadInfo?) listener){
    this.stateListener = listener;
  }



  //async INIT
  static Future<Launcher> create(Function(LauncherState, DownloadInfo?) listener) async {
    var l = new Launcher._(listener);
    //paths
    l.root = (await getApplicationSupportDirectory()).path;
    Directory(l.getExtractDir()).createSync();
    l._updateExecutablePaths();

    //version control
    var f = new File(l.getAppVersionPath());
    if(!f.existsSync()) f.createSync();
    l.localAppVersion = await l.getLocalAppVersion();
    l.remoteAppVersion = await l.getRemoteAppVersion();
    l.updateState();

    return l;
  }

  Future handleBtnPress() async {
    switch (_currentState){

      case LauncherState.canDownload:
        _setState(LauncherState.downloading);
        await download(_setProgress);
        _setState(LauncherState.installing);
        await install();
        updateState();
        break;

      case LauncherState.canInstall:
        _setState(LauncherState.installing);
        await install();
        updateState();
        break;

      case LauncherState.canUpdate:
        _setState(LauncherState.updating);
        await uninstall();
        await setLocalAppVersion(remoteAppVersion!);
        await download(_setProgress);
        await install();
        updateState();
        break;

      case LauncherState.canRun:
        await runApp();
        //TODO: Hide window
        return LauncherState.running;

      case LauncherState.waiting:
      case LauncherState.downloading:
      case LauncherState.installing:
      case LauncherState.uninstalling:
      case LauncherState.updating:
      case LauncherState.running:
        //Dont care
        //maybe open alert
        break;
    }
  }

  Future<LauncherState> updateState() async {
    if (canUpgrade())
      _setState(LauncherState.canUpdate);
    else if (await _updateExecutablePaths())
      _setState(LauncherState.canRun);
    else if (await archiveExists())
      _setState(LauncherState.canInstall);
    else
      _setState(LauncherState.canDownload);
    return _currentState;
  }


  Future<bool> _updateExecutablePaths() async {
    if(Platform.isMacOS) macExecutablePath = await _findMacExecutable(getExtractDir());
    if(Platform.isWindows) windowsExecutablePath = await _findWindowsExecutable(getExtractDir());
    print(macExecutablePath);
    return canRun();
    if(Platform.isWindows) return windowsExecutablePath != null;
    return false;
  }



  //#region Run

  /// Runs the executable, figures out operating system.
  Future runApp() async {
    if(canRun()) {
      if (Platform.isMacOS) {
        _rewriteMacExecutablePermission(macExecutablePath!);
        _runMacExecutable(macExecutablePath!);
      }
      else if (Platform.isWindows) {
        _runWindowsExecutable(windowsExecutablePath!);
      }
      else
        throw new Exception(
            "Platform not supported: " + Platform.operatingSystem);
    }
    else throw new Exception("Executable not found");
  }

  ///TODO not sure this works
  void _runWindowsExecutable(String path) {
    var result = Process.runSync('cmd', ['start',path]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }

  void _rewriteMacExecutablePermission(String path) {
    //Write permission to execute app
    var innerExecutable =  Directory(path+"/Contents/MacOS").listSync().first.path;
    var result = Process.runSync('chmod', ["+x", innerExecutable]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }

  ///runPath should point to an app executable
  void _runMacExecutable(String path) {
    print("RUNNING");
    //Run
    var result = Process.runSync('open', [path]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }

  Future<String?> _findMacExecutable(String folderPath) async {
    var dir = Directory(folderPath).listSync(recursive: true).toList();
    var app = dir.map((e) => e.path).firstWhere((element) => element.endsWith('.app'), orElse: () => '');
    return app.isEmpty ? null : app;
  }

  Future<String?> _findWindowsExecutable(String folderPath) async {
    var dir = Directory(folderPath).listSync(recursive: true).toList();
    var exe = dir.map((e) => e.path).firstWhere((e) => e == 'Bridgestars.exe', orElse: () => '');
    return exe.isEmpty ? null : exe;
  }
  //#endregion

  //region upgrade

  Future _upgradeAppVersion(Version newVersion, Function()) async {
    await uninstall();
  }

  //endregion

  //#region install
  Future install() async {
    await _unzip(getArchivePath(), getExtractDir());
    await _updateExecutablePaths();
    //TODO remove zip file
  }

  ///Should work on both mac and windows
  Future _unzip(String zipPath, String unzipPath) async {
    print("EXTRACTING");
    // Use an InputFileStream to access the zip file without storing it in memory.

    var bytes = new File(zipPath).readAsBytesSync();
    var archive = ZipDecoder().decodeBytes(bytes);
    for (var file in archive) {
      var fileName = '$unzipPath/${file.name}';
      if (file.isFile) {
        var outFile = File(fileName);
        //_tempImages.add(outFile.path);
        if(!fileName.contains('__MACOSX')) {
          outFile = await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content);
        }
      }
    }
    await _removeArchive();
    return;
  }
  //#endregion install

  //region uninstall

  Future uninstall() async {
    await _removeArchive();
    await _removeGameDir();
  }

  Future _removeGameDir() async {
    if(new Directory(getGameDir()).existsSync())
      new Directory(getGameDir()).listSync().forEach((file) => file.deleteSync(recursive: true));
  }

  Future _removeArchive() async {
    if(await archiveExists())
      new File(getArchivePath()).deleteSync();
  }


  //endregion

  //#region download
  Future download(void Function(DownloadInfo) callback) async {
    if(localAppVersion != null){
      return _downloadFile(localAppVersion!.getUrl(), getArchivePath(), callback);
    }
    throw new Exception("Current version not set");
  }

  Future _downloadFile(String uri, String savePath,
      void Function(DownloadInfo) callback) async {
    print("DOWNLOADING");


    int lastRcv = 0;
    var lastTime = new DateTime.now();
    Duration diff() => new DateTime.now().difference(lastTime);
    double calcSpeed(rcv) => (rcv - lastRcv) / (diff().inMicroseconds);
    double percentDone = 0;
    double speedMBs = 0;
    double secondsLeft = 0;
    void calcProgress(int rcv, int total) {
      percentDone = ((rcv / total) * 100);
      speedMBs = calcSpeed(rcv);
      secondsLeft = ((total - rcv) / speedMBs)/1e6;
    }

    await Dio().download(
      uri,
      savePath,
      onReceiveProgress: (rcv, total) {
        //print(
        //    'received: ${rcv.toStringAsFixed(0)} out of total: ${total.toStringAsFixed(0)}');
        calcProgress(rcv, total);
        callback(new DownloadInfo(
            percentDone, speedMBs, secondsLeft)); //.toStringAsFixed(0);
      },
      deleteOnError: true,
    );
    return;
  }
  //#endregion download

  //#region version control


  List<String> _getArrayFromFirestoreDoc(Map<String, dynamic> doc, String name){
    var xs = doc['fields'][name]['arrayValue']['values'] as List<dynamic>;
    return xs.map((e) => e['stringValue'].toString()).toList();
  }

  Future<Version> getRemoteAppVersion() async {
    var res = await http.get(Uri.parse('https://firestore.googleapis.com/v1/projects/bridge-fcee8/databases/(default)/documents/versions/game-mac'));
    var data = json.decode(res.body) as Map<String, dynamic>;
    List<String> versionNbrs = _getArrayFromFirestoreDoc(data, 'versionNbrs');
    List<String> urls = _getArrayFromFirestoreDoc(data, 'urls');
    return Version.parse(versionNbrs.last, urls.last)!;
  }

  Future<Version?> getLocalAppVersion() async {
    var lines = new File(getAppVersionPath()).readAsLinesSync();
    if(lines.length != 2) return null;
    return Version.parse(lines[0], lines[1]);
  }

  Future setLocalAppVersion(Version v) async {
    localAppVersion = v;
    new File(getAppVersionPath()).writeAsString(v.getNbr() + "\n" + v._url);
  }



//#endregion

}




//#region data classes

class DownloadInfo{
  DownloadInfo(this.percentDone, this.speedMBs, this.secondsLeft);
  double percentDone;
  double speedMBs;
  double secondsLeft;

  @override
  String toString() {
    return '${percentDone.toStringAsFixed(1)}%  ${speedMBs.toStringAsFixed(1)} MB/s  ${secondsLeft.toStringAsFixed(0)} s';
  }


}

bool isNumeric(String s) => int.tryParse(s) != null;

class Version extends Comparable{
  String getNbr() => _nbrs.join('.');
  var _nbrs = [0,0,0];
  var _url = '';
  String getUrl() => _url;
  String toString() => getNbr() + ";" + _url;

  Version._(List<int> nbrs, String url){
    _nbrs = nbrs;
    _url = url;
  }

  static Version? parse(String s, String url){
    var split = s.split('.');
    if(split.length == 3 && split.every(isNumeric)){
      return new Version._(split.map((e) => int.parse(e)).toList(), url);
    }
    return null;
  }

  bool operator >(Version other) => compareTo(other) == 1;
  bool operator <(Version other) => compareTo(other) == -1;
  @override
  bool operator ==(Object other) => other.runtimeType == Version && compareTo(other) == 0;


  @override
  int compareTo(other) {
    for(var i = 0; i < 3; i++){
      if(_nbrs[i] > other._nbrs[i]) return 1;
      else if(_nbrs[i] < other._nbrs[i]) return -1;
    }
    return 0;
  }
}

//#endregion