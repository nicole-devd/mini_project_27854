
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'schedule_item.dart';
import 'weather_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyWeekApp());
}

class MyWeekApp extends StatelessWidget {
  const MyWeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Week',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MyWeekScreen();
        }

        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool loading = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must have at least 6 characters.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed. Please try again.';

      if (e.code == 'email-already-in-use') {
        message = 'This email already has an account.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Please choose a stronger password.';
      } else if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      } else if (e.code == 'network-request-failed') {
        message = 'Check your internet connection.';
      }

      showMessage(message);
    } catch (e) {
      showMessage('Something went wrong. Please try again.');
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Week'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.calendar_month,
                size: 70,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                isLogin ? 'Welcome Back' : 'Create Account',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isLogin
                    ? 'Login to access your weekly timetable.'
                    : 'Register to start using My Week.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator()
                      : Text(isLogin ? 'Login' : 'Register'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: loading
                    ? null
                    : () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin
                      ? 'Create a new account'
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyWeekScreen extends StatefulWidget {
  const MyWeekScreen({super.key});

  @override
  State<MyWeekScreen> createState() => _MyWeekScreenState();
}

class _MyWeekScreenState extends State<MyWeekScreen> {
  List<ScheduleItem> items = [];
  List<String> itemIds = [];

  bool loading = true;
  bool weatherLoading = true;
  String? weatherError;
  Map<String, dynamic>? weather;

  String? databaseError;

  final WeatherService weatherService = WeatherService();

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  CollectionReference<Map<String, dynamic>> get courses {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('courses');
  }

  @override
  void initState() {
    super.initState();
    loadItems();
    loadWeather();
  }

  Future<void> loadItems() async {
    try {
      final snapshot = await courses.get();

      if (snapshot.docs.isEmpty) {
        final sampleItems = [
          ScheduleItem(
            name: 'Database Systems',
            day: 'Monday',
            startTime: '09:00',
            endTime: '11:00',
          ),
          ScheduleItem(
            name: 'Big Data Analytics',
            day: 'Wednesday',
            startTime: '10:00',
            endTime: '12:00',
          ),
          ScheduleItem(
            name: 'Mobile Application Development',
            day: 'Friday',
            startTime: '14:00',
            endTime: '16:00',
          ),
        ];

        for (final item in sampleItems) {
          final document = await courses.add(item.toJson());
          items.add(item);
          itemIds.add(document.id);
        }
      } else {
        for (final document in snapshot.docs) {
          items.add(ScheduleItem.fromJson(document.data()));
          itemIds.add(document.id);
        }
      }

      if (!mounted) return;

      setState(() {
        loading = false;
        databaseError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        databaseError = e.toString();
      });
    }
  }

  Future<void> loadWeather() async {
    if (!mounted) return;

    setState(() {
      weatherLoading = true;
      weatherError = null;
    });

    try {
      final result = await weatherService.getWeather();

      if (!mounted) return;

      setState(() {
        weather = result;
        weatherLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        weatherError = e.toString();
        weatherLoading = false;
      });
    }
  }

  bool validTime(String value) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
      return false;
    }

    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return false;

    return hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  int timeToMinutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> addItem() async {
    final nameController = TextEditingController();
    final dayController = TextEditingController(text: 'Monday');
    final startController = TextEditingController();
    final endController = TextEditingController();

    String? validationError;

    final newItem = await showDialog<ScheduleItem>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add a course'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Course name',
                      ),
                    ),
                    TextField(
                      controller: dayController,
                      decoration: const InputDecoration(
                        labelText: 'Day',
                        hintText: 'Monday',
                      ),
                    ),
                    TextField(
                      controller: startController,
                      decoration: const InputDecoration(
                        labelText: 'Start time (HH:MM)',
                        hintText: '09:00',
                      ),
                    ),
                    TextField(
                      controller: endController,
                      decoration: const InputDecoration(
                        labelText: 'End time (HH:MM)',
                        hintText: '11:00',
                      ),
                    ),
                    if (validationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          validationError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    final matchingDays = days.where(
                          (day) =>
                      day.toLowerCase() ==
                          dayController.text.trim().toLowerCase(),
                    );

                    final start = startController.text.trim();
                    final end = endController.text.trim();

                    if (name.isEmpty ||
                        matchingDays.isEmpty ||
                        !validTime(start) ||
                        !validTime(end) ||
                        timeToMinutes(end) <= timeToMinutes(start)) {
                      setDialogState(() {
                        validationError =
                        'Enter a course, valid day, and valid times.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      ScheduleItem(
                        name: name,
                        day: matchingDays.first,
                        startTime: start,
                        endTime: end,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    dayController.dispose();
    startController.dispose();
    endController.dispose();

    if (!mounted || newItem == null) return;

    try {
      final document = await courses.add(newItem.toJson());

      if (!mounted) return;

      setState(() {
        items.add(newItem);
        itemIds.add(document.id);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save course: $e')),
      );
    }
  }

  Future<void> deleteItem(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete course?'),
          content: Text('Delete "${items[index].name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      await courses.doc(itemIds[index]).delete();

      if (!mounted) return;

      setState(() {
        items.removeAt(index);
        itemIds.removeAt(index);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete course: $e')),
      );
    }
  }

  Future<void> toggleCompleted(int index, bool? value) async {
    final completed = value ?? false;

    try {
      await courses.doc(itemIds[index]).update({
        'isCompleted': completed,
      });

      if (!mounted) return;

      setState(() {
        items[index].isCompleted = completed;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update course: $e')),
      );
    }
  }

  Widget weatherSection() {
    if (weatherLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 16),
              Text('Loading Kigali weather...'),
            ],
          ),
        ),
      );
    }

    if (weatherError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kigali Weather'),
              const SizedBox(height: 8),
              Text(
                weatherError!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: loadWeather,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (weather == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Weather data is not available.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kigali Weather',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Temperature: ${weather!['temperature_2m']} °C'),
            Text('Humidity: ${weather!['relative_humidity_2m']}%'),
            Text('Wind speed: ${weather!['wind_speed_10m']} km/h'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: loadWeather,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh weather'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Week'),
        actions: [
          IconButton(
            onPressed: logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : databaseError != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load your timetable from Firestore.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                databaseError!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    loading = true;
                    databaseError = null;
                    items.clear();
                    itemIds.clear();
                  });
                  loadItems();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          weatherSection(),
          const SizedBox(height: 16),
          Text(
            'My Timetable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...days.map((day) {
            final dayItems = items
                .where((item) => item.day == day)
                .toList()
              ..sort(
                    (a, b) => a.startTime.compareTo(b.startTime),
              );

            if (dayItems.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ...dayItems.map((item) {
                  final index = items.indexOf(item);

                  return Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: item.isCompleted,
                        onChanged: (value) {
                          toggleCompleted(index, value);
                        },
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.startTime} - ${item.endTime} '
                            '• ${item.category}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => deleteItem(index),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
      floatingActionButton: loading || databaseError != null
          ? null
          : FloatingActionButton(
        onPressed: addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
