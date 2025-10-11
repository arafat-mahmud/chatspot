import 'package:flutter/material.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:chatspot/dashboard/menu/components/settings/text_field_helper.dart';

/// Demo page showing improved text field styling with proper outline visibility
class TextFieldStyleDemo extends StatefulWidget {
  @override
  _TextFieldStyleDemoState createState() => _TextFieldStyleDemoState();
}

class _TextFieldStyleDemoState extends State<TextFieldStyleDemo> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isPasswordVisible = false;
  String? _emailError;
  String? _selectedGender;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Field Style Demo'),
        actions: [
          IconButton(
            icon: Icon(
              ThemeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              ThemeService.toggleTheme();
            },
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Text Field Outline Visibility Test',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            SizedBox(height: 8),
            Text(
              'Test the text fields below. The outline should always be visible in both light and dark themes.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 24),

            // Basic text field
            Text(
              'Basic Text Field',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: context.getInputDecoration('Full Name'),
              style: context.textFieldTextStyle,
            ),
            SizedBox(height: 16),

            // Email field with error state
            Text(
              'Email Field (with error state)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: context.getInputDecoration(
                'Email Address',
                errorText: _emailError,
              ),
              style: context.textFieldTextStyle,
              onChanged: (value) {
                setState(() {
                  if (value.isNotEmpty && !value.contains('@')) {
                    _emailError = 'Please enter a valid email';
                  } else {
                    _emailError = null;
                  }
                });
              },
            ),
            SizedBox(height: 16),

            // Password field
            Text(
              'Password Field',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: TextFieldDecorationHelper.getPasswordFieldDecoration(
                context,
                labelText: 'Password',
                isPasswordVisible: _isPasswordVisible,
                onToggleVisibility: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              style: context.textFieldTextStyle,
            ),
            SizedBox(height: 16),

            // Phone field with prefix icon
            Text(
              'Phone Field (with prefix icon)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: context.getInputDecoration(
                'Phone Number',
                prefixIcon: Icon(
                  Icons.phone,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              style: context.textFieldTextStyle,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),

            // Dropdown field
            Text(
              'Dropdown Field',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: TextFieldDecorationHelper.getDropdownDecoration(
                context,
                labelText: 'Gender',
              ),
              style: context.textFieldTextStyle,
              items: ['Male', 'Female', 'Other', 'Prefer not to say']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
            SizedBox(height: 16),

            // Date picker field
            Text(
              'Date Picker Field',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              readOnly: true,
              decoration: TextFieldDecorationHelper.getDatePickerDecoration(
                context,
                labelText: 'Date of Birth',
              ),
              style: context.textFieldTextStyle,
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  // Handle date selection
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Selected: ${picked.toString().split(' ')[0]}'),
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 32),

            // Instructions
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Testing Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Tap on any text field - the outline should become visible with a thicker border\n'
                    '2. Toggle between light and dark themes using the button in the app bar\n'
                    '3. Check that outlines are always visible in both themes\n'
                    '4. Test the email field by typing invalid email to see error state\n'
                    '5. Test the password field visibility toggle',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Current theme info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Current Theme: ${ThemeService.isDarkMode ? 'Dark' : 'Light'} Mode',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
