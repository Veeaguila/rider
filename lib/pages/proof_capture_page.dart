import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:http/http.dart" as http;

import "../services/api_error.dart";
import "../services/api_config.dart";
import "../services/rider_session.dart";
import "../services/rider_session_guard.dart";

class ProofCapturePage extends StatefulWidget {
  final RiderSession? session;
  final Future<XFile?> Function()? capturePhoto;
  final int parcelId;
  final String deliveryAddress;

  const ProofCapturePage({
    super.key,
    this.session,
    this.capturePhoto,
    required this.parcelId,
    required this.deliveryAddress,
  });

  @override
  State<ProofCapturePage> createState() => _ProofCapturePageState();
}

class _ProofCapturePageState extends State<ProofCapturePage>
    with RiderSessionGuard<ProofCapturePage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _capturedImage;
  Uint8List? _capturedBytes;
  String _proofType = "PHOTO";
  final TextEditingController _notesController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      await readyToken();
      final XFile? photo = widget.capturePhoto != null
          ? await widget.capturePhoto!()
          : await _imagePicker.pickImage(
              source: ImageSource.camera,
              maxWidth: 1200,
              maxHeight: 1200,
              imageQuality: 85,
            );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (bytes.length > 20 * 1024 * 1024) {
          throw const SessionFailure("Proof must be at most 20 MB.");
        }
        if (!mounted) return;
        setState(() {
          _capturedImage = photo;
          _capturedBytes = bytes;
          _proofType = "PHOTO";
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is SessionFailure ? e.message : "Could not capture a photo. Check camera permission and retry.",
          ),
        ),
      );
    }
  }

  Future<void> _uploadProof() async {
    if (_isUploading) return;
    if (_capturedImage == null || _capturedBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please capture a photo')));
      return;
    }
    if (_capturedBytes!.length > 20 * 1024 * 1024 ||
        _notesController.text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Proof must be at most 20 MB and notes at most 500 characters.',
          ),
        ),
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      final token = await readyToken();
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$deliveriesUrl/${widget.parcelId}/upload-proof'),
            )
            ..headers['Authorization'] = 'Bearer $token'
            ..headers['Accept'] = 'application/json'
            ..fields['type'] = _proofType
            ..fields['notes'] = _notesController.text
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                _capturedBytes!,
                filename: _capturedImage!.name,
              ),
            );
      final response = await riderSession.sendMultipart(request);
      await checkAuthorization(response.statusCode);
      if (response.statusCode != 201) {
        throw SessionFailure(apiErrorMessage(response));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Proof uploaded!')));
      Navigator.of(context).pop(true);
    } catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure is SessionFailure ? failure.message : 'Proof upload could not be confirmed. Refresh before retrying.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Capture Delivery Proof"),
        backgroundColor: const Color(0xFF1f3a70),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Delivery Address",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.deliveryAddress,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Proof Type",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              RadioGroup<String>(
                groupValue: _proofType,
                onChanged: (value) {
                  if (value != null) setState(() => _proofType = value);
                },
                child: Row(
                  children: const [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Photo'),
                        value: 'PHOTO',
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Signature'),
                        value: 'SIGNATURE',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Proof Image",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _capturedImage != null
                  ? Image.memory(
                      _capturedBytes!,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                      child: const Center(
                        child: Text(
                          "No image captured",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _capturePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Capture Photo"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1f3a70),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Notes",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: "Add notes about delivery...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadProof,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        )
                      : const Text("Upload Proof"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isUploading ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
