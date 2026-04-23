Map<String, Map<String, String>> translations = {
  'login': {'fr': 'Se connecter', 'en': 'Login', 'ar': 'تسجيل الدخول'},
  'signup': {'fr': 'Créer un compte', 'en': 'Sign Up', 'ar': 'إنشاء حساب'},
  'phone': {'fr': 'Numéro de téléphone', 'en': 'Phone Number', 'ar': 'رقم الهاتف'},
  'password': {'fr': 'Mot de passe', 'en': 'Password', 'ar': 'كلمة المرور'},
  'forgot': {'fr': 'Mot de passe oublié ?', 'en': 'Forgot Password?', 'ar': 'نسيت كلمة المرور؟'},
  'full_name': {'fr': 'Nom complet', 'en': 'Full Name', 'ar': 'الاسم الكامل'},
  'password_length': {'fr': '6 caractères minimum', 'en': 'At least 6 characters', 'ar': '6 أحرف على الأقل'},
  'confirm_password': {'fr': 'Confirmer mot de passe', 'en': 'Confirm Password', 'ar': 'تأكيد كلمة المرور'},
  'password_mismatch': {'fr': 'Les mots de passe ne correspondent pas', 'en': 'Passwords do not match', 'ar': 'كلمات المرور غير متطابقة'},
  'signup_button': {'fr': 'S\'inscrire', 'en': 'Sign Up', 'ar': 'إنشاء حساب'},
  'error': {'fr': 'Erreur', 'en': 'Error', 'ar': 'خطأ'},
  'food': {'fr': 'Food', 'en': 'Food', 'ar': 'طعام'},
  'uber': {'fr': 'Uber', 'en': 'Uber', 'ar': 'أوبر'},
  'shop': {'fr': 'Shop', 'en': 'Shop', 'ar': 'متجر'},
  'transport': {'fr': 'Transport', 'en': 'Transport', 'ar': 'نقل'},
  'others': {'fr': 'Autres', 'en': 'Others', 'ar': 'أخرى'},
  'order': {'fr': 'Commander', 'en': 'Order', 'ar': 'طلب'},
  'offers': {'fr': 'Offres', 'en': 'Offers', 'ar': 'عروض'},
  'worker_title': {'fr': 'Kartoucha - Livreur', 'en': 'Kartoucha - Worker', 'ar': 'كرطوشة - عامل'},
  'title':{'fr': 'Kartoucha - Delivery', 'en': 'Kartoucha - Delivery', 'ar': "كرطوشة - لتوصيل"},
  'offline_message': {'fr': 'Vous êtes hors ligne', 'en': 'You are offline', 'ar': 'أنت غير متصل'},
  'activate_switch': {'fr': 'Activez le bouton pour recevoir des commandes', 'en': 'Activate the switch to receive orders', 'ar': 'قم بتفعيل الزر لاستلام الطلبات'},
  'accept_order': {'fr': 'Accepter la commande', 'en': 'Accept Order', 'ar': 'قبول الطلب'},
  'still_not_accepted_account': {'fr': 'Votre compte na pas encore été approuvé', 'en': 'Your account has not yet been approved.', 'ar': 'لم تتم الموافقة على حسابك بعد'},
};

String t(String key, String langCode) {
  return translations[key]?[langCode] ?? key;
}