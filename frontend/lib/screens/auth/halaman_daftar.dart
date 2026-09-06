import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../services/layanan_auth.dart';
import 'halaman_masuk.dart' show validasiEmail;

/// Use Case 1 — bagian "Mendaftar Akun".
class HalamanDaftar extends StatefulWidget {
  const HalamanDaftar({super.key});

  @override
  State<HalamanDaftar> createState() => _HalamanDaftarState();
}

class _HalamanDaftarState extends State<HalamanDaftar> {
  final _kunciForm = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ulangPasswordCtrl = TextEditingController();

  bool _sedangProses = false;
  bool _passwordTersembunyi = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _ulangPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _daftar() async {
    if (!_kunciForm.currentState!.validate()) return;

    setState(() => _sedangProses = true);
    try {
      final langsungMasuk = await LayananAuth.instance.daftar(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (langsungMasuk) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akun dibuat. Cek emailmu dan klik tautan konfirmasi sebelum masuk.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LayananAuth.pesanRamah(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sedangProses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaBritishly.krem,
      appBar: AppBar(
        title: const Text('Daftar Akun Baru'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _kunciForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Mulai Perjalanan Kosakatamu',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: TemaBritishly.tinta,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Semua kosakata, sinonim, dan akronim tersimpan aman di akun pribadimu.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: TemaBritishly.tintaPudar,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'nama@email.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                      ),
                      validator: validasiEmail,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _passwordTersembunyi,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'Minimal 6 karakter',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordTersembunyi
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _passwordTersembunyi = !_passwordTersembunyi,
                          ),
                        ),
                      ),
                      validator: (nilai) {
                        if (nilai == null || nilai.isEmpty) {
                          return 'Password belum diisi';
                        }
                        if (nilai.length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _ulangPasswordCtrl,
                      obscureText: _passwordTersembunyi,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _daftar(),
                      decoration: const InputDecoration(
                        labelText: 'Ulangi Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      validator: (nilai) => nilai != _passwordCtrl.text
                          ? 'Password tidak sama'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    FilledButton(
                      onPressed: _sedangProses ? null : _daftar,
                      child: _sedangProses
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Buat Akun Saya'),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _sedangProses ? null : () => Navigator.of(context).pop(),
                      child: const Text('Sudah punya akun? Masuk di sini'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
