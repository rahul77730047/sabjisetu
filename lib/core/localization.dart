import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Localization extends ChangeNotifier {
  static final Localization _instance = Localization._internal();
  factory Localization() => _instance;
  Localization._internal();

  bool _isHindi = false;
  bool get isHindi => _isHindi;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isHindi = prefs.getBool('is_hindi') ?? false;
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _isHindi = !_isHindi;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_hindi', _isHindi);
    notifyListeners();
  }

  String translate(String key) {
    if (!_isHindi) {
      if (key.toLowerCase() == 'sabzisetu') return 'SabziSetu';
      return key.replaceAll('_', ' ').split(' ').map((str) => str.isNotEmpty ? str[0].toUpperCase() + str.substring(1).toLowerCase() : '').join(' ');
    }

    final k = key.toLowerCase().trim();
    if (k == 'sabzisetu') return 'SabziSetu';

    final map = <String, String>{
      // Navigation & Titles
      'dashboard': 'डैशबोर्ड',
      'mandi purchase': 'मंडी खरीद',
      'local purchase': 'स्थानीय खरीद',
      'stock / inventory': 'स्टॉक / इन्वेंटरी',
      'stock movements': 'स्टॉक हलचल',
      'sales / supply': 'बिक्री / आपूर्ति',
      'customers': 'ग्राहक',
      'payments & due': 'भुगतान और बकाया',
      'expenses': 'खर्चे',
      'labour / majdoor': 'मजदूर / श्रमिक',
      'reports & analytics': 'रिपोर्ट और विश्लेषण',
      'whatsapp bills': 'व्हाट्सएप बिल',
      'notifications': 'सूचनाएं',
      'settings': 'सेटिंग्स',
      'backup / export': 'बैकअप / एक्सपोर्ट',
      'stock history': 'स्टॉक इतिहास',
      'units': 'इकाई मास्टर',
      'vendors': 'विक्रेता मास्टर',
      'security': 'सुरक्षा',
      'business': 'व्यवसाय',
      'item master': 'आइटम मास्टर',
      'vegetable / item master': 'सब्जी / आइटम मास्टर',

      // Actions & Buttons
      'add': 'जोड़ें',
      'edit': 'सुधारें',
      'delete': 'हटाएं',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'retry': 'पुनः प्रयास करें',
      'login': 'लॉगिन',
      'logout': 'लॉगआउट',
      'search': 'खोजें',
      'update': 'अपडेट करें',
      'add item': 'वस्तु जोड़ें',
      'save settings': 'सेटिंग्स सहेजें',
      'update password': 'पासवर्ड अपडेट करें',

      // Form Labels & Table Columns
      'date': 'तारीख',
      'vendor': 'विक्रेता',
      'item': 'वस्तु',
      'quantity': 'मात्रा',
      'unit': 'इकाई',
      'rate': 'दर',
      'amount': 'कुल राशि',
      'customer': 'ग्राहक',
      'status': 'स्थिति',
      'note': 'नोट',
      'specification': 'विवरण',
      'qty': 'मात्रा',
      'avg cost': 'औसत लागत',
      'selling price': 'विक्रय मूल्य',
      'phone': 'फोन',
      'due': 'बकाया',
      'business name': 'व्यापार का नाम',
      'owner': 'मालिक',
      'tagline': 'टैगलाइन',
      'currency': 'मुद्रा',
      'low stock threshold (kg)': 'कम स्टॉक सीमा (Kg)',
      'due date': 'बकाया तिथि',
      'work type': 'काम का प्रकार',
      'workers': 'मजदूर',
      'category': 'श्रेणी',
      'movement date': 'हलचल की तारीख',
      'qty change': 'मात्रा बदलाव',
      'source type': 'स्रोत प्रकार',
      'payment method': 'भुगतान का तरीका',
      'transaction id': 'लेनदेन आईडी',
      'hindi': 'हिंदी',
      'specs': 'विवरण',
      'conversion': 'परिवर्तन',
      'english name': 'अंग्रेजी नाम',
      'hindi name': 'हिंदी नाम',
      'kg multiplier': 'किलोग्राम गुणांक',
      'name': 'नाम',

      // Dashboard Specific
      'welcome back': 'स्वागत है',
      'business pulse': 'बिजनेस पल्स',
      'sales vs purchase': 'बिक्री बनाम खरीद',
      'outstanding due': 'कुल बकाया',
      'today\'s sales': 'आज की बिक्री',
      'today\'s purchase': 'आज की खरीद',
      'gross profit': 'सकल लाभ',
      'net profit': 'शुद्ध लाभ',
      'recent due list': 'हालिया बकाया सूची',
      'recent sales': 'हालिया बिक्री',
      'stock alerts': 'स्टॉक अलर्ट',
      'low stock': 'कम स्टॉक',
      'available': 'उपलब्ध',
      'out of stock': 'स्टॉक खत्म',
      'overdue': 'समय सीमा पार',
      'due today': 'आज बकाया',
      'upcoming': 'आगामी',

      // Messages & Dialogs
      'are you sure': 'क्या आप वाकई चाहते हैं?',
      'delete entry': 'प्रविष्टि हटाएं?',
      'no records found': 'कोई रिकॉर्ड नहीं मिला',
      'loading': 'लोड हो रहा है...',
      'success': 'सफल',
      'error': 'त्रुटि',
      'unauthorized': 'अनधिकृत',
      'password changed': 'पासवर्ड बदल गया',
      'is required': 'अनिवार्य है',
      'all fields': 'सभी फ़ील्ड',
      'invalid credentials': 'गलत आईडी या पासवर्ड',
      'enabled': 'सक्षम',
      'disabled': 'अक्षम',
      'change account password': 'अकाउंट पासवर्ड बदलें',
      'update your password to keep your business data secure.': 'अपने व्यवसाय डेटा को सुरक्षित रखने के लिए अपना पासवर्ड अपडेट करें।',
      'current password': 'वर्तमान पासवर्ड',
      'new password': 'नया पासवर्ड',
      'confirm new password': 'नए पासवर्ड की पुष्टि करें',
      'logout?': 'लॉगआउट करें?',
      'are you sure you want to sign out?': 'क्या आप वाकई साइन आउट करना चाहते हैं?',
      'id and password': 'आईडी और पासवर्ड',
      'login to account': 'खाते में लॉगिन करें',
      'smart trading platform': 'स्मार्ट ट्रेडिंग प्लेटफॉर्म',

      // Units
      'kilogram': 'किलोग्राम',
      'quintal': 'क्विंटल',
      'bag': 'बोरी',
      'carat': 'कैरेट',
    };

    return map[k] ?? key.replaceAll('_', ' ').toUpperCase();
  }
}
