import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appavailability/flutter_appavailability.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/subjects.dart';

final log = Logger();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();
final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();
NotificationAppLaunchDetails notificationAppLaunchDetails;

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  ReceivedNotification({
    @required this.id,
    @required this.title,
    @required this.body,
    @required this.payload,
  });
}

class PaddedRaisedButton extends StatelessWidget {
  final String buttonText;
  final VoidCallback onPressed;

  const PaddedRaisedButton({
    @required this.buttonText,
    @required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
      child: RaisedButton(child: Text(buttonText), onPressed: onPressed),
    );
  }
}

Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
  // Note: permissions aren't requested here just to demonstrate that can be done later using the `requestPermissions()` method
  // of the `IOSFlutterLocalNotificationsPlugin` class
  var initializationSettingsIOS = IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification:
          (int id, String title, String body, String payload) async {
        didReceiveLocalNotificationSubject.add(ReceivedNotification(
            id: id, title: title, body: body, payload: payload));
      });
  var initializationSettings = InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
    if (payload != null) {
      log.d('notification payload: $payload');
    }
    selectNotificationSubject.add(payload);
  });

  runApp(IchDenkAnDichApp());
}

class IchDenkAnDichApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ich denk an Dich!',
      theme: ThemeData(
        primarySwatch: Colors.red,
        floatingActionButtonTheme: FloatingActionButtonThemeData(),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Ich Denk An Dich'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MethodChannel platform =
      MethodChannel('crossingthestreams.io/resourceResolver');

  String targetPerson = "Katrin";

  @override
  void initState() {
    super.initState();
    _requestIOSPermissions();
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();
  }

  void _requestIOSPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _configureDidReceiveLocalNotificationSubject() {
    didReceiveLocalNotificationSubject.stream
        .listen((ReceivedNotification receivedNotification) async {
      log.d("Received local Notification '${receivedNotification}'");
      await showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body)
              : null,
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text('Ok'),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LaunchApplication(receivedNotification.payload),
                  ),
                );
              },
            )
          ],
        ),
      );
    });
  }

  void _configureSelectNotificationSubject() {
    selectNotificationSubject.stream.listen((String payload) async {
      log.d("Received Notification with Payload '${payload}'");
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LaunchApplication(payload)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                  child: Text(
                      'Tap on a notification when it appears to trigger navigation'),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Did notification launch app? ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              '${notificationAppLaunchDetails?.didNotificationLaunchApp ?? false}',
                        )
                      ],
                    ),
                  ),
                ),
                if (notificationAppLaunchDetails?.didNotificationLaunchApp ??
                    false)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Launch notification payload: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: notificationAppLaunchDetails.payload,
                          )
                        ],
                      ),
                    ),
                  ),
                PaddedRaisedButton(
                  buttonText: 'Show plain notification with payload',
                  onPressed: () async {
                    await _showNotification();
                  },
                ),
                PaddedRaisedButton(
                  buttonText: 'Cancel notification',
                  onPressed: () async {
                    await _cancelNotification();
                  },
                ),
                PaddedRaisedButton(
                  buttonText:
                      'Schedule notification to appear in 5 seconds, custom sound, red colour, large icon, red LED',
                  onPressed: () async {
                    await _scheduleNotification();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNotification() async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your channel id', 'your channel name', 'your channel description',
        importance: Importance.Max, priority: Priority.High, ticker: 'ticker');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, 'Ich denk an Dich (Local)',
        'Send Greetings to "${targetPerson}"', platformChannelSpecifics,
        payload: targetPerson);
  }

  Future<void> _cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  /// Schedules a notification that specifies a different icon, sound and vibration pattern
  Future<void> _scheduleNotification() async {
    var scheduledNotificationDateTime =
        DateTime.now().add(Duration(seconds: 5));
    var vibrationPattern = Int64List(4);
    vibrationPattern[0] = 0;
    vibrationPattern[1] = 1000;
    vibrationPattern[2] = 5000;
    vibrationPattern[3] = 2000;

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your other channel id',
        'your other channel name',
        'your other channel description',
        icon: 'secondary_icon',
        sound: RawResourceAndroidNotificationSound('slow_spring_board'),
        largeIcon: DrawableResourceAndroidBitmap('sample_large_icon'),
        vibrationPattern: vibrationPattern,
        enableLights: true,
        color: const Color.fromARGB(255, 255, 0, 0),
        ledColor: const Color.fromARGB(255, 255, 0, 0),
        ledOnMs: 1000,
        ledOffMs: 500);
    var iOSPlatformChannelSpecifics =
        IOSNotificationDetails(sound: 'slow_spring_board.aiff');
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        0,
        'Ich denk an Dich (Scheduled)',
        'Send Greetings to "${targetPerson}"',
        scheduledNotificationDateTime,
        platformChannelSpecifics,
        payload: targetPerson);
    log.d("Scheduled Notification for " +
        scheduledNotificationDateTime.toIso8601String());
  }
}

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

  Future<String> appEnablementState(String package_name) async {
    if (Platform.isAndroid) {
      if (await AppAvailability.isAppEnabled(package_name)) {
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
                    print("App ${installedApps[index]["app_name"]} launched!");
                  }).catchError((err) {
                    Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text(
                            "App ${installedApps[index]["app_name"]} not found!")));
                    print(err);
                  });
                }),
          );
        },
      ),
    );
  }
}
