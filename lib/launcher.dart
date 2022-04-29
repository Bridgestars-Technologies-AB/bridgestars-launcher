




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




class Launcher {

  String root='';
  String downloadPath='';
  String extractDir='';
  String gameDir='';
  String? _getMacExecutablePath() => _findMacExecutable(extractDir);
  String? _getWindowsExecutablePath() => _findWindowsExecutable(extractDir); //TODO CHECK INITIALIZATION
  Future<bool> downloadZipExists() => new File(downloadPath).exists();

  //TODO keep this link in the cloud and fetch link depending on version number.
  String getDownloadLink() =>
      'https://onedrive.live.com/download?cid=3F5E79BDE61E7EA5&resid=3F5E79BDE61E7EA5%2128381&authkey=ALH_V94FQ3PnTjY';

  String appVersionPath='';
  String launcherVersionPath='';

  Launcher._(){}

  static Future<Launcher> create() async {
    var l = new Launcher._();
    l.root = (await getApplicationSupportDirectory()).path;
    l.appVersionPath = l.root + "/appVersion.data";
    l.launcherVersionPath = l.root + "/launcherVersion.data";
    l.downloadPath = l.root + "/download.zip";
    l.extractDir = l.root + "/game";
    Directory(l.extractDir).createSync();
    var f = new File(l.appVersionPath);
    if(!f.existsSync()) f.createSync();

    return l;
  }

  Future<bool> executableExists() async {
    if(Platform.isMacOS) return _getMacExecutablePath() != null;
    if(Platform.isWindows) return _getWindowsExecutablePath() != null;
    return false;
  }



  //#region Run


  /// Runs the executable, figures out operating system.
  Future runApp() async {
    if(await executableExists()) {
      if (Platform.isMacOS) {
        var path = _getMacExecutablePath()!;
        _rewriteMacExecutablePermission(path);
        _runMacExecutable(path);
      }
      else if (Platform.isWindows) {
        var path = _getWindowsExecutablePath()!;
        _runWindowsExecutable(path);
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

  String? _findMacExecutable(String folderPath) {
    var dir = Directory(folderPath).listSync(recursive: true).toList();
    var app = dir.map((e) => e.path).firstWhere((element) => element.endsWith('.app'), orElse: () => '');
    return app.isEmpty ? null : app;
  }

  String? _findWindowsExecutable(String folderPath) {
    var dir = Directory(folderPath).listSync(recursive: true).toList();
    var exe = dir.map((e) => e.path).firstWhere((e) => e == 'Bridgestars.exe', orElse: () => '');
    return exe.isEmpty ? null : exe;
  }
  //#endregion


  Future install() async {
    await _unzip(downloadPath, extractDir);
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
    return;
  }



  Future download(void Function(ProgressInfo) callback) async {
    return _downloadFile(getDownloadLink(), downloadPath, callback);
  }

  Future _downloadFile(String uri, String savePath,
      void Function(ProgressInfo) callback) async {
    print("DOWNLOADING");


    int lastRcv = 0;
    var lastTime = new DateTime.now();
    Duration diff() => new DateTime.now().difference(lastTime);
    double calcSpeed(rcv) => (rcv - lastRcv) / (diff().inMicroseconds);
    double progress = 0;
    double speed = 0;
    double secondsLeft = 0;
    void calcProgress(int rcv, int total) {
      progress = ((rcv / total) * 100);
      speed = calcSpeed(rcv);
      secondsLeft = ((total - rcv) / speed)/1e6;
    }

    await Dio().download(
      uri,
      savePath,
      onReceiveProgress: (rcv, total) {
        //print(
        //    'received: ${rcv.toStringAsFixed(0)} out of total: ${total.toStringAsFixed(0)}');
        calcProgress(rcv, total);
        callback(new ProgressInfo(
            progress.toStringAsFixed(1), speed.toStringAsFixed(1) + " MB/s",
            secondsLeft.toStringAsFixed(0))); //.toStringAsFixed(0);
      },
      deleteOnError: true,
    );
    return;
  }

  //#region version control


  //

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
    var lines = new File(appVersionPath).readAsLinesSync();
    if(lines.length != 2) return null;
    return Version.parse(lines[0], lines[1]);
  }

  Future setLocalAppVersion(Version v) async {
    new File(appVersionPath).writeAsString(v.getNbr() + "\n" + v._url);
  }



//#endregion

}




//#region data classes

class ProgressInfo{
  ProgressInfo(this.progress, this.speed, this.timeLeft);
  String progress;
  String speed;
  String timeLeft;
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