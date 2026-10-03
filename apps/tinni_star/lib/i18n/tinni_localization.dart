const List<String> tinniSupportedLanguages = <String>[
  'English',
  'Hindi',
  'Urdu',
  'Arabic',
  'Bengali',
  'Malayalam',
  'Filipino (Tagalog)',
  'Persian (Farsi)',
  'Kurdish',
  'Baluchi',
  'Chinese (Simplified)',
  'Chinese (Traditional)',
  'Korean',
];

const Set<String> tinniRtlLanguages = <String>{
  'Urdu',
  'Arabic',
  'Persian (Farsi)',
  'Kurdish',
  'Baluchi',
};

bool tinniIsSupportedLanguage(String value) =>
    tinniSupportedLanguages.contains(value.trim());

bool tinniIsRtlLanguage(String value) =>
    tinniRtlLanguages.contains(value.trim());

String tinniText(String language, String key) {
  final normalized = language.trim().toLowerCase();
  final Map<String, String> values;
  switch (normalized) {
    case 'hindi':
      values = _hindi;
      break;
    case 'urdu':
      values = _urdu;
      break;
    case 'arabic':
      values = _arabic;
      break;
    case 'bengali':
      values = _bengali;
      break;
    case 'malayalam':
      values = _malayalam;
      break;
    case 'filipino (tagalog)':
      values = _filipino;
      break;
    case 'persian (farsi)':
      values = _persian;
      break;
    case 'kurdish':
      values = _kurdish;
      break;
    case 'baluchi':
      values = _baluchi;
      break;
    case 'chinese (simplified)':
      values = _chineseSimplified;
      break;
    case 'chinese (traditional)':
      values = _chineseTraditional;
      break;
    case 'korean':
      values = _korean;
      break;
    default:
      values = _english;
  }
  return values[key] ?? _english[key] ?? key;
}

const Map<String, String> _english = <String, String>{
  'party': 'Party',
  'discover': 'Discover',
  'message': 'Message',
  'mine': 'Mine',
  'follow': 'Follow',
  'fans': 'Fans',
  'charm': 'Charm',
  'wallet': 'Wallet',
  'wealth_level': 'Wealth level',
  'medal_of_honor': 'Medal of Honor',
  'custom_center': 'Custom Center',
  'shop': 'Shop',
  'props': 'Props',
  'reward_records': 'Reward Records',
  'task': 'Task',
  'host_data': 'Host data',
  'family': 'Family',
  'cp_nest': 'CP Nest',
  'feedback': 'Feedback',
  'setting': 'Setting',
  'message_notification': 'Message notification',
  'bind_account': 'Bind account',
  'language_settings': 'Language settings',
  'about_tinni': 'About Tinni Star',
  'blocklist': 'Blocklist',
  'privacy_statement': 'Privacy statement',
  'sign_out': 'Sign out',
  'voice': 'Voice',
  'vibration': 'Vibration',
  'floating_room_only': 'Only receive floating screen in the room',
  'car': 'Car',
  'profile': 'Profile',
  'lucky': 'Lucky',
  'ring': 'Ring',
  'profile_background': 'Profile Background',
  'entrance': 'Entrance',
  'bubble': 'Bubble',
  'frame': 'Frame',
  'my_items': 'My items',
  'purchase': 'Purchase',
  'send': 'Send',
  'use': 'Use',
  'using': 'Using',
  'remove': 'Remove',
  'permanent': 'Permanent',
  'family_wallet': 'Family Wallet',
  'daily_check_in': 'Daily Check-in',
  'family_announcement': 'Family Announcement',
  'member_list': 'Member List',
  'family_level': 'Family Level',
  'family_members': 'Family Members',
  'join_requests': 'Join Requests',
  'members': 'Members',
  'create': 'Create',
  'open': 'Open',
  'request_to_join': 'Request to Join',
  'home': 'Home',
  'trends': 'Trends',
};

const Map<String, String> _hindi = <String, String>{
  'party': 'पार्टी',
  'discover': 'खोजें',
  'message': 'संदेश',
  'mine': 'मेरा',
  'follow': 'फॉलो',
  'fans': 'फैन्स',
  'charm': 'चार्म',
  'wallet': 'वॉलेट',
  'wealth_level': 'वेल्थ लेवल',
  'medal_of_honor': 'मेडल ऑफ ऑनर',
  'custom_center': 'कस्टम सेंटर',
  'shop': 'शॉप',
  'props': 'प्रॉप्स',
  'reward_records': 'रिवॉर्ड रिकॉर्ड',
  'task': 'टास्क',
  'host_data': 'होस्ट डेटा',
  'family': 'फैमिली',
  'cp_nest': 'CP नेस्ट',
  'feedback': 'फीडबैक',
  'setting': 'सेटिंग',
  'message_notification': 'मैसेज नोटिफिकेशन',
  'bind_account': 'अकाउंट लिंक करें',
  'language_settings': 'भाषा सेटिंग',
  'about_tinni': 'Tinni Star के बारे में',
  'blocklist': 'ब्लॉकलिस्ट',
  'privacy_statement': 'प्राइवेसी स्टेटमेंट',
  'sign_out': 'साइन आउट',
  'voice': 'आवाज़',
  'vibration': 'वाइब्रेशन',
  'floating_room_only': 'फ्लोटिंग स्क्रीन केवल रूम में दिखाएँ',
  'car': 'कार',
  'profile': 'प्रोफाइल',
  'lucky': 'लकी',
  'ring': 'रिंग',
  'profile_background': 'प्रोफाइल बैकग्राउंड',
  'entrance': 'एंट्रेंस',
  'bubble': 'बबल',
  'frame': 'फ्रेम',
  'my_items': 'मेरे आइटम',
  'purchase': 'खरीदें',
  'send': 'भेजें',
  'use': 'लगाएँ',
  'using': 'लगा हुआ',
  'remove': 'हटाएँ',
  'permanent': 'परमानेंट',
  'family_wallet': 'फैमिली वॉलेट',
  'daily_check_in': 'डेली चेक-इन',
  'family_announcement': 'फैमिली घोषणा',
  'member_list': 'मेंबर लिस्ट',
  'family_level': 'फैमिली लेवल',
  'family_members': 'फैमिली मेंबर्स',
  'join_requests': 'जॉइन रिक्वेस्ट',
  'members': 'मेंबर्स',
  'create': 'बनाएँ',
  'open': 'खोलें',
  'request_to_join': 'जॉइन रिक्वेस्ट भेजें',
  'home': 'होम',
  'trends': 'ट्रेंड्स',
};

const Map<String, String> _urdu = <String, String>{
  'party': 'پارٹی',
  'discover': 'تلاش',
  'message': 'پیغام',
  'mine': 'میرا',
  'follow': 'فالو',
  'fans': 'فینز',
  'charm': 'چارم',
  'wallet': 'والیٹ',
  'wealth_level': 'ویلتھ لیول',
  'medal_of_honor': 'میڈل آف آنر',
  'custom_center': 'کسٹم سینٹر',
  'shop': 'شاپ',
  'props': 'پراپس',
  'reward_records': 'ریوارڈ ریکارڈ',
  'task': 'ٹاسک',
  'host_data': 'ہوسٹ ڈیٹا',
  'family': 'فیملی',
  'cp_nest': 'CP نیسٹ',
  'feedback': 'فیڈبیک',
  'setting': 'سیٹنگ',
  'message_notification': 'میسج نوٹیفکیشن',
  'bind_account': 'اکاؤنٹ لنک کریں',
  'language_settings': 'زبان کی سیٹنگ',
  'about_tinni': 'Tinni Star کے بارے میں',
  'blocklist': 'بلاک لسٹ',
  'privacy_statement': 'پرائیویسی اسٹیٹمنٹ',
  'sign_out': 'سائن آؤٹ',
  'voice': 'آواز',
  'vibration': 'وائبریشن',
  'floating_room_only': 'فلوٹنگ اسکرین صرف روم میں دکھائیں',
  'car': 'کار',
  'profile': 'پروفائل',
  'lucky': 'لکی',
  'ring': 'رِنگ',
  'profile_background': 'پروفائل بیک گراؤنڈ',
  'entrance': 'انٹرنس',
  'bubble': 'ببل',
  'frame': 'فریم',
  'my_items': 'میرے آئٹمز',
  'purchase': 'خریدیں',
  'send': 'بھیجیں',
  'use': 'استعمال کریں',
  'using': 'استعمال میں',
  'remove': 'ہٹائیں',
  'permanent': 'مستقل',
  'family_wallet': 'فیملی والیٹ',
  'daily_check_in': 'روزانہ چیک اِن',
  'family_announcement': 'فیملی اعلان',
  'member_list': 'ممبر لسٹ',
  'family_level': 'فیملی لیول',
  'family_members': 'فیملی ممبرز',
  'join_requests': 'جوائن درخواستیں',
  'members': 'ممبرز',
  'create': 'بنائیں',
  'open': 'کھولیں',
  'request_to_join': 'جوائن درخواست بھیجیں',
  'home': 'ہوم',
  'trends': 'ٹرینڈز',
};


const Map<String, String> _arabic = <String, String>{
  'party': 'حفلة',
  'discover': 'اكتشف',
  'message': 'الرسائل',
  'mine': 'حسابي',
  'follow': 'متابَعون',
  'fans': 'المعجبون',
  'charm': 'السحر',
  'wallet': 'المحفظة',
  'wealth_level': 'مستوى الثروة',
  'medal_of_honor': 'وسام الشرف',
  'custom_center': 'المركز المخصص',
  'shop': 'المتجر',
  'props': 'العناصر',
  'reward_records': 'سجل المكافآت',
  'task': 'المهام',
  'family': 'العائلة',
  'cp_nest': 'عش CP',
  'feedback': 'الملاحظات',
  'setting': 'الإعدادات',
};

const Map<String, String> _bengali = <String, String>{
  'party': 'পার্টি',
  'discover': 'খুঁজুন',
  'message': 'বার্তা',
  'mine': 'আমার',
  'follow': 'ফলো',
  'fans': 'ফ্যান',
  'charm': 'চার্ম',
  'wallet': 'ওয়ালেট',
  'wealth_level': 'সম্পদ স্তর',
  'medal_of_honor': 'সম্মান পদক',
  'custom_center': 'কাস্টম সেন্টার',
  'shop': 'শপ',
  'props': 'আইটেম',
  'reward_records': 'পুরস্কার রেকর্ড',
  'task': 'টাস্ক',
  'family': 'পরিবার',
  'cp_nest': 'CP নেস্ট',
  'feedback': 'ফিডব্যাক',
  'setting': 'সেটিংস',
};

const Map<String, String> _malayalam = <String, String>{
  'party': 'പാർട്ടി',
  'discover': 'കണ്ടെത്തുക',
  'message': 'സന്ദേശം',
  'mine': 'എന്റെത്',
  'follow': 'ഫോളോ',
  'fans': 'ഫാൻസ്',
  'charm': 'ചാർം',
  'wallet': 'വാലറ്റ്',
  'wealth_level': 'സമ്പത്ത് നില',
  'medal_of_honor': 'ബഹുമതി മെഡൽ',
  'custom_center': 'കസ്റ്റം സെന്റർ',
  'shop': 'ഷോപ്പ്',
  'props': 'ഐറ്റങ്ങൾ',
  'reward_records': 'റിവാർഡ് റെക്കോർഡുകൾ',
  'task': 'ടാസ്ക്',
  'family': 'കുടുംബം',
  'cp_nest': 'CP നെസ്റ്റ്',
  'feedback': 'ഫീഡ്ബാക്ക്',
  'setting': 'സെറ്റിംഗ്സ്',
};

const Map<String, String> _filipino = <String, String>{
  'party': 'Party',
  'discover': 'Tuklasin',
  'message': 'Mensahe',
  'mine': 'Akin',
  'follow': 'Sinusundan',
  'fans': 'Mga Fan',
  'charm': 'Charm',
  'wallet': 'Wallet',
  'wealth_level': 'Antas ng Yaman',
  'medal_of_honor': 'Medalya ng Karangalan',
  'custom_center': 'Custom Center',
  'shop': 'Tindahan',
  'props': 'Mga Item',
  'reward_records': 'Tala ng Gantimpala',
  'task': 'Gawain',
  'family': 'Pamilya',
  'cp_nest': 'CP Nest',
  'feedback': 'Feedback',
  'setting': 'Settings',
};

const Map<String, String> _persian = <String, String>{
  'party': 'پارتی',
  'discover': 'کشف',
  'message': 'پیام',
  'mine': 'من',
  'follow': 'دنبال‌شده',
  'fans': 'طرفداران',
  'charm': 'جذابیت',
  'wallet': 'کیف پول',
  'wealth_level': 'سطح ثروت',
  'medal_of_honor': 'نشان افتخار',
  'custom_center': 'مرکز سفارشی',
  'shop': 'فروشگاه',
  'props': 'آیتم‌ها',
  'reward_records': 'سوابق پاداش',
  'task': 'وظیفه',
  'family': 'خانواده',
  'cp_nest': 'لانه CP',
  'feedback': 'بازخورد',
  'setting': 'تنظیمات',
};

const Map<String, String> _kurdish = <String, String>{
  'party': 'پارتی',
  'discover': 'دۆزینەوە',
  'message': 'پەیام',
  'mine': 'هی من',
  'follow': 'شوێنکەوتن',
  'fans': 'هەواداران',
  'charm': 'جوانی',
  'wallet': 'جزدان',
  'wealth_level': 'ئاستی دەوڵەمەندی',
  'medal_of_honor': 'میداڵی شانازی',
  'custom_center': 'ناوەندی تایبەت',
  'shop': 'فرۆشگا',
  'props': 'ئایتمەکان',
  'reward_records': 'تۆماری خەڵات',
  'task': 'ئەرک',
  'family': 'خێزان',
  'cp_nest': 'CP Nest',
  'feedback': 'فیدباک',
  'setting': 'ڕێکخستن',
};

const Map<String, String> _baluchi = <String, String>{
  'party': 'پارٹی',
  'discover': 'دریافت',
  'message': 'پیغام',
  'mine': 'منی',
  'follow': 'دنبال',
  'fans': 'هوادار',
  'charm': 'کشش',
  'wallet': 'والٹ',
  'wealth_level': 'دولت ءِ سطح',
  'medal_of_honor': 'عزت ءِ تمغہ',
  'custom_center': 'کسٹم سینٹر',
  'shop': 'دکان',
  'props': 'آئٹم',
  'reward_records': 'انعام ءِ ریکارڈ',
  'task': 'کار',
  'family': 'خاندان',
  'cp_nest': 'CP Nest',
  'feedback': 'فیڈبیک',
  'setting': 'سیٹنگ',
};

const Map<String, String> _chineseSimplified = <String, String>{
  'party': '派对',
  'discover': '发现',
  'message': '消息',
  'mine': '我的',
  'follow': '关注',
  'fans': '粉丝',
  'charm': '魅力',
  'wallet': '钱包',
  'wealth_level': '财富等级',
  'medal_of_honor': '荣誉勋章',
  'custom_center': '自定义中心',
  'shop': '商店',
  'props': '道具',
  'reward_records': '奖励记录',
  'task': '任务',
  'family': '家族',
  'cp_nest': 'CP 小窝',
  'feedback': '反馈',
  'setting': '设置',
};

const Map<String, String> _chineseTraditional = <String, String>{
  'party': '派對',
  'discover': '探索',
  'message': '訊息',
  'mine': '我的',
  'follow': '關注',
  'fans': '粉絲',
  'charm': '魅力',
  'wallet': '錢包',
  'wealth_level': '財富等級',
  'medal_of_honor': '榮譽勳章',
  'custom_center': '自訂中心',
  'shop': '商店',
  'props': '道具',
  'reward_records': '獎勵記錄',
  'task': '任務',
  'family': '家族',
  'cp_nest': 'CP 小窩',
  'feedback': '意見回饋',
  'setting': '設定',
};

const Map<String, String> _korean = <String, String>{
  'party': '파티',
  'discover': '탐색',
  'message': '메시지',
  'mine': '내 정보',
  'follow': '팔로우',
  'fans': '팬',
  'charm': '매력',
  'wallet': '지갑',
  'wealth_level': '부 레벨',
  'medal_of_honor': '명예 훈장',
  'custom_center': '커스텀 센터',
  'shop': '상점',
  'props': '아이템',
  'reward_records': '보상 기록',
  'task': '미션',
  'family': '패밀리',
  'cp_nest': 'CP 네스트',
  'feedback': '피드백',
  'setting': '설정',
};
