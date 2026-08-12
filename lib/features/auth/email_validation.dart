/// Form validators for the sign-in and sign-up forms.
///
/// Pure functions rather than closures inside the widgets, so the rules can be
/// exercised directly against the addresses that matter.
library;

/// Null when [value] looks like an email address, otherwise the reason.
///
/// Deliberately permissive. The previous pattern,
/// `^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+`, turned away real addresses —
/// plus-addressing (`user+gym@gmail.com`), underscores, and hyphenated domains
/// (`me@my-site.com`) — while being unanchored at the end, so it was lax
/// exactly where it thought it was strict.
///
/// A client-side check can only catch obvious typos; the confirmation email is
/// the real proof an address exists. So this rejects what cannot possibly be an
/// address and lets everything else through.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Please enter your email';

  final parts = email.split('@');
  if (parts.length != 2) return 'Please enter a valid email';

  final [local, domain] = parts;
  if (local.isEmpty || domain.isEmpty) return 'Please enter a valid email';
  if (email.contains(RegExp(r'\s'))) return 'Please enter a valid email';

  // A domain with no dot cannot be reached from the public internet.
  if (!domain.contains('.')) return 'Please enter a valid email';
  if (domain.startsWith('.') || domain.endsWith('.')) {
    return 'Please enter a valid email';
  }

  return null;
}

/// Null when [value] is a usable password, otherwise the reason.
///
/// Six characters is Supabase's own default minimum; the server enforces it
/// regardless, and a mismatch here would only produce a confusing round trip.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Please enter a password';
  if (value.length < 6) return 'Password must be at least 6 characters';
  return null;
}
