
class ScheduleItem {
  String name;
  String day;
  String startTime;
  String endTime;
  String category;
  bool isCompleted;

  ScheduleItem({
    required this.name,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.category = 'Study',
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'category': category,
      'isCompleted': isCompleted,
    };
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      name: json['name'],
      day: json['day'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      category: json['category'] ?? 'Study',
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}
