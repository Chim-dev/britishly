import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../services/layanan_auth.dart';
import '../../widgets/logo_google.dart';
import 'halaman_daftar.dart';

/// Use Case 1 — bagian "Masuk Akun".
/// Desain estetis minimalis dengan palet British Racing Green & Amber.
class HalamanMasuk extends StatefulWidget {
  const HalamanMasuk({super.key});

  @override
  State<HalamanMasuk> createState() => _HalamanMasukState();
}

class _HalamanMasukState extends State<HalamanMasuk> {
  final _kunciForm = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _sedangProses = false;
  bool _sedangProsesGoogle = false;
  bool _passwordTersembunyi = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    if (!_kunciForm.currentState!.validate()) return;

    setState(() => _sedangProses = true);
    try {
      await LayananAuth.instance.masuk(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
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

  Future<void> _masukGoogle() async {
    setState(() => _sedangProsesGoogle = true);
    try {
      await LayananAuth.instance.masukDenganGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LayananAuth.pesanRamah(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sedangProsesGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaBritishly.krem,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _kunciForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    const Text(
                      'Britishly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: TemaBritishly.hijau,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bangun kosakata & akronim Inggrismu setiap hari',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: TemaBritishly.tintaPudar,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 36),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _masuk(),
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Password belum diisi' : null,
                    ),
                    const SizedBox(height: 28),

                    FilledButton(
                      onPressed: (_sedangProses || _sedangProsesGoogle) ? null : _masuk,
                      child: _sedangProses
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Masuk ke Akun'),
                    ),
                    const SizedBox(height: 18),

                    // Pembatas Atau
                    const Row(
                      children: [
                        Expanded(child: Divider(color: TemaBritishly.kremGaris)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'atau',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: TemaBritishly.tintaPudar,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: TemaBritishly.kremGaris)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Tombol Google Sign-In
                    OutlinedButton(
                      onPressed: (_sedangProses || _sedangProsesGoogle) ? null : _masukGoogle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: TemaBritishly.tinta,
                        side: const BorderSide(color: TemaBritishly.kremGaris, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: _sedangProsesGoogle
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: TemaBritishly.hijau,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                LogoGoogle(ukuran: 19),
                                SizedBox(width: 10),
                                Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: TemaBritishly.tinta,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Belum punya akun?',
                          style: TextStyle(color: TemaBritishly.tintaPudar, fontSize: 13.5),
                        ),
                        TextButton(
                          onPressed: _sedangProses
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const HalamanDaftar(),
                                    ),
                                  ),
                          child: const Text(
                            'Daftar Sekarang',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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

/// Validasi format email — dipakai bersama oleh halaman masuk dan daftar.
String? validasiEmail(String? nilai) {
  final teks = nilai?.trim() ?? '';
  if (teks.isEmpty) return 'Email belum diisi';
  final pola = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  if (!pola.hasMatch(teks)) return 'Format email tidak valid';
  return null;
}
