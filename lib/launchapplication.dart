import 'dart:async';
import 'dart:io';

import 'package:clipboard_manager/clipboard_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appavailability/flutter_appavailability.dart';
import 'package:logger/logger.dart';

final log = Logger();

class LaunchApplication extends StatefulWidget {
  LaunchApplication(this.payload);

  final String payload;

  @override
  State<StatefulWidget> createState() => LaunchApplicationState();
}

class LaunchApplicationState extends State<LaunchApplication> {
  String _payload;

  List<Map<String, String>> installedApps;

  List<Map<String, String>> iOSApps = [
    {"app_name": "Calendar", "package_name": "calshow://"},
    {"app_name": "Facebook", "package_name": "fb://"},
    {"app_name": "Whatsapp", "package_name": "whatsapp://"}
  ];

  Future<String> appEnablementState(String packageName) async {
    if (Platform.isAndroid) {
      if (await AppAvailability.isAppEnabled(packageName)) {
        return "Enabled";
      }
      return "Disabled";
    }
    return "Unknown";
  }

  Future<void> getApps() async {
    List<Map<String, String>> _installedApps;

    if (Platform.isAndroid) {
      _installedApps = await AppAvailability.getInstalledApps();
    } else if (Platform.isIOS) {
      // iOS doesn't allow to get installed apps.
      _installedApps = iOSApps;
      log.d(await AppAvailability.checkAvailability("calshow://"));
      // Returns: Map<String, String>{app_name: , package_name: calshow://, versionCode: , version_name: }
    }

    setState(() {
      _installedApps.forEach((element) async {
        var enablementState = await appEnablementState(element["package_name"]);
        log.d("Found app: $element['app_name'] (Enablement: $enablementState)");
      });
      installedApps = _installedApps;
    });
  }

  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
  }

  @override
  Widget build(BuildContext context) {
    if (installedApps == null) {
      getApps();
    }
    ClipboardManager.copyToClipBoard("Liebe $_payload, ich musste gerade an dich denken!");
    return Scaffold(
      appBar: AppBar(
        title: Text('Send Greetings to ${(_payload ?? '')} via'),
      ),
      body: ListView.builder(
        itemCount: installedApps == null ? 0 : installedApps.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(installedApps[index]["app_name"]),
            trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  Scaffold.of(context).hideCurrentSnackBar();
                  AppAvailability.launchApp(
                      installedApps[index]["package_name"])
                      .then((_) {
                    log.d("App ${installedApps[index]["app_name"]} launched!");
                  }).catchError((err) {
                    Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text(
                            "App ${installedApps[index]["app_name"]} not found!")));
                    log.e(err);
                  });
                }),
          );
        },
      ),
    );
  }
}
