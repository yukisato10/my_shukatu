import 'package:hive/hive.dart';

part 'company.g.dart';

@HiveType(typeId: 10)
enum SelectionTrack {
  @HiveField(0)
  summerIntern,
  @HiveField(1)
  winterIntern,
  @HiveField(2)
  early,
  @HiveField(3)
  main,
}

@HiveType(typeId: 11)
enum SelectionPhase {
  @HiveField(0)
  notApplied,
  @HiveField(1)
  entry,
  @HiveField(2)
  es,
  @HiveField(3)
  webTest,
  @HiveField(4)
  gd,
  @HiveField(5)
  interview1,
  @HiveField(6)
  interview2,
  @HiveField(7)
  interview3,
  @HiveField(8)
  interview4,
  @HiveField(9)
  finalInterview,
  @HiveField(10)
  offer,
  @HiveField(11)
  declined,
  @HiveField(12)
  rejected,

}

@HiveType(typeId: 12)
enum DesireLevel {
  @HiveField(0)
  high,
  @HiveField(1)
  mid,
  @HiveField(2)
  low,
}

@HiveType(typeId: 13)
enum ScheduleType {
  @HiveField(0)
  event,
  @HiveField(1)
  esDeadline,
  @HiveField(2)
  webTest,
  @HiveField(3)
  gd,
  @HiveField(4)
  interview1,
  @HiveField(5)
  interview2,
  @HiveField(6)
  interview3,
  @HiveField(7)
  interview4,
  @HiveField(8)
  finalInterview,
  @HiveField(9)
  other,

}

@HiveType(typeId: 14)
class ScheduleItem {
  @HiveField(0)
  ScheduleType type;

  @HiveField(1)
  DateTime dateTime;

  @HiveField(2)
  String? note;

  ScheduleItem({
    required this.type,
    required this.dateTime,
    this.note,
  });
}

@HiveType(typeId: 15)
class EsQa {
  @HiveField(0)
  String question;

  @HiveField(1)
  String answer;

  EsQa({
    required this.question,
    required this.answer,
  });
}

@HiveType(typeId: 16)
class Company extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String? mypageUrl;

  @HiveField(2)
  String? mypageid;

  @HiveField(3)
  String? mypagePassword;

  @HiveField(4)
  String? industry;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  SelectionTrack track;

  @HiveField(8)
  SelectionPhase phase;

  @HiveField(9)
  String? note;

  @HiveField(10)
  DesireLevel? desireLevel;

  @HiveField(11)
  List<ScheduleItem> schedules;

  @HiveField(12)
  List<EsQa> esQasSummer;

  @HiveField(13)
  List<EsQa> esQasWinter;

  @HiveField(14)
  List<EsQa> esQasEarly;

  @HiveField(15)
  List<EsQa> esQasMain;

  Company({
    required this.name,
    this.mypageUrl,
    this.mypageid,
    this.mypagePassword,
    this.industry,
    required this.createdAt,
    required this.updatedAt,
    this.track = SelectionTrack.main,
    this.phase = SelectionPhase.notApplied,
    this.note,
    this.desireLevel,
    List<ScheduleItem>? schedules,
    List<EsQa>? esQasSummer,
    List<EsQa>? esQasWinter,
    List<EsQa>? esQasEarly,
    List<EsQa>? esQasMain,
  })  : schedules = schedules ?? <ScheduleItem>[],
        esQasSummer = esQasSummer ?? <EsQa>[],
        esQasWinter = esQasWinter ?? <EsQa>[],
        esQasEarly = esQasEarly ?? <EsQa>[],
        esQasMain = esQasMain ?? <EsQa>[];
}
