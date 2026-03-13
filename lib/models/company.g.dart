// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleItemAdapter extends TypeAdapter<ScheduleItem> {
  @override
  final int typeId = 14;

  @override
  ScheduleItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleItem(
      type: fields[0] as ScheduleType,
      dateTime: fields[1] as DateTime,
      note: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EsQaAdapter extends TypeAdapter<EsQa> {
  @override
  final int typeId = 15;

  @override
  EsQa read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EsQa(
      question: fields[0] as String,
      answer: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EsQa obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.question)
      ..writeByte(1)
      ..write(obj.answer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EsQaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CompanyAdapter extends TypeAdapter<Company> {
  @override
  final int typeId = 16;

  @override
  Company read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Company(
      name: fields[0] as String,
      mypageUrl: fields[1] as String?,
      mypageid: fields[2] as String?,
      mypagePassword: fields[3] as String?,
      industry: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      track: fields[7] as SelectionTrack,
      phase: fields[8] as SelectionPhase,
      note: fields[9] as String?,
      desireLevel: fields[10] as DesireLevel?,
      schedules: (fields[11] as List?)?.cast<ScheduleItem>(),
      esQasSummer: (fields[12] as List?)?.cast<EsQa>(),
      esQasWinter: (fields[13] as List?)?.cast<EsQa>(),
      esQasEarly: (fields[14] as List?)?.cast<EsQa>(),
      esQasMain: (fields[15] as List?)?.cast<EsQa>(),
    );
  }

  @override
  void write(BinaryWriter writer, Company obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.mypageUrl)
      ..writeByte(2)
      ..write(obj.mypageid)
      ..writeByte(3)
      ..write(obj.mypagePassword)
      ..writeByte(4)
      ..write(obj.industry)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.track)
      ..writeByte(8)
      ..write(obj.phase)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.desireLevel)
      ..writeByte(11)
      ..write(obj.schedules)
      ..writeByte(12)
      ..write(obj.esQasSummer)
      ..writeByte(13)
      ..write(obj.esQasWinter)
      ..writeByte(14)
      ..write(obj.esQasEarly)
      ..writeByte(15)
      ..write(obj.esQasMain);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SelectionTrackAdapter extends TypeAdapter<SelectionTrack> {
  @override
  final int typeId = 10;

  @override
  SelectionTrack read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SelectionTrack.summerIntern;
      case 1:
        return SelectionTrack.winterIntern;
      case 2:
        return SelectionTrack.early;
      case 3:
        return SelectionTrack.main;
      default:
        return SelectionTrack.summerIntern;
    }
  }

  @override
  void write(BinaryWriter writer, SelectionTrack obj) {
    switch (obj) {
      case SelectionTrack.summerIntern:
        writer.writeByte(0);
        break;
      case SelectionTrack.winterIntern:
        writer.writeByte(1);
        break;
      case SelectionTrack.early:
        writer.writeByte(2);
        break;
      case SelectionTrack.main:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionTrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SelectionPhaseAdapter extends TypeAdapter<SelectionPhase> {
  @override
  final int typeId = 11;

  @override
  SelectionPhase read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SelectionPhase.notApplied;
      case 1:
        return SelectionPhase.entry;
      case 2:
        return SelectionPhase.es;
      case 3:
        return SelectionPhase.webTest;
      case 4:
        return SelectionPhase.gd;
      case 5:
        return SelectionPhase.interview1;
      case 6:
        return SelectionPhase.interview2;
      case 7:
        return SelectionPhase.interview3;
      case 8:
        return SelectionPhase.interview4;
      case 9:
        return SelectionPhase.finalInterview;
      case 10:
        return SelectionPhase.offer;
      case 11:
        return SelectionPhase.declined;
      case 12:
        return SelectionPhase.rejected;
      default:
        return SelectionPhase.notApplied;
    }
  }

  @override
  void write(BinaryWriter writer, SelectionPhase obj) {
    switch (obj) {
      case SelectionPhase.notApplied:
        writer.writeByte(0);
        break;
      case SelectionPhase.entry:
        writer.writeByte(1);
        break;
      case SelectionPhase.es:
        writer.writeByte(2);
        break;
      case SelectionPhase.webTest:
        writer.writeByte(3);
        break;
      case SelectionPhase.gd:
        writer.writeByte(4);
        break;
      case SelectionPhase.interview1:
        writer.writeByte(5);
        break;
      case SelectionPhase.interview2:
        writer.writeByte(6);
        break;
      case SelectionPhase.interview3:
        writer.writeByte(7);
        break;
      case SelectionPhase.interview4:
        writer.writeByte(8);
        break;
      case SelectionPhase.finalInterview:
        writer.writeByte(9);
        break;
      case SelectionPhase.offer:
        writer.writeByte(10);
        break;
      case SelectionPhase.declined:
        writer.writeByte(11);
        break;
      case SelectionPhase.rejected:
        writer.writeByte(12);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionPhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DesireLevelAdapter extends TypeAdapter<DesireLevel> {
  @override
  final int typeId = 12;

  @override
  DesireLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DesireLevel.high;
      case 1:
        return DesireLevel.mid;
      case 2:
        return DesireLevel.low;
      default:
        return DesireLevel.high;
    }
  }

  @override
  void write(BinaryWriter writer, DesireLevel obj) {
    switch (obj) {
      case DesireLevel.high:
        writer.writeByte(0);
        break;
      case DesireLevel.mid:
        writer.writeByte(1);
        break;
      case DesireLevel.low:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesireLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScheduleTypeAdapter extends TypeAdapter<ScheduleType> {
  @override
  final int typeId = 13;

  @override
  ScheduleType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScheduleType.event;
      case 1:
        return ScheduleType.esDeadline;
      case 2:
        return ScheduleType.webTest;
      case 3:
        return ScheduleType.gd;
      case 4:
        return ScheduleType.interview1;
      case 5:
        return ScheduleType.interview2;
      case 6:
        return ScheduleType.interview3;
      case 7:
        return ScheduleType.interview4;
      case 8:
        return ScheduleType.finalInterview;
      case 9:
        return ScheduleType.other;
      default:
        return ScheduleType.event;
    }
  }

  @override
  void write(BinaryWriter writer, ScheduleType obj) {
    switch (obj) {
      case ScheduleType.event:
        writer.writeByte(0);
        break;
      case ScheduleType.esDeadline:
        writer.writeByte(1);
        break;
      case ScheduleType.webTest:
        writer.writeByte(2);
        break;
      case ScheduleType.gd:
        writer.writeByte(3);
        break;
      case ScheduleType.interview1:
        writer.writeByte(4);
        break;
      case ScheduleType.interview2:
        writer.writeByte(5);
        break;
      case ScheduleType.interview3:
        writer.writeByte(6);
        break;
      case ScheduleType.interview4:
        writer.writeByte(7);
        break;
      case ScheduleType.finalInterview:
        writer.writeByte(8);
        break;
      case ScheduleType.other:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
