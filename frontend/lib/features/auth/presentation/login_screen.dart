import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.startInSignup = false});

  final bool startInSignup;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmController = TextEditingController();
  late bool _isLogin;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startInSignup;
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  void _submit() {
    debugPrint('[LoginScreen] Submit tapped. isLogin=$_isLogin');
    if (_formKey.currentState?.validate() != true) {
      debugPrint('[LoginScreen] Form validation failed.');
      return;
    }
    final email = _emailController.text.trim();
    if (_isLogin) {
      debugPrint('[LoginScreen] Attempting login for $email');
      ref
          .read(authControllerProvider.notifier)
          .login(_emailController.text, _passwordController.text);
    } else {
      debugPrint('[LoginScreen] Attempting signup for $email');
      ref
          .read(authControllerProvider.notifier)
          .signup(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final primaryColor = const Color(0xFF111827);

    if (authState.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Team',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A233A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '팀 미팅을 더 쉽게',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      const BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLogin)
                          _buildLoginFields()
                        else
                          _buildSignupFields(),
                        if (authState.hasError) ...[
                          const SizedBox(height: 16),
                          Text(
                            authState.errorMessage ?? '문제가 발생했습니다.',
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? '로그인' : '회원가입',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: authState.isLoading
                                ? null
                                : _toggleAuthMode,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _isLogin ? '회원가입' : '로그인으로 돌아가기',
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        if (_isLogin) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton(
                              onPressed: () {},
                              child: const Text(
                                '비밀번호 재설정',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginFields() {
    return Column(
      children: [
        _buildTextField(controller: _emailController, hintText: '이메일'),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          hintText: '비밀번호',
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildSignupFields() {
    return Column(
      children: [
        _buildTextField(controller: _nameController, hintText: '이름'),
        const SizedBox(height: 16),
        _buildTextField(controller: _emailController, hintText: '이메일'),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          hintText: '비밀번호',
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmController,
          hintText: '비밀번호 확인',
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$hintText을(를) 입력해주세요';
          }
          if (hintText.contains('비밀번호') && value.length < 8) {
            return '비밀번호는 8자 이상이어야 합니다';
          }
          if (hintText == '비밀번호 확인' && value != _passwordController.text) {
            return '비밀번호가 일치하지 않습니다';
          }
          if (hintText == '이메일' && !value.contains('@')) {
            return '유효한 이메일을 입력하세요';
          }
          return null;
        },
      ),
    );
  }
}
