import 'package:fruit_care_pro/services/admin_service_http.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/services/admin_service.dart';
import 'package:fruit_care_pro/models/user.dart';

class AdminResetPasswordScreen extends StatefulWidget {
  final AppUser user;

  const AdminResetPasswordScreen({
    super.key,
    required this.user,
  });

  @override
  State<AdminResetPasswordScreen> createState() =>
      _AdminResetPasswordScreenState();
}

class _AdminResetPasswordScreenState extends State<AdminResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AdminServiceHttp _adminService = AdminServiceHttp();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _adminService.resetUserPassword(
        userId: widget.user.id,
        newPassword: _newPasswordController.text.trim(),
      );

      if (mounted) {
        // Prikaži success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 30),
                const SizedBox(width: 8),
                const Text('Uspešno'),
              ],
            ),
            content: Text(
              'Lozinka za korisnika ${widget.user.name} je uspešno promenjena.',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Zatvori dialog
                  Navigator.of(context).pop(); // Vrati se nazad
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('U redu'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Prikaži error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Greška'),
              ],
            ),
            content: Text(
              'Došlo je do greške:\n$e',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('U redu'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 3),
        child: Container(
          color: Colors.green[800],
          child: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: const Text(
                  'Resetuj lozinku',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Container(height: 3, color: Colors.brown[500]),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Korisnik:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              generateTextField(
                labelText: "Nova lozinka",                
                controller: _newPasswordController,
                isPassword: _obscurePassword,
                iconData: Icons.lock_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Unesite novu lozinku';
                  }
                  if (value.length < 6) {
                    return 'Lozinka mora imati minimum 6 karaktera';
                  }
                  return null;
                },
                sufixIconWidget: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              
              const SizedBox(height: 16),

              generateTextField(
                labelText: "Potvrdite lozinku",                
                controller: _confirmPasswordController,
                isPassword: _obscureConfirmPassword,
                iconData: Icons.lock_outline,
                  validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Potvrdite lozinku';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Lozinke se ne poklapaju';
                  }
                  return null;
                },
                sufixIconWidget: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  },
                ),
              ),
            

              const SizedBox(height: 32),

              generateButton(
                  text: "Resetujte lozinku",
                  onPressed: _resetPassword,
                  
                ),
              // Reset button
              // SizedBox(
              //   width: double.infinity,
              //   height: 50,
              //   child: ElevatedButton(
              //     onPressed: _isLoading ? null : _resetPassword,
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.green[800],
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //     ),
              //     child: _isLoading
              //         ? const SizedBox(
              //             height: 20,
              //             width: 20,
              //             child: CircularProgressIndicator(
              //               color: Colors.white,
              //               strokeWidth: 2,
              //             ),
              //           )
              //         : const Text(
              //             'Resetuj lozinku',
              //             style: TextStyle(
              //               fontSize: 16,
              //               fontWeight: FontWeight.bold,
              //             ),
              //           ),
              //   ),
              // ),

              const SizedBox(height: 16),

      
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Korisnik će biti obavešten da mora promeniti lozinku pri sledećem prijavljivanju.',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
