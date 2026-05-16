
import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';

class SqlConnectScreen extends StatefulWidget {
  const SqlConnectScreen({super.key});

  @override
  State<SqlConnectScreen> createState() => _SqlConnectScreenState();
}

class _SqlConnectScreenState extends State<SqlConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '3306');
  final _dbController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  String _connectionResult = '';
  bool _isLoading = false;

  Future<void> _connectToDb() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _connectionResult = '';
      });

      try {
        final conn = await MySQLConnection.createConnection(
          host: _hostController.text,
          port: int.parse(_portController.text),
          userName: _userController.text,
          password: _passwordController.text,
          databaseName: _dbController.text,
          secure: false,
        );

        await conn.connect();

        if (conn.connected) {
          setState(() {
            _connectionResult = 'Connection successful!';
          });
          await conn.close();
        } else {
          setState(() {
            _connectionResult = 'Connection failed.';
          });
        }
      } catch (e) {
        setState(() {
          _connectionResult = 'Connection failed: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to MySQL'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(labelText: 'Host / Server Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a host name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a port';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dbController,
                  decoration: const InputDecoration(labelText: 'Database Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a database name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'User Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a user name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _connectToDb,
                        child: const Text('Connect'),
                      ),
                const SizedBox(height: 16),
                Text(_connectionResult),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
