import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../../../domain/entities/congregation_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/congregation_provider.dart';

class CongregationFormScreen extends ConsumerStatefulWidget {
  final CongregationEntity? congregation;

  const CongregationFormScreen({super.key, this.congregation});

  @override
  ConsumerState<CongregationFormScreen> createState() => _CongregationFormScreenState();
}

class _CongregationFormScreenState extends ConsumerState<CongregationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  late TextEditingController _leaderNameController;
  late TextEditingController _serviceTimesController;
  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.congregation?.name ?? '');
    _descriptionController = TextEditingController(text: widget.congregation?.description ?? '');
    _addressController = TextEditingController(text: widget.congregation?.address ?? '');
    _cityController = TextEditingController(text: widget.congregation?.city ?? '');
    _provinceController = TextEditingController(text: widget.congregation?.province ?? '');
    _latitudeController = TextEditingController(text: widget.congregation?.latitude.toString() ?? '0.0');
    _longitudeController = TextEditingController(text: widget.congregation?.longitude.toString() ?? '0.0');
    _phoneController = TextEditingController(text: widget.congregation?.phone ?? '');
    _whatsappController = TextEditingController(text: widget.congregation?.whatsappNumber ?? '');
    _emailController = TextEditingController(text: widget.congregation?.email ?? '');
    _leaderNameController = TextEditingController(text: widget.congregation?.leaderName ?? '');
    _serviceTimesController = TextEditingController(text: widget.congregation?.serviceTimes.join('\n') ?? '');
    _imageUrl = widget.congregation?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _leaderNameController.dispose();
    _serviceTimesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
    });
  }

  Future<void> _useCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ative a localização do dispositivo.')),
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização não concedida.')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);
    });

    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted || places.isEmpty) return;

      final place = places.first;
      final road = (place.street ?? '').trim();
      final number = (place.subThoroughfare ?? '').trim();
      final locality = (place.locality ?? '').trim();
      final adminArea = (place.administrativeArea ?? '').trim();

      final resolvedAddress = [road, number]
          .where((part) => part.isNotEmpty)
          .join(', ');

      setState(() {
        if (resolvedAddress.isNotEmpty) {
          _addressController.text = resolvedAddress;
        }
        if (locality.isNotEmpty) {
          _cityController.text = locality;
        }
        if (adminArea.isNotEmpty) {
          _provinceController.text = adminArea;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localização obtida. Não foi possível resolver o endereço automaticamente.'),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final congregationId = widget.congregation?.id ?? const Uuid().v4();
      var imageUrl = _imageUrl;

      if (_imageFile != null) {
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await ref
            .read(congregationRepositoryProvider)
            .uploadCongregationImage(_imageFile!, congregationId, fileName);
      }

      final newCong = CongregationEntity(
        id: congregationId,
        name: _nameController.text,
        description: _descriptionController.text,
        address: _addressController.text,
        city: _cityController.text,
        province: _provinceController.text,
        country: 'Angola',
        latitude: double.tryParse(_latitudeController.text) ?? 0.0,
        longitude: double.tryParse(_longitudeController.text) ?? 0.0,
        phone: _phoneController.text,
        whatsappNumber: _whatsappController.text,
        email: _emailController.text,
        leaderName: _leaderNameController.text,
        serviceTimes: _serviceTimesController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
        imageUrl: imageUrl,
        isActive: true,
        createdAt: widget.congregation?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user.uid,
      );

      try {
        if (widget.congregation == null) {
          await ref.read(congregationRepositoryProvider).addCongregation(newCong);
          if (mounted) Navigator.pop(context);
        } else {
          await ref.read(congregationRepositoryProvider).updateCongregation(newCong);
          if (mounted) Navigator.pop(context, newCong);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.congregation == null ? 'Nova Congregação' : 'Editar Congregação')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Foto da congregação',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : (_imageUrl != null && _imageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_imageUrl!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined),
                              SizedBox(height: 8),
                              Text('Selecionar foto'),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Endereço/Morada'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _provinceController, decoration: const InputDecoration(labelText: 'Província'))),
              ],
            ),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _latitudeController, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _longitudeController, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number)),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Usar localização atual'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _leaderNameController, decoration: const InputDecoration(labelText: 'Responsável Local'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
            TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Telefone'), keyboardType: TextInputType.phone),
            TextFormField(controller: _whatsappController, decoration: const InputDecoration(labelText: 'WhatsApp'), keyboardType: TextInputType.phone),
            TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serviceTimesController,
              decoration: const InputDecoration(labelText: 'Horários (Um por linha)', hintText: 'Domingo 09:00 - Culto\nQuarta 18:30 - Estudo'),
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _save, child: const Text('Guardar Congregação')),
          ],
        ),
      ),
    );
  }
}
