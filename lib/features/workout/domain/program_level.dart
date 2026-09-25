enum ProgramLevel { beginner, intermediate, advanced }

ProgramLevel? programLevelFromDb(String? value) =>
    value == null ? null : ProgramLevel.values.byName(value);

String? programLevelToDb(ProgramLevel? level) => level?.name;
