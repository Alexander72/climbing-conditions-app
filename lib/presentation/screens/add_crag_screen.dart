import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crag_provider.dart';
import '../../domain/entities/crag.dart';
import '../../domain/entities/aspect.dart';
import '../../domain/entities/rock_type.dart';
import '../../domain/entities/climbing_type.dart';
import '../../domain/entities/crag_source.dart';

class AddCragScreen extends StatefulWidget {
  const AddCragScreen({super.key});

  @override
  State<AddCragScreen> createState() => _AddCragScreenState();
}

class _AddCragScreenState extends State<AddCragScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _elevationController = TextEditingController();
  final _descriptionController = TextEditingController();

  Aspect _selectedAspect = Aspect.south;
  RockType _selectedRockType = RockType.limestone;
  final Set<ClimbingType> _selectedClimbingTypes = {ClimbingType.sport};

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _elevationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Crag'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Crag Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a crag name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final lat = double.tryParse(value);
                      if (lat == null || lat < -90 || lat > 90) {
                        return 'Invalid latitude';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lonController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final lon = double.tryParse(value);
                      if (lon == null || lon < -180 || lon > 180) {
                        return 'Invalid longitude';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Aspect>(
              value: _selectedAspect,
              decoration: const InputDecoration(
                labelText: 'Aspect',
                border: OutlineInputBorder(),
              ),
              items: Aspect.values.map((aspect) {
                return DropdownMenuItem(
                  value: aspect,
                  child: Text(aspect.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedAspect = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RockType>(
              initialValue: _selectedRockType,
              decoration: const InputDecoration(
                labelText: 'Rock Type',
                border: OutlineInputBorder(),
              ),
              items: RockType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRockType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Climbing Types',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...ClimbingType.values.map((type) {
              return CheckboxListTile(
                title: Text(type.displayName),
                value: _selectedClimbingTypes.contains(type),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedClimbingTypes.add(type);
                    } else {
                      _selectedClimbingTypes.remove(type);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 16),
            TextFormField(
              controller: _elevationController,
              decoration: const InputDecoration(
                labelText: 'Elevation (meters)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add Crag'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedClimbingTypes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one climbing type'),
          ),
        );
        return;
      }

      final crag = Crag(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lonController.text),
        aspect: _selectedAspect,
        rockType: _selectedRockType,
        climbingTypes: _selectedClimbingTypes.toList(),
        elevation: _elevationController.text.isNotEmpty
            ? double.tryParse(_elevationController.text)
            : null,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        source: CragSource.user,
      );

      context.read<CragProvider>().addCrag(crag);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crag added successfully')),
      );
    }
  }
}
