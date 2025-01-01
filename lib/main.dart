import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notepad App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> _authenticate() async {
    String? savedPassword = await _storage.read(key: 'password');

    if (savedPassword == null) {
      // No password set; prompt the user to create one
      _showSetPasswordDialog();
    } else {
      // Password exists; validate it
      _showPasswordPrompt(savedPassword);
    }
  }

  void _showSetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController _newPasswordController =
            TextEditingController();

        return AlertDialog(
          title: Text('Set Password'),
          content: TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Enter a new password'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_newPasswordController.text.isNotEmpty) {
                  await _storage.write(
                      key: 'password', value: _newPasswordController.text);
                  Navigator.pop(context);
                  _navigateToNotes();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showPasswordPrompt(String savedPassword) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Password'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_passwordController.text == savedPassword) {
                  Navigator.pop(context);
                  _navigateToNotes();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid password!')),
                  );
                }
              },
              child: Text('Login'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToNotes() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => NoteList()),
    );
  }

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class NoteList extends StatefulWidget {
  @override
  _NoteListState createState() => _NoteListState();
}

class _NoteListState extends State<NoteList> {
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> filteredNotes = [];
  TextEditingController searchController = TextEditingController();
  late Database database;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();

    searchController.addListener(() {
      filterNotes(searchController.text);
    });
  }

  Future<void> _initializeDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = p.join(databasesPath, 'notes.db');

    database = await openDatabase(path, version: 2, onCreate: (db, version) async {
      await db.execute('''CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT
          )''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE notes ADD COLUMN title TEXT');
      }
    });

    _loadNotes();
  }

  Future<void> _loadNotes() async {
    List<Map<String, dynamic>> notesList = await database.query('notes');
    setState(() {
      notes = notesList;
      filteredNotes = notesList;
    });
  }

  Future<void> deleteNote(int id) async {
    await database.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadNotes();
  }

  void filterNotes(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredNotes = notes;
      } else {
        filteredNotes = notes
            .where((note) =>
                note['title'].toString().toLowerCase().contains(query.toLowerCase()) ||
                note['content'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    database.close();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notepad'),
        actions: [
          IconButton(
            icon: Icon(Icons.lock),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChangePasswordScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: filteredNotes.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 3,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        filteredNotes[index]['title'] ?? 'Untitled',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        filteredNotes[index]['content'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteNote(filteredNotes[index]['id']),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddNoteScreen(
                            database: database,
                            isEditing: true,
                            noteId: filteredNotes[index]['id'],
                            existingTitle: filteredNotes[index]['title'],
                            existingContent: filteredNotes[index]['content'],
                          ),
                        ),
                      ).then((_) => _loadNotes()),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddNoteScreen(database: database, isEditing: false)),
          ).then((_) => _loadNotes());
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddNoteScreen extends StatefulWidget {
  final Database database;
  final bool isEditing;
  final int? noteId;
  final String? existingTitle;
  final String? existingContent;

  AddNoteScreen({
    required this.database,
    required this.isEditing,
    this.noteId,
    this.existingTitle,
    this.existingContent,
  });

  @override
  _AddNoteScreenState createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  TextEditingController titleController = TextEditingController();
  TextEditingController contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      titleController.text = widget.existingTitle ?? '';
      contentController.text = widget.existingContent ?? '';
    }
  }

  Future<void> saveNote() async {
    if (contentController.text.isNotEmpty) {
      final note = {
        'title': titleController.text.isEmpty ? 'Untitled' : titleController.text,
        'content': contentController.text,
      };

      if (widget.isEditing) {
        await widget.database.update(
          'notes',
          note,
          where: 'id = ?',
          whereArgs: [widget.noteId],
        );
      } else {
        await widget.database.insert(
          'notes',
          note,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      Navigator.pop(this.context);
    } else {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Please enter note content!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Note' : 'Add New Note'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: 'Write your note here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: saveNote,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(widget.isEditing ? 'Save Changes' : 'Save Note'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> _changePassword() async {
    String? savedPassword = await _storage.read(key: 'password');

    if (savedPassword == null) {
      // Handle case where no password is set
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No password is set!')),
      );
    } else if (_currentPasswordController.text == savedPassword) {
      if (_newPasswordController.text == _confirmNewPasswordController.text) {
        await _storage.write(key: 'password', value: _newPasswordController.text);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password changed successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New passwords do not match!')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incorrect current password!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Current Password'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'New Password'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _confirmNewPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Confirm New Password'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePassword,
              child: Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}
