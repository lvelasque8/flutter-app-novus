import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local de Novus.
///
/// SQLite es la fuente de verdad: la aplicación funciona sin internet y
/// guarda todo en el dispositivo. El esquema ya incluye marcas de tiempo
/// para poder agregar sincronización más adelante.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int _version = 2;

  Database? _db;
  String? _path;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _path = p.join(dir, 'novus.db');
    _db = await openDatabase(
      _path!,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<String> get path async {
    await database;
    return _path!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> reopen() async {
    await database;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        category TEXT,
        price REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER NOT NULL DEFAULT 0,
        tax_exempt INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        document TEXT,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_sessions (
        id TEXT PRIMARY KEY,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_bs REAL NOT NULL DEFAULT 0,
        opening_usd REAL NOT NULL DEFAULT 0,
        counted_bs REAL,
        counted_usd REAL,
        expected_bs REAL,
        expected_usd REAL,
        difference_bs REAL,
        difference_usd REAL,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'abierta'
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        rate REAL NOT NULL DEFAULT 0,
        total_bs REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        reference TEXT,
        status TEXT NOT NULL,
        cash_session_id TEXT,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        method TEXT NOT NULL,
        amount REAL NOT NULL,
        amount_bs REAL NOT NULL DEFAULT 0,
        reference TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        sale_id TEXT,
        total REAL NOT NULL,
        paid REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pendiente',
        due_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE account_payments (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        amount REAL NOT NULL,
        amount_bs REAL NOT NULL DEFAULT 0,
        method TEXT NOT NULL,
        note TEXT,
        cash_session_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reference TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_products_active ON products (active)');
    await db.execute('CREATE INDEX idx_sales_created ON sales (created_at)');
    await db.execute(
      'CREATE INDEX idx_sale_items_sale ON sale_items (sale_id)',
    );
    await db.execute('CREATE INDEX idx_accounts_status ON accounts (status)');
    await db.execute(
      'CREATE INDEX idx_customer_document ON customers (document)',
    );
    await db.execute(
      'CREATE INDEX idx_cash_sessions_status ON cash_sessions (status)',
    );

    await _seedSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cash_sessions (
          id TEXT PRIMARY KEY,
          opened_at TEXT NOT NULL,
          closed_at TEXT,
          opening_bs REAL NOT NULL DEFAULT 0,
          opening_usd REAL NOT NULL DEFAULT 0,
          counted_bs REAL,
          counted_usd REAL,
          expected_bs REAL,
          expected_usd REAL,
          difference_bs REAL,
          difference_usd REAL,
          notes TEXT,
          status TEXT NOT NULL DEFAULT 'abierta'
        )
      ''');

      await _addColumn(db, 'sales', 'cash_session_id', 'TEXT');
      await _addColumn(db, 'sale_items', 'unit_cost', 'REAL NOT NULL DEFAULT 0');
      await _addColumn(db, 'account_payments', 'cash_session_id', 'TEXT');
      await _addColumn(db, 'account_payments', 'amount_bs', 'REAL NOT NULL DEFAULT 0');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cash_sessions_status '
        'ON cash_sessions (status)',
      );

      await db.insert(
        'settings',
        {'key': 'rate_updated_at', 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.insert(
        'settings',
        {'key': 'rate_source', 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.insert(
        'settings',
        {'key': 'last_backup_at', 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _addColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    } on DatabaseException catch (error) {
      // La columna ya existe (por ejemplo, en una instalación nueva).
      if (!error.toString().toLowerCase().contains('duplicate column')) {
        rethrow;
      }
    }
  }

  Future<void> _seedSettings(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaults = <String, String>{
      'business_name': 'Mi negocio',
      'rif': '',
      'address': '',
      'phone': '',
      'rate_bs': '0',
      'iva_rate': '16',
      'rate_updated_at': '',
      'rate_source': '',
      'last_backup_at': '',
      'onboarded': '0',
      'created_at': now,
    };
    for (final entry in defaults.entries) {
      await db.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<String> getSetting(String key, {String fallback = ''}) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return fallback;
    return rows.first['value'] as String? ?? fallback;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSettings(Map<String, String> values) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in values.entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Borra los datos operativos y deja la configuración del negocio.
  Future<void> clearBusinessData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('account_payments');
      await txn.delete('accounts');
      await txn.delete('payments');
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('inventory_movements');
      await txn.delete('products');
      await txn.delete('customers');
      await txn.delete('cash_sessions');
    });
  }
}
