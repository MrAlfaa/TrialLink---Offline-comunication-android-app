import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    return initialize();
  }

  Future<Database> initialize() async {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _opening;
    if (opening != null) return opening;

    final future = _openDatabase();
    _opening = future;
    try {
      return await future;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _openDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDir.path, 'traillink_phase_01.db');

    _database = await openDatabase(
      dbPath,
      version: 20,
      onCreate: (db, version) async {
        await _createPhaseOneTables(db);
        await _createPhaseTwoTables(db);
        await _createPhaseThreeTables(db);
        await _createPhaseFourTables(db);
        await _createPhaseSevenTables(db);
        await _createPhaseEightTables(db);
        await _createPhaseNineTables(db);
        await _createPhaseTenTables(db);
        await _createPhaseElevenTables(db);
        await _createPhaseTwelveTables(db);
        await _createPhaseThirteenATables(db);
        await _createPhaseThirteenBTables(db);
        await _createPhaseThirteenETables(db);
        await _createPhaseFourteenTables(db);
        await _createPhaseFifteenTables(db);
        await _createPhaseSixteenTables(db);
        await _createPhaseSeventeenTables(db);
        await _createPhaseEighteenTables(db);
        await _createPhaseNineteenTables(db);
        await _createPhaseTwentyTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPhaseTwoTables(db);
        }
        if (oldVersion < 3) {
          await _createPhaseThreeTables(db);
        }
        if (oldVersion < 4) {
          await _createPhaseFourTables(db);
        }
        if (oldVersion < 5) {
          await _createPhaseSevenTables(db);
        }
        if (oldVersion < 6) {
          await _createPhaseEightTables(db);
        }
        if (oldVersion < 7) {
          await _createPhaseNineTables(db);
        }
        if (oldVersion < 8) {
          await _createPhaseTenTables(db);
        }
        if (oldVersion < 9) {
          await _createPhaseElevenTables(db);
        }
        if (oldVersion < 10) {
          await _createPhaseTwelveTables(db);
        }
        if (oldVersion < 11) {
          await _createPhaseThirteenATables(db);
        }
        if (oldVersion < 12) {
          await _createPhaseThirteenBTables(db);
        }
        if (oldVersion < 13) {
          await _createPhaseThirteenETables(db);
        }
        if (oldVersion < 14) {
          await _createPhaseFourteenTables(db);
        }
        if (oldVersion < 15) {
          await _createPhaseFifteenTables(db);
        }
        if (oldVersion < 16) {
          await _createPhaseSixteenTables(db);
        }
        if (oldVersion < 17) {
          await _createPhaseSeventeenTables(db);
        }
        if (oldVersion < 18) {
          await _createPhaseEighteenTables(db);
        }
        if (oldVersion < 19) {
          await _createPhaseNineteenTables(db);
        }
        if (oldVersion < 20) {
          await _createPhaseTwentyTables(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createPhaseOneTables(Database db) async {
    await db.execute('''
          CREATE TABLE local_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_id TEXT NOT NULL UNIQUE,
            channel_id TEXT,
            sender_id TEXT,
            body TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'draft',
            priority TEXT NOT NULL DEFAULT 'normal',
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
        ''');

    await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            retry_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

    await db.execute('''
          CREATE TABLE peer_nodes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            node_id TEXT NOT NULL UNIQUE,
            display_name TEXT,
            last_seen_at TEXT,
            transport_type TEXT,
            signal_strength INTEGER,
            metadata TEXT
          )
        ''');

    await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            value_type TEXT NOT NULL DEFAULT 'string',
            updated_at TEXT NOT NULL
          )
        ''');

    await db.execute('''
          CREATE TABLE app_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL UNIQUE,
            device_label TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_opened_at TEXT NOT NULL
          )
        ''');
  }

  Future<void> _createPhaseTwoTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_user_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL UNIQUE,
        fullName TEXT NOT NULL,
        email TEXT NOT NULL,
        lastSyncedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_group_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        groupId TEXT NOT NULL UNIQUE,
        groupName TEXT NOT NULL,
        groupCode TEXT NOT NULL,
        memberRole TEXT NOT NULL,
        cachedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createPhaseThreeTables(Database db) async {
    await _backupLegacyTableIfNeeded(
      db: db,
      tableName: 'local_messages',
      requiredColumn: 'client_message_id',
      backupTableName: 'local_messages_phase01_backup',
    );
    await _backupLegacyTableIfNeeded(
      db: db,
      tableName: 'sync_queue',
      requiredColumn: 'payload_json',
      backupTableName: 'sync_queue_phase01_backup',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL,
        server_id TEXT,
        client_message_id TEXT NOT NULL UNIQUE,
        group_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        message_type TEXT NOT NULL DEFAULT 'text',
        content TEXT NOT NULL,
        delivery_status TEXT NOT NULL,
        is_mine INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_state TEXT NOT NULL,
        created_locally INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_message_id TEXT NOT NULL UNIQUE,
        group_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        queue_status TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_local_messages_group_id ON local_messages(group_id)');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_messages_client_id ON local_messages(client_message_id)',
    );
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_message_queue_status ON message_queue(queue_status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)');
  }

  Future<void> _backupLegacyTableIfNeeded({
    required Database db,
    required String tableName,
    required String requiredColumn,
    required String backupTableName,
  }) async {
    final tableExists = await _tableExists(db, tableName);
    if (!tableExists) return;

    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final hasRequiredColumn =
        columns.any((column) => column['name'] == requiredColumn);
    if (hasRequiredColumn) return;

    final backupExists = await _tableExists(db, backupTableName);
    if (!backupExists) {
      await db.execute('ALTER TABLE $tableName RENAME TO $backupTableName');
    } else {
      await db.execute('DROP TABLE $tableName');
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  Future<void> _createPhaseFourTables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'message_queue',
      columnName: 'context_type',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'message_queue',
      columnName: 'context_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'sync_queue',
      columnName: 'context_type',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'sync_queue',
      columnName: 'context_id',
      definition: 'TEXT',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_channels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id TEXT NOT NULL UNIQUE,
        channel_code TEXT NOT NULL UNIQUE,
        channel_name TEXT NOT NULL,
        description TEXT,
        created_by_user_id TEXT NOT NULL,
        created_by_name TEXT,
        channel_key_hash TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        last_opened_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_channel_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        member_role TEXT NOT NULL,
        source TEXT NOT NULL,
        status TEXT NOT NULL,
        joined_at TEXT NOT NULL,
        last_seen_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_channel_packets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packet_id TEXT NOT NULL UNIQUE,
        channel_id TEXT NOT NULL,
        channel_code TEXT NOT NULL,
        packet_type TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'normal',
        ttl INTEGER NOT NULL DEFAULT 5,
        hop_count INTEGER NOT NULL DEFAULT 0,
        packet_status TEXT NOT NULL DEFAULT 'local_created',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_channels_code ON offline_channels(channel_code)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_channel_members_channel ON offline_channel_members(channel_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_packets_channel ON offline_channel_packets(channel_id)',
    );
  }

  Future<void> _createPhaseSevenTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nearby_peers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint_id TEXT NOT NULL UNIQUE,
        user_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        device_name TEXT,
        active_channel_id TEXT NOT NULL,
        active_channel_code TEXT NOT NULL,
        connection_status TEXT NOT NULL,
        discovered_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        rssi INTEGER,
        is_same_channel INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS peer_connection_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_nearby_peers_channel ON nearby_peers(active_channel_code)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_nearby_peers_status ON nearby_peers(connection_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_peer_events_endpoint ON peer_connection_events(endpoint_id)',
    );
  }

  Future<void> _createPhaseEightTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT NOT NULL UNIQUE,
        packet_id TEXT NOT NULL UNIQUE,
        channel_id TEXT NOT NULL,
        channel_code TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content TEXT NOT NULL,
        is_mine INTEGER NOT NULL DEFAULT 0,
        delivery_status TEXT NOT NULL,
        ack_status TEXT NOT NULL,
        ttl INTEGER NOT NULL DEFAULT 5,
        hop_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_packet_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packet_id TEXT NOT NULL UNIQUE,
        channel_id TEXT NOT NULL,
        channel_code TEXT NOT NULL,
        packet_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        queue_status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS processed_offline_packets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packet_id TEXT NOT NULL UNIQUE,
        channel_id TEXT NOT NULL,
        channel_code TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        processed_action TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_acks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ack_id TEXT NOT NULL UNIQUE,
        ack_for_packet_id TEXT NOT NULL,
        ack_for_message_id TEXT,
        channel_id TEXT NOT NULL,
        received_from_user_id TEXT NOT NULL,
        received_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_messages_channel ON offline_messages(channel_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_packet_queue_status ON offline_packet_queue(queue_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_processed_packets_channel ON processed_offline_packets(channel_id)',
    );
  }

  Future<void> _createPhaseNineTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_event_id TEXT NOT NULL UNIQUE,
        server_event_id TEXT,
        group_id TEXT,
        offline_channel_id TEXT,
        channel_code TEXT,
        alert_type TEXT NOT NULL,
        message TEXT,
        priority TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        location_captured_at TEXT,
        status TEXT NOT NULL,
        delivery_mode TEXT NOT NULL,
        ack_status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_state TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_packet_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packet_id TEXT NOT NULL UNIQUE,
        local_event_id TEXT NOT NULL,
        group_id TEXT,
        offline_channel_id TEXT,
        channel_code TEXT,
        payload_json TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'emergency',
        queue_status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_acks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ack_id TEXT NOT NULL UNIQUE,
        local_event_id TEXT NOT NULL,
        ack_from_user_id TEXT NOT NULL,
        ack_from_name TEXT,
        ack_mode TEXT NOT NULL,
        received_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_emergency_events_group ON emergency_events(group_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_emergency_events_channel ON emergency_events(offline_channel_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_emergency_packet_queue_status ON emergency_packet_queue(queue_status, priority)',
    );
  }

  Future<void> _createPhaseTenTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_location_id TEXT NOT NULL UNIQUE,
        server_location_id TEXT,
        group_id TEXT,
        offline_channel_id TEXT,
        channel_code TEXT,
        user_id TEXT NOT NULL,
        user_name TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        altitude REAL,
        speed REAL,
        heading REAL,
        captured_at TEXT NOT NULL,
        source TEXT NOT NULL,
        share_status TEXT NOT NULL,
        sync_state TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS teammate_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        group_id TEXT,
        offline_channel_id TEXT,
        channel_code TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        captured_at TEXT NOT NULL,
        received_at TEXT NOT NULL,
        source TEXT NOT NULL,
        freshness TEXT NOT NULL,
        UNIQUE(user_id, group_id, offline_channel_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_packet_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packet_id TEXT NOT NULL UNIQUE,
        local_location_id TEXT NOT NULL,
        offline_channel_id TEXT,
        channel_code TEXT,
        payload_json TEXT NOT NULL,
        queue_status TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_location_updates_sync ON location_updates(sync_state)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_teammate_locations_context ON teammate_locations(group_id, offline_channel_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_location_packet_queue_status ON location_packet_queue(queue_status)',
    );
  }

  Future<void> _createPhaseElevenTables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'offline_packet_queue',
      columnName: 'priority',
      definition: "TEXT NOT NULL DEFAULT 'normal'",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS peer_metric_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint_id TEXT NOT NULL,
        user_id TEXT,
        display_name TEXT,
        channel_id TEXT,
        channel_code TEXT,
        rssi INTEGER,
        ack_rtt_ms INTEGER,
        packet_success_rate REAL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        disconnect_count INTEGER NOT NULL DEFAULT 0,
        connection_status TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        sample_source TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS peer_quality_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint_id TEXT NOT NULL UNIQUE,
        user_id TEXT,
        display_name TEXT,
        channel_id TEXT,
        channel_code TEXT,
        quality_score REAL NOT NULL,
        quality_label TEXT NOT NULL,
        trend_direction TEXT NOT NULL,
        recommended_action TEXT,
        last_calculated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS connectivity_guidance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id TEXT,
        channel_code TEXT,
        guidance_type TEXT NOT NULL,
        message TEXT NOT NULL,
        related_endpoint_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_peer_metric_samples_endpoint ON peer_metric_samples(endpoint_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_peer_quality_scores_channel ON peer_quality_scores(channel_code, quality_score)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_connectivity_guidance_channel ON connectivity_guidance_logs(channel_code, created_at)',
    );
  }

  Future<void> _createPhaseTwelveTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS voice_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_voice_id TEXT NOT NULL UNIQUE,
        server_voice_id TEXT,
        group_id TEXT,
        offline_channel_id TEXT,
        channel_code TEXT,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        local_file_path TEXT,
        remote_audio_url TEXT,
        duration_ms INTEGER,
        file_size_bytes INTEGER,
        is_mine INTEGER NOT NULL DEFAULT 0,
        delivery_mode TEXT NOT NULL,
        delivery_status TEXT NOT NULL,
        ack_status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_state TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ptt_floor_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL UNIQUE,
        context_type TEXT NOT NULL,
        context_id TEXT NOT NULL,
        speaker_id TEXT NOT NULL,
        speaker_name TEXT NOT NULL,
        event_type TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS voice_packet_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packet_id TEXT NOT NULL UNIQUE,
        local_voice_id TEXT NOT NULL,
        offline_channel_id TEXT,
        channel_code TEXT,
        payload_json TEXT NOT NULL,
        queue_status TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_voice_notes_context ON voice_notes(group_id, offline_channel_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ptt_floor_events_context ON ptt_floor_events(context_type, context_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_voice_packet_queue_status ON voice_packet_queue(queue_status, created_at)',
    );
  }

  Future<void> _createPhaseThirteenATables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'app_settings',
      columnName: 'value_type',
      definition: "TEXT NOT NULL DEFAULT 'string'",
    );
  }

  Future<void> _createPhaseThirteenBTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_identity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_user_id TEXT NOT NULL UNIQUE,
        backend_user_id TEXT,
        public_user_id TEXT,
        cloud_user_id TEXT,
        display_name TEXT NOT NULL,
        email TEXT,
        phone_number TEXT,
        emergency_note TEXT,
        identity_type TEXT NOT NULL,
        created_offline INTEGER NOT NULL DEFAULT 0,
        cloud_status TEXT NOT NULL DEFAULT 'local_only',
        sync_state TEXT NOT NULL DEFAULT 'needs_cloud_create',
        last_cloud_sync_at TEXT,
        cloud_error_message TEXT,
        last_verified_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT NOT NULL UNIQUE,
        trip_name TEXT NOT NULL,
        mode TEXT NOT NULL,
        cloud_group_id TEXT,
        cloud_group_name TEXT,
        offline_channel_id TEXT,
        channel_code TEXT,
        channel_name TEXT,
        local_identity_id TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        sync_state TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_trip_sessions_status ON trip_sessions(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_trip_sessions_identity ON trip_sessions(local_identity_id)',
    );
  }

  Future<void> _createPhaseFourteenTables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'local_identity',
      columnName: 'public_user_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_identity',
      columnName: 'cloud_user_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_identity',
      columnName: 'cloud_status',
      definition: "TEXT NOT NULL DEFAULT 'local_only'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_identity',
      columnName: 'sync_state',
      definition: "TEXT NOT NULL DEFAULT 'needs_cloud_create'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_identity',
      columnName: 'last_cloud_sync_at',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_identity',
      columnName: 'cloud_error_message',
      definition: 'TEXT',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_identity_public_user_id ON local_identity(public_user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_identity_cloud_user_id ON local_identity(cloud_user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_identity_cloud_status ON local_identity(cloud_status)',
    );
    await db.execute('''
      UPDATE local_identity
      SET cloud_user_id = backend_user_id
      WHERE cloud_user_id IS NULL AND backend_user_id IS NOT NULL
    ''');
    await db.execute('''
      UPDATE local_identity
      SET cloud_status = CASE
        WHEN backend_user_id IS NOT NULL THEN 'cloud_ready'
        ELSE 'local_only'
      END
      WHERE cloud_status IS NULL OR cloud_status = ''
    ''');
    await db.execute('''
      UPDATE local_identity
      SET sync_state = CASE
        WHEN backend_user_id IS NOT NULL THEN 'synced'
        ELSE 'needs_cloud_create'
      END
      WHERE sync_state IS NULL OR sync_state = ''
    ''');
  }

  Future<void> _createPhaseFifteenTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id TEXT NOT NULL UNIQUE,
        group_name TEXT NOT NULL,
        group_code TEXT,
        description TEXT,
        member_role TEXT,
        member_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        source TEXT NOT NULL,
        sync_state TEXT NOT NULL,
        last_synced_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id TEXT NOT NULL,
        user_id TEXT,
        local_user_id TEXT,
        display_name TEXT NOT NULL,
        email TEXT,
        phone_number TEXT,
        role TEXT NOT NULL,
        membership_status TEXT NOT NULL,
        presence_status TEXT NOT NULL,
        last_seen_at TEXT,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        UNIQUE(group_id, user_id),
        UNIQUE(group_id, local_user_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_groups_sync ON local_groups(sync_state, last_synced_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_group_members_group ON local_group_members(group_id, membership_status)',
    );

    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'offline_channel_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'chat_context_type',
      definition: "TEXT NOT NULL DEFAULT 'cloud_group'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'sender_local_id',
      definition: 'TEXT',
    );

    if (await _tableExists(db, 'local_group_cache')) {
      await db.execute('''
        INSERT OR IGNORE INTO local_groups (
          group_id,
          group_name,
          group_code,
          member_role,
          member_count,
          status,
          source,
          sync_state,
          last_synced_at,
          created_at,
          updated_at
        )
        SELECT
          groupId,
          groupName,
          groupCode,
          memberRole,
          0,
          'active',
          'backend',
          'synced',
          cachedAt,
          cachedAt,
          cachedAt
        FROM local_group_cache
      ''');
    }

    await db.execute('''
      UPDATE local_messages
      SET sync_state = CASE
        WHEN sync_state IN ('server_synced', 'completed') THEN 'synced'
        WHEN sync_state IN ('pending') THEN 'needs_sync'
        WHEN sync_state IN ('error') THEN 'failed'
        WHEN sync_state IN ('local_only', 'needs_sync', 'synced', 'failed') THEN sync_state
        ELSE 'needs_sync'
      END
    ''');
  }

  Future<void> _createPhaseSixteenTables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channel_members',
      columnName: 'membership_status',
      definition: "TEXT NOT NULL DEFAULT 'active'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channel_members',
      columnName: 'presence_status',
      definition: "TEXT NOT NULL DEFAULT 'unknown'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channel_members',
      columnName: 'connection_status',
      definition: "TEXT NOT NULL DEFAULT 'disconnected'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channel_members',
      columnName: 'endpoint_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channel_members',
      columnName: 'identity_type',
      definition: "TEXT NOT NULL DEFAULT 'guest'",
    );
    await db.execute('''
      UPDATE offline_channel_members
      SET membership_status = CASE
        WHEN status IN ('active', 'left', 'blocked') THEN status
        ELSE 'active'
      END
      WHERE membership_status IS NULL OR membership_status = ''
    ''');
    await db.execute('''
      UPDATE offline_channel_members
      SET presence_status = CASE
        WHEN last_seen_at IS NULL THEN 'unknown'
        ELSE 'nearby'
      END
      WHERE presence_status IS NULL OR presence_status = ''
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_channel_members_presence ON offline_channel_members(channel_id, membership_status, presence_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_channel_members_endpoint ON offline_channel_members(endpoint_id)',
    );
  }

  Future<void> _createPhaseSeventeenTables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'local_file_path',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'remote_url',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'thumbnail_path',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'file_name',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'file_size_bytes',
      definition: 'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'mime_type',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'duration_ms',
      definition: 'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'upload_status',
      definition: "TEXT NOT NULL DEFAULT 'not_required'",
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_messages_upload ON local_messages(upload_status, sync_state)',
    );
    await db.execute('''
      UPDATE local_messages
      SET upload_status = 'not_required'
      WHERE upload_status IS NULL OR upload_status = ''
    ''');
  }

  Future<void> _createPhaseEighteenTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS live_radio_sessions (
        stream_id TEXT PRIMARY KEY,
        offline_channel_id TEXT NOT NULL,
        channel_code TEXT NOT NULL,
        sender_local_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_ms INTEGER,
        chunk_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        last_error TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_live_radio_sessions_channel ON live_radio_sessions(offline_channel_id, started_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_live_radio_sessions_status ON live_radio_sessions(status)',
    );
  }

  Future<void> _createPhaseNineteenTables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channels',
      columnName: 'channel_status',
      definition: "TEXT NOT NULL DEFAULT 'active'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channels',
      columnName: 'ended_at',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channels',
      columnName: 'ended_by_user_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channels',
      columnName: 'ended_reason',
      definition: 'TEXT',
    );
    await db.execute('''
      UPDATE offline_channels
      SET channel_status = CASE
        WHEN channel_status IN ('active', 'inactive', 'ended') THEN channel_status
        WHEN is_active = 1 THEN 'active'
        ELSE 'inactive'
      END
      WHERE channel_status IS NULL OR channel_status = ''
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_channels_status ON offline_channels(channel_status, is_active)',
    );
  }

  Future<void> _createPhaseTwentyTables(Database db) async {
    await _addColumnIfMissing(
      db,
      tableName: 'trip_sessions',
      columnName: 'active_channel_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'trip_sessions',
      columnName: 'last_opened_at',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channels',
      columnName: 'trip_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_channels',
      columnName: 'is_primary',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id TEXT NOT NULL UNIQUE,
        trip_id TEXT NOT NULL,
        channel_id TEXT,
        cloud_group_id TEXT,
        chat_name TEXT NOT NULL,
        chat_type TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 0,
        chat_status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    for (final tableName in [
      'offline_messages',
      'offline_packet_queue',
      'processed_offline_packets',
      'offline_acks',
      'local_messages',
      'message_queue',
    ]) {
      await _addColumnIfMissing(
        db,
        tableName: tableName,
        columnName: 'chat_id',
        definition: 'TEXT',
      );
    }
    for (final tableName in ['local_messages', 'message_queue']) {
      await _addColumnIfMissing(
        db,
        tableName: tableName,
        columnName: 'trip_id',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        db,
        tableName: tableName,
        columnName: 'channel_id',
        definition: 'TEXT',
      );
    }

    final now = DateTime.now().toIso8601String();
    await db.execute('''
      UPDATE trip_sessions
      SET active_channel_id = COALESCE(active_channel_id, offline_channel_id),
          last_opened_at = COALESCE(last_opened_at, updated_at, started_at, created_at, '$now')
      WHERE active_channel_id IS NULL OR active_channel_id = ''
         OR last_opened_at IS NULL OR last_opened_at = ''
    ''');
    await db.execute('''
      UPDATE trip_sessions
      SET status = 'inactive'
      WHERE status NOT IN ('active', 'inactive', 'archived', 'completed')
    ''');
    await db.execute('''
      UPDATE trip_sessions
      SET status = 'inactive'
      WHERE status = 'active'
        AND trip_id NOT IN (
          SELECT trip_id FROM trip_sessions
          WHERE status = 'active'
          ORDER BY COALESCE(last_opened_at, started_at, created_at) DESC
          LIMIT 1
        )
    ''');

    final tripRows = await db.query('trip_sessions');
    for (final trip in tripRows) {
      final tripId = trip['trip_id']?.toString();
      if (tripId == null || tripId.isEmpty) continue;
      final channelId =
          (trip['active_channel_id'] ?? trip['offline_channel_id'])?.toString();
      final channelCode = trip['channel_code']?.toString();
      final cloudGroupId = trip['cloud_group_id']?.toString();

      if (channelId != null && channelId.isNotEmpty) {
        await db.update(
          'offline_channels',
          {
            'trip_id': tripId,
            'is_primary': 1,
            'updated_at': now,
          },
          where: 'channel_id = ? OR channel_code = ?',
          whereArgs: [channelId, channelCode],
        );
        await _insertDefaultChatIfMissing(
          db: db,
          tripId: tripId,
          channelId: channelId,
          cloudGroupId: cloudGroupId,
          chatType: 'offline_channel',
          now: now,
        );
      } else if (cloudGroupId != null && cloudGroupId.isNotEmpty) {
        await _insertDefaultChatIfMissing(
          db: db,
          tripId: tripId,
          channelId: null,
          cloudGroupId: cloudGroupId,
          chatType: 'cloud_group',
          now: now,
        );
      } else {
        await _insertDefaultChatIfMissing(
          db: db,
          tripId: tripId,
          channelId: null,
          cloudGroupId: null,
          chatType: 'trip_general',
          now: now,
        );
      }
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_trip_sessions_active ON trip_sessions(status, last_opened_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_channels_trip ON offline_channels(trip_id, is_primary, is_active)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_rooms_trip ON chat_rooms(trip_id, is_default, is_active)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_rooms_channel ON chat_rooms(channel_id, is_default, is_active)',
    );
  }

  Future<void> _insertDefaultChatIfMissing({
    required Database db,
    required String tripId,
    required String? channelId,
    required String? cloudGroupId,
    required String chatType,
    required String now,
  }) async {
    final existing = await db.query(
      'chat_rooms',
      where:
          'trip_id = ? AND COALESCE(channel_id, "") = ? AND chat_type = ? AND is_default = 1',
      whereArgs: [tripId, channelId ?? '', chatType],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await db.insert(
      'chat_rooms',
      {
        'chat_id': 'chat_${tripId}_${channelId ?? cloudGroupId ?? 'general'}',
        'trip_id': tripId,
        'channel_id': channelId,
        'cloud_group_id': cloudGroupId,
        'chat_name': 'General',
        'chat_type': chatType,
        'is_default': 1,
        'is_active': 1,
        'chat_status': 'active',
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _createPhaseThirteenETables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bridged_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bridge_record_id TEXT NOT NULL UNIQUE,
        original_packet_id TEXT,
        client_message_id TEXT,
        source_path TEXT NOT NULL,
        direction TEXT NOT NULL,
        trip_id TEXT,
        group_id TEXT,
        channel_id TEXT,
        channel_code TEXT NOT NULL,
        origin_sender_id TEXT,
        origin_sender_local_id TEXT,
        origin_display_name TEXT,
        bridged_by_local_id TEXT NOT NULL,
        bridged_by_backend_id TEXT,
        bridged_by_name TEXT,
        bridged_at TEXT NOT NULL,
        status TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS processed_bridge_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unique_item_id TEXT NOT NULL UNIQUE,
        item_type TEXT NOT NULL,
        source_path TEXT NOT NULL,
        processed_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bridge_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bridge_enabled INTEGER NOT NULL DEFAULT 1,
        bridge_text INTEGER NOT NULL DEFAULT 1,
        bridge_sos INTEGER NOT NULL DEFAULT 1,
        bridge_location INTEGER NOT NULL DEFAULT 1,
        bridge_normal_voice INTEGER NOT NULL DEFAULT 0,
        bridge_emergency_voice INTEGER NOT NULL DEFAULT 1,
        bridge_only_same_trip INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    final settings = await db.query('bridge_settings', limit: 1);
    if (settings.isEmpty) {
      await db.insert('bridge_settings', {
        'bridge_enabled': 1,
        'bridge_text': 1,
        'bridge_sos': 1,
        'bridge_location': 1,
        'bridge_normal_voice': 0,
        'bridge_emergency_voice': 1,
        'bridge_only_same_trip': 1,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    await _addColumnIfMissing(
      db,
      tableName: 'offline_messages',
      columnName: 'source_path',
      definition: "TEXT NOT NULL DEFAULT 'offline'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_messages',
      columnName: 'origin_local_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_messages',
      columnName: 'origin_identity_type',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'offline_messages',
      columnName: 'bridged_by_name',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'source_path',
      definition: "TEXT NOT NULL DEFAULT 'online'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'origin_local_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'origin_identity_type',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'local_messages',
      columnName: 'bridged_by_name',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'emergency_events',
      columnName: 'source_path',
      definition: "TEXT NOT NULL DEFAULT 'offline'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'emergency_events',
      columnName: 'origin_local_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'emergency_events',
      columnName: 'origin_display_name',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'emergency_events',
      columnName: 'bridged_by_name',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'location_updates',
      columnName: 'source_path',
      definition: "TEXT NOT NULL DEFAULT 'offline'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'location_updates',
      columnName: 'origin_local_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'teammate_locations',
      columnName: 'source_path',
      definition: "TEXT NOT NULL DEFAULT 'peer'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'teammate_locations',
      columnName: 'bridged_by_name',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'voice_notes',
      columnName: 'source_path',
      definition: "TEXT NOT NULL DEFAULT 'offline'",
    );
    await _addColumnIfMissing(
      db,
      tableName: 'voice_notes',
      columnName: 'origin_local_id',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      tableName: 'voice_notes',
      columnName: 'bridged_by_name',
      definition: 'TEXT',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bridged_messages_status ON bridged_messages(status, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bridged_messages_channel ON bridged_messages(channel_code, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_processed_bridge_items_type ON processed_bridge_items(item_type, processed_at)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db, {
    required String tableName,
    required String columnName,
    required String definition,
  }) async {
    if (!await _tableExists(db, tableName)) return;
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (!exists) {
      await db
          .execute('ALTER TABLE $tableName ADD COLUMN $columnName $definition');
    }
  }

  Future<Map<String, Object?>> ensureSession() async {
    final db = await database;
    final existing = await db.query('app_sessions', limit: 1);
    final now = DateTime.now().toIso8601String();

    if (existing.isNotEmpty) {
      final session = existing.first;
      await db.update(
        'app_sessions',
        {'last_opened_at': now},
        where: 'id = ?',
        whereArgs: [session['id']],
      );
      return {...session, 'last_opened_at': now};
    }

    final sessionId = _buildSessionId();
    final record = {
      'session_id': sessionId,
      'device_label': 'TrailLink Device',
      'created_at': now,
      'last_opened_at': now,
    };

    final id = await db.insert('app_sessions', record);
    return {'id': id, ...record};
  }

  Future<bool> isOnboardingComplete() async {
    final setupValue = await readSetting('setup_completed');
    if (setupValue == 'true') return true;
    final value = await readSetting('onboarding_complete');
    return value == 'true';
  }

  Future<void> setOnboardingComplete() async {
    await upsertSetting('setup_completed', 'true', valueType: 'bool');
    await upsertSetting('onboarding_complete', 'true');
  }

  Future<void> upsertSetting(
    String key,
    String value, {
    String valueType = 'string',
  }) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'value_type': valueType,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<Map<String, String>> readAllSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows)
        row['key'].toString(): row['value']?.toString() ?? '',
    };
  }

  Future<String> testSQLite() async {
    const key = 'phase_01_sqlite_test';
    final value = 'SQLite initialized successfully';
    await upsertSetting(key, value);
    final savedValue = await readSetting(key);

    if (savedValue != value) {
      throw StateError('SQLite test record could not be read back.');
    }

    return value;
  }

  Future<void> cacheUser({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    final db = await database;
    await db.insert(
      'local_user_cache',
      {
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'lastSyncedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearUserCache() async {
    final db = await database;
    await db.delete('local_user_cache');
    await db.delete('local_group_cache');
  }

  Future<void> cacheGroups(List<Map<String, String>> groups) async {
    final db = await database;
    final batch = db.batch();
    await db.delete('local_group_cache');

    for (final group in groups) {
      batch.insert(
        'local_group_cache',
        {
          ...group,
          'cachedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  String _buildSessionId() {
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'tl-${DateTime.now().millisecondsSinceEpoch}-$random';
  }
}
