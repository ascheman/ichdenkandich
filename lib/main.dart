import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/subjects.dart';

import 'launchapplication.dart';

final ichDenkAnDich = 'Ich denk an Dich!';

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
  log.d("Starting main");
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
  log.d("Initialized notifications");

  runApp(IchDenkAnDichApp());
}

class IchDenkAnDichApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ichDenkAnDich,
      theme: ThemeData(
        primarySwatch: Colors.red,
        floatingActionButtonTheme: FloatingActionButtonThemeData(),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: ichDenkAnDich),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MethodChannel platform =
      MethodChannel('crossingthestreams.io/resourceResolver');

  // TODO find out hot to best cope with languages and loacles
  static final defaultLanguage = 'de';
  static final LocaleType defaultLocaleType = LocaleType.de;

//  static final Locale defaultLocale = Locale(defaultLanguage);

  final testScheduledNotificationDelay = 5;

  String targetPerson = "Katrin";
  String message;

  // TODO provide value type (with proper formatting of value for output)
  DateTime selectedDateTime;
  String selectedDateTimeFormatted;

  // TODO provide value type (with proper formatting of value for output)
  DateTime scheduledDateTime = null;
  String scheduledDateTimeFormatted;

  bool repeatAfter24h = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting(defaultLanguage);
    _requestIOSPermissions();
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();
    setSelectedDateTime(DateTime.now());
    setScheduledDateTime(null);
    message = "Liebe $targetPerson,\nmusste dank '$ichDenkAnDich'\ngerade an dich denken! <3";
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
      log.d("Received local Notification '$receivedNotification'");
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
                        LaunchApplication(receivedNotification.payload, message),
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
      log.d("Received Notification with Payload '$payload'");
      setState(() {
//        log.d("State is dirty now");
        reschedule();
      });
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LaunchApplication(payload, message)),
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
      locale: defaultLocaleType,
    );

    if (null == _selectedDateTime) {
      return currentValue;
    }
    return _selectedDateTime;
  }

  static String _formatted(DateTime dateTime) {
    var formatter = DateFormat.yMd("de").add_jms();
    String formatted = formatter.format(dateTime);

    return formatted;
  }

  void setSelectedDateTime(DateTime dateTime) {
    selectedDateTime = dateTime;
    selectedDateTimeFormatted = _formatted(dateTime);
    log.d("Selected time '$scheduledDateTimeFormatted'");
  }

  void setScheduledDateTime(DateTime dateTime) {
    if (null != dateTime) {
      scheduledDateTime = dateTime;
      scheduledDateTimeFormatted = _formatted(dateTime);
    } else {
      scheduledDateTimeFormatted = "None";
    }
    log.d("Scheduled time '$scheduledDateTimeFormatted'");
  }

  void reschedule() {
    if (repeatAfter24h && null != scheduledDateTime) {
      _scheduleNotification(scheduledDateTime.add(Duration(days: 1)));
    } else {
      _cancelNotification();
      log.d("No repeat required to reschedule");
    }
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
                      Text('Select:'),
                      IconButton(
                        icon: Icon(
                          Icons.calendar_today,
                          semanticLabel: "Select reminder date/time",
                        ),
                        onPressed: () async {
                          final newTime =
                              await _selectDateTime(context, selectedDateTime);
                          setState(() {
                            setSelectedDateTime(newTime);
                          });
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Selected: $selectedDateTimeFormatted'),
                        ),
                      ),
                      PaddedRaisedButton(
                        buttonText: 'Schedule',
                        onPressed: () async {
                          await _scheduleNotification(selectedDateTime);
                          setState(() {
                            // No action required here - only render new scheduled date/time
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: <Widget>[
                      Text('Repeat(24h):'),
                      Padding(
                        padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                        child: Checkbox(
                          value: repeatAfter24h,
                          onChanged: (bool value) {
                            setState(() {
                              repeatAfter24h = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Scheduled: $scheduledDateTimeFormatted'),
                        ),
                      ),
                      PaddedRaisedButton(
                        buttonText: 'Cancel',
                        onPressed: () async {
                          await _cancelNotification();
                          setState(() {
                            // No action required here - only render new scheduled date/time
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                    padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Initial message (copy & paste in called reminder app)',
                      ),
                      initialValue: message,
                      maxLines: 5,
                      onChanged: (String textinput) {
                        setState(() {
                          message = textinput;
                        });
                      },
                    )),
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
                  buttonText:
                      'Schedule notification to appear in $testScheduledNotificationDelay seconds',
                  onPressed: () async {
                    setState(() {
                      var scheduledNotificationDateTime = DateTime.now().add(
                          Duration(seconds: testScheduledNotificationDelay));
                      _scheduleNotification(scheduledNotificationDateTime);
                    });
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
    await flutterLocalNotificationsPlugin.show(0, '$ichDenkAnDich (Local)',
        'Send Greetings to "$targetPerson"', platformChannelSpecifics,
        payload: targetPerson);
  }

  Future<void> _cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
    setScheduledDateTime(null);
  }

  /// Schedules a notification that specifies a different icon, sound and vibration pattern
  Future<void> _scheduleNotification(DateTime scheduledDateTime) async {
    setScheduledDateTime(scheduledDateTime);
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
        '$ichDenkAnDich (Scheduled)',
        'Send Greetings to "$targetPerson"\n(at $scheduledDateTimeFormatted)',
        scheduledDateTime,
        platformChannelSpecifics,
        payload: targetPerson);
    log.d("Scheduled Notification for $scheduledDateTimeFormatted");
  }
}
