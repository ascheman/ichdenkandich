import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/subjects.dart';

import 'launchapplication.dart';

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

  final testScheduledNotificationDelay = 10;

  DateTime reminderTime = DateTime.now();

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

  // This is kind of functional - If the value is not changed the current value is returned
  Future<DateTime> _selectDateTime(
      BuildContext context, DateTime currentValue) async {
    final DateTime _selectedDateTime = await DatePicker.showDateTimePicker(
      context,
      showTitleActions: true,
      currentTime: currentValue,
      minTime: DateTime.now(),
      locale: LocaleType.de,
    );

    if (null == _selectedDateTime) {
      return currentValue;
    }
    return _selectedDateTime;
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
                      'Tap on a notification when it appears\nto proceed to greeting application'),
                ),
                Padding(
                    padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Greet which person?',
                      ),
                      initialValue: targetPerson,
                      onChanged: (String textinput) {
                        setState(() {
                          targetPerson = textinput;
                        });
                      },
                    )),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: Icon(
                          Icons.calendar_today,
                          semanticLabel: "Select reminder date/time",
                        ),
                        onPressed: () async {
                          final newTime =
                              await _selectDateTime(context, reminderTime);
                          setState(() {
                            log.d(
                                "Selected a new reminder date/time: $newTime");
                            reminderTime = newTime;
                          });
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Selected: $reminderTime'),
                        ),
                      ),
                      PaddedRaisedButton(
                        buttonText: 'Schedule',
                        onPressed: () async {
                          await _scheduleTestNotification(reminderTime);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(
                  color: Colors.red,
                  height: 20,
                  thickness: 5,
                  indent: 0,
                  endIndent: 0,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                  child: Text.rich(
                    TextSpan(
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                        text:
                            'Developers Corner (to be removed or hidden in final release)'),
                  ),
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
                      'Schedule notification to appear in ${testScheduledNotificationDelay} seconds, custom sound, red colour, large icon, red LED',
                  onPressed: () async {
                    var scheduledNotificationDateTime = DateTime.now()
                        .add(Duration(seconds: testScheduledNotificationDelay));
                    await _scheduleTestNotification(
                        scheduledNotificationDateTime);
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
  Future<void> _scheduleTestNotification(
      DateTime scheduledNotificationDateTime) async {
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
