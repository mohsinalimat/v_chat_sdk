import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:v_chat_sdk/src/utils/v_chat_config.dart';

import '../utils/helpers/helpers.dart';
import 'tables/message_table.dart';
import 'tables/room_table.dart';

class DBProvider {
  DBProvider._();

  static final DBProvider instance = DBProvider._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    // if _database is null we instantiate it
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final String documentsDirectory = await getDatabasesPath();
    final String path = join(documentsDirectory, "v_chat_chat.db");

    return openDatabase(
      path,
      version: VChatConfig.databaseVersion,
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          await RoomTable.createTable(txn);
          await MessageTable.createTable(txn);
          // await txn.execute('PRAGMA cache_size = 1000000');
          // await txn.execute("PRAGMA synchronous = OFF");
          // await txn.execute('PRAGMA temp_store = MEMORY');
        });
      },
      onOpen: (db) async {
        // await NewRoomTable.recreateTable(db);
        // await NewMessageTable.recreateTable(db);
        //
        // log("--------------all tables deleted!--------------");
      },
    );
  }

  Future reCreateTables() async {
    await RoomTable.recreateTable(_database!);
    await MessageTable.recreateTable(_database!);
    Helpers.vlog("all tables deleted!");
  }
}
