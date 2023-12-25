// ignore_for_file: prefer_const_declarations, prefer_const_constructors, library_private_types_in_public_api, use_key_in_widget_constructors, unused_local_variable, prefer_const_literals_to_create_immutables, must_be_immutable, deprecated_member_use, unused_element, unnecessary_cast, avoid_print

import 'dart:convert';
import 'package:bikemaster/changen_password.dart';
import 'package:bikemaster/login_page_mender.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MechanicHomePage extends StatefulWidget {
  @override
  _MechanicHomePageState createState() => _MechanicHomePageState();
}

class _MechanicHomePageState extends State<MechanicHomePage> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _mechanicProfileData;
  bool requestAccepted = true;

  @override
  void initState() {
    super.initState();
    initNotifications();
    configureFirebaseMessaging();
    initializeLocalNotifications();
    fetchMechanicProfileData();
  }

  void fetchMechanicProfileData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot mechanicDoc = await FirebaseFirestore.instance
          .collection('mechanics')
          .doc(user
              .uid) // Assuming the mechanic's UID is used as the document ID
          .get();

      if (mechanicDoc.exists) {
        setState(() {
          _mechanicProfileData = mechanicDoc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  void initializeLocalNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();
  }

  Future<String?> getRiderFCMToken(String riderId) async {
    final riderDoc = await FirebaseFirestore.instance
        .collection('riders')
        .doc(riderId)
        .get();
    final riderData = riderDoc.data() as Map<String, dynamic>?;
    return riderData?['fcmToken'] as String?;
  }

  void configureFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showNotification(notification.title ?? '', notification.body ?? '');
      }
    });
  }

  void showNotification(String title, String body) async {
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

  void acceptRequest(String riderId, String riderFcm) async {
    print('riderid ${riderId}');
    final foregroundMessage = RemoteMessage(
      data: {
        'title': 'Request Accepted',
        'body': 'Your request has been accepted by the mechanic.',
      },
      notification: RemoteNotification(
        title: 'Request Accepted',
        body: 'Your request has been accepted by the mechanic.',
      ),
    );
    FirebaseMessaging.instance.subscribeToTopic('riders_$riderId');
    FirebaseMessaging.onMessage.listen((message) {
      showNotification(
          message.notification?.title ?? '', message.notification?.body ?? '');
    });
    // displayForegroundNotification(foregroundMessage);
    sendBackgroundNotificationToRider(riderFcm);

    try {
      await FirebaseFirestore.instance
          .collection('riders')
          .doc(riderId)
          .update({'status': 'accepted'});
      print('Rider status updated successfully.');
    } catch (error) {
      print('Error updating rider status: $error');
    }
    // Send notification to the rider
    sendBackgroundNotificationToRider(riderId);

    // Retrieve the rider's current location from Firestore
    final riderDoc = await FirebaseFirestore.instance
        .collection('riders')
        .doc(riderId)
        .get();
    final riderData = riderDoc.data() as Map<String, dynamic>?;
    final riderLocation = riderData?['currentLocation'] as String?;

    // Set requestAccepted to true to display full rider information
    setState(() {
      requestAccepted = true;
    });

    if (riderLocation != null) {
      // Open OSM map with the rider's current location
      final osmMapUrl =
          'https://www.openstreetmap.org/?mlat=${riderLocation.split(',')[0]}&mlon=${riderLocation.split(',')[1]}';
      if (await canLaunch(osmMapUrl)) {
        // Launch the OSM map URL
        await launch(osmMapUrl);
      } else {
        print('Could not launch OSM map.');
      }
    } else {
      print('Rider location not available.');
    }

    // Set the rider's status back to default after completing the request
    try {
      await FirebaseFirestore.instance
          .collection('riders')
          .doc(riderId)
          .update({'status': 'default'});
      print('Rider status set back to default successfully.');
    } catch (error) {
      print('Error setting rider status back to default: $error');
    }
  }

  void displayForegroundNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'my_custom_channel_id', // Replace with your channel ID
      'My Custom Notifications', // Replace with your channel name
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? 'BikeMaster',
      message.notification?.body ?? 'Requested Accepted by mechanics',
      platformChannelSpecifics,
      payload: 'foreground_notification',
    );
  }

  void sendBackgroundNotificationToRider(String riderFcm) {
    final serverKey =
        'AAAAt72nvR8:APA91bG_NWOBigQ9KUNu1Sm39kS0q9AhaVWdWJHqCmBGcGfyicJWzHlON7COd1mWJrvzm5fgXighWk7N6okRMK7b3_9j0OtUqC0CEu_P9M578iPZa8vtZhtttxAmrG1TO3WmuQvRTIFd';
    final message = {
      'notification': {
        'title': 'Request Accepted',
        'body': 'Your request has been accepted by the mechanic.',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'screen': 'map',
      },
      'to': riderFcm
    };
    print(message);
    http
        .post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode(message),
    )
        .then((response) {
      if (response.statusCode == 200) {
        // Message sent successfully
        print('FCM message sent successfully.');
      } else {
        // Handle errors here
        print(
            'FCM message sending failed. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    }).catchError((error) {
      // Handle any exceptions here
      print('Error sending FCM message: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Bike Master'),
        ),
        body: SingleChildScrollView(
          child: Column(children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('riders')
                  .where('status', isEqualTo: 'requested')
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }

                final riders = snapshot.data?.docs;

                if (riders?.isEmpty ?? true) {
                  return Text('There is no more Request of Riders.');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: riders!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final rider = riders[index];
                    final data = rider.data() as Map<String, dynamic>;
                    print(data);
                    return ListTile(
                      title: Text(
                        requestAccepted ? data['name'] : 'Rider Request',
                      ),
                      subtitle: requestAccepted
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Name: ${data['name']}'),
                                Text('Phone: ${data['phoneNumber']}'),
                                Text('Address: ${data['address']}'),
                                Text('Email: ${data['email']}'),
                              ],
                            )
                          : null,
                      trailing: requestAccepted
                          ? ElevatedButton(
                              onPressed: () {
                                acceptRequest(rider.id, data['fcmToken']);
                              },
                              child: Text('Accept Request'),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ]),
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
                    DocumentSnapshot mechanicDoc = await FirebaseFirestore
                        .instance
                        .collection('mechanics')
                        .doc(user
                            .uid) // Assuming the mechanic's UID is used as the document ID
                        .get();

                    if (mechanicDoc.exists) {
                      Map<String, dynamic> mechanicData =
                          mechanicDoc.data() as Map<String, dynamic>;

                      // Set the mechanic profile data to be displayed
                      setState(() {
                        Navigator.pop(context);
                        _mechanicProfileData = mechanicData;
                      });
                    }
                  }
                },
              ),
              if (_mechanicProfileData != null)
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
                            '${_mechanicProfileData?['name'] ?? 'N/A'}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100.0,
                        height: 30.0,
                        child: Card(
                          child: Text(
                            '${_mechanicProfileData?['address'] ?? 'N/A'}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100.0,
                        height: 30.0,
                        child: Card(
                          child: Text(
                            '${_mechanicProfileData?['phoneNumber'] ?? 'N/A'}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200.0,
                        height: 30.0,
                        child: Card(
                          child: Text(
                            '${_mechanicProfileData?['email'] ?? 'N/A'}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Add more fields as needed
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
                      return LoginPageMender();
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
        ));
  }
}
