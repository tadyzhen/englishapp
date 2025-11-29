import 'package:flutter/material.dart';
import '../services/groups_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  int _memberLimit = 50;
  bool _isPublic = true;
  bool _requireApproval = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final groupId = await GroupsService.createGroup(
        name: _nameController.text,
        memberLimit: _memberLimit,
        isPublic: _isPublic,
        requireApproval: _requireApproval,
      );
      if (!mounted) return;
      Navigator.pop(context, groupId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('建立群組失敗: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('建立群組'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '群組名稱',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '請輸入群組名稱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('人數上限'),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _memberLimit,
                    items: const [20, 50, 100, 200]
                        .map((e) => DropdownMenuItem<int>(
                              value: e,
                              child: Text('$e 人'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _memberLimit = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('公開群組'),
                subtitle: const Text('公開後可以被搜尋到'),
                value: _isPublic,
                onChanged: (v) {
                  setState(() => _isPublic = v);
                },
              ),
              SwitchListTile(
                title: const Text('加入需審核'),
                subtitle: const Text('開啟後，加入需要管理員批准'),
                value: _requireApproval,
                onChanged: (v) {
                  setState(() => _requireApproval = v);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('建立'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
