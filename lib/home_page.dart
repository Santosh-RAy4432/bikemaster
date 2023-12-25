// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, avoid_print, library_private_types_in_public_api, unnecessary_null_comparison, unused_local_variable, prefer_const_literals_to_create_immutables
import 'package:bikemaster/changen_password.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'login_page_rider.dart';

void displayLocalNotificationAtTop(String title, String message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.grey[800],
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

class RiderHomePage extends StatefulWidget {
  @override
  _RiderHomePageState createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String currentLocation = '';
  Map<String, dynamic> riderprofile = {};

  @override
  void initState() {
    super.initState();
    fetchCurrentLocation();
    initializeNotificationPlugin();
    fetchRiderprofileData();
    updatefcmToken();
    configureFirebaseMessaging();
  }

  final AndroidNotificationChannel androidNotificationChannel =
      AndroidNotificationChannel(
    'my_custom_channel_id',
    'My Custom Notifications',
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void initializeNotificationPlugin() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);
  }

  void configureFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        displayForegroundNotification(message);
      }
    });
  }

  void displayForegroundNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'my_custom_channel_id',
      'My Custom Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? 'BikeMaster',
      message.notification?.body ??
          'Your Request has been accepted by mechanic',
      platformChannelSpecifics,
      payload: 'foreground_notification',
    );
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'my_custom_channel_id',
      'My Custom Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void fetchRiderprofileData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot riderDoc = await FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .get();
      if (riderDoc.exists) {
        // Update the class-level riderprofile map with the fetched data
        setState(() {
          riderprofile = riderDoc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  Future<void> fetchCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      currentLocation =
          'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
    });
  }

  void updatefcmToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      // Update the token in Firestore
      User? user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    }
  }

  void initializeFirebaseMessaging() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened app: ${message.notification?.title}');
      print('Message opened app: ${message.notification?.body}');
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received message: ${message.notification?.title}');
      print('Received message: ${message.notification?.body}');
      displayForegroundNotification(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bike Master'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mechanics')
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData) {
                  List<QueryDocumentSnapshot> documents = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (BuildContext context, int index) {
                      Map<String, dynamic> mechanicData =
                          documents[index].data() as Map<String, dynamic>;
                      String riderId = documents[index].id;
                      return MechanicBox(
                        mechanicData: mechanicData,
                        currentLocation: currentLocation,
                        onSendRequest: () {
                          sendRequestToMechanic(
                            mechanicData,
                            currentLocation,
                          );
                        },
                      );
                    },
                  );
                }

                return Text('No data available.');
              },
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () async {
                // Retrieve the authenticated user
                User? user = _auth.currentUser;

                if (user != null) {
                  // Fetch mechanic data from Firestore
                  DocumentSnapshot riderDoc = await FirebaseFirestore.instance
                      .collection('riders')
                      .doc(user
                          .uid) // Assuming the mechanic's UID is used as the document ID
                      .get();
                  if (riderDoc.exists) {
                    setState(() {
                      riderprofile = riderDoc.data() as Map<String, dynamic>;
                    });
                  }
                }
                Navigator.pop(context);
              },
            ),
            if (riderprofile != null)
              Container(
                margin: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100.0,
                      height: 30.0,
                      child: Card(
                        child: Text(
                          '${riderprofile['name'] ?? 'N/A'}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100.0,
                      height: 30.0,
                      child: Card(
                        child: Text(
                          '${riderprofile['address'] ?? 'N/A'}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100.0,
                      height: 30.0,
                      child: Card(
                        child: Text(
                          '${riderprofile['phoneNumber'] ?? 'N/A'}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200.0,
                      height: 30.0,
                      child: Card(
                        child: Text(
                          '${riderprofile['email'] ?? 'N/A'}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: Icon(Icons.vpn_key),
              title: Text('Change Password'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (BuildContext context) {
                    return ChangePassword();
                  }),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (BuildContext context) {
                    return LoginPage();
                  }),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.arrow_back,
                  ),
                ],
              ),
              onTap: () {
                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void sendRequestToMechanic(
    Map<String, dynamic> mechanicData,
    String currentLocation,
  ) async {
    String mechanicName = mechanicData['name'];
    String mechanicEmail = mechanicData['email'];
    print('Sent request to $mechanicName ($mechanicEmail)');
    print('Current Location: $currentLocation');

    // Retrieve the authenticated user
    User? user = _auth.currentUser;

    if (user != null) {
      // Update the rider's current location in Firestore
      await FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .update({'currentLocation': currentLocation, 'status': 'requested'});
    }

    showRequestSentMessage();
  }

  void showRequestSentMessage() {
    displayLocalNotificationAtTop(
        'Request Sent', 'Your request has been sent successfully.');
    // Call the new method to display a notification at the top of the screen
    displayNotification(); // Display the notification
  }

  void displayNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'my_custom_channel_id',
      'My Custom Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Request Sent',
      'Your request has been sent successfully.',
      platformChannelSpecifics,
      payload: 'request_sent',
    );
  }
}

class MechanicBox extends StatelessWidget {
  final Map<String, dynamic> mechanicData;
  final String currentLocation;
  final VoidCallback onSendRequest;

  const MechanicBox({
    required this.mechanicData,
    required this.currentLocation,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10.0),
      padding: EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mechanicData['name'],
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.0),
          Text('Email: ${mechanicData['email']}'),
          Text('Phone Number: ${mechanicData['phoneNumber']}'),
          Text('Workshop Name: ${mechanicData['workshop']}'),
          Text('Address: ${mechanicData['address']}'),
          SizedBox(height: 8.0),
          ElevatedButton(
            onPressed: onSendRequest,
            child: Text('Send Request'),
          ),
        ],
      ),
    );
  }
}
