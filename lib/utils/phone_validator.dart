class PhoneValidator {
  static String? validate(String? value, String errorMessage) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage;
    }

    final phone = value.trim();
    // must be exactly 8 digits
    if (phone.length != 8) {
      return 'Le numéro doit contenir exactement 8 chiffres.';
    }

    // must start with 9,5,2,4,7
    if (!RegExp(r'^[95247]').hasMatch(phone)) {
      return 'Le numéro doit commencer par 9,5,2,4 ou 7.';
    }

    // must be all digits
    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
      return 'Le numéro ne doit contenir que des chiffres.';
    }

    return null; // valid
  }
}
