
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schedule_item.dart';
import 'weather_service.dart';

void main() {
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
      home: const MyWeekScreen(),
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
  bool loading = true;
  bool weatherLoading = true;
  String? weatherError;
  Map<String, dynamic>? weather;

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

  @override
  void initState() {
    super.initState();
    loadItems();
    loadWeather();
  }

  Future<void> loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedItems = prefs.getString('my_week_items');

      if (savedItems != null) {
        final List<dynamic> decoded = jsonDecode(savedItems);
        items = decoded
            .map(
              (item) => ScheduleItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
            .toList();
      } else {
        items = [
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

        await saveItems();
      }

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load timetable: $e')),
      );
    }
  }

  Future<void> saveItems() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedItems = jsonEncode(
      items.map((item) => item.toJson()).toList(),
    );

    await prefs.setString('my_week_items', encodedItems);
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
        weatherError = null;
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

    setState(() {
      items.add(newItem);
    });

    await saveItems();
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

    if (confirm == true && mounted) {
      setState(() {
        items.removeAt(index);
      });

      await saveItems();
    }
  }

  Future<void> toggleCompleted(int index, bool? value) async {
    setState(() {
      items[index].isCompleted = value ?? false;
    });

    await saveItems();
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
              Expanded(child: Text('Loading Kigali weather...')),
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
              Text(
                'Kigali Weather',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(
                weatherError!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: weatherLoading ? null : loadWeather,
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
            Text(
              'Temperature: ${weather!['temperature_2m']} °C',
            ),
            Text(
              'Humidity: ${weather!['relative_humidity_2m']}%',
            ),
            Text(
              'Wind speed: ${weather!['wind_speed_10m']} km/h',
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Week'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
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
      floatingActionButton: FloatingActionButton(
        onPressed: addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
