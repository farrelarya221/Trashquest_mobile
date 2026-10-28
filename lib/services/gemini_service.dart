import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../data/models/waste_item.dart';

/// Structured response from multimodal waste & circular intelligence
class GeminiClassificationResult {
  final String name;
  final WasteCategory category;
  final bool recyclable;
  final String disposalAdvice;
  final String notes;
  final double confidence;
  final bool isUncertain;
  final String upcycleIdea;
  final String economicValue;
  final String carbonImpact;
  final String decompositionTime;

  const GeminiClassificationResult({
    required this.name,
    required this.category,
    required this.recyclable,
    required this.disposalAdvice,
    required this.notes,
    this.confidence = 0.95,
    this.isUncertain = false,
    this.upcycleIdea = 'Dapat dikreasikan menjadi wadah penyimpanan serbaguna.',
    this.economicValue = 'Rp 2.000 - 3.500 / kg di Bank Sampah',
    this.carbonImpact = 'Menghemat ~0.05 kg emisi CO2 jika didaur ulang',
    this.decompositionTime = 'Ratusan tahun jika tertimbun di TPA',
  });

  factory GeminiClassificationResult.uncertain() {
    return const GeminiClassificationResult(
      name: 'Objek Belum Teridentifikasi',
      category: WasteCategory.residu,
      recyclable: false,
      disposalAdvice: 'Coba ambil foto dari jarak lebih dekat dan pastikan pencahayaan cukup terang.',
      notes: 'AI belum yakin dengan jenis objek ini untuk menjaga akurasi pemilahan.',
      confidence: 0.35,
      isUncertain: true,
      upcycleIdea: 'Pastikan objek bersih dan jelas terlihat di kamera.',
      economicValue: '-',
      carbonImpact: '-',
      decompositionTime: '-',
    );
  }
}

/// Service handling multimodal vision intelligence and conversational AI
/// Powered by ultra-fast Groq LPU + redundant Google Gemini fallback.
class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  // API Keys
  static const String _defaultGeminiKey = 'AQ.Ab8RN6IdJeZJpwsL00I6n6bbgr9W7iZPkLnkecVLE_JpoVogxg';
  static const String _defaultGroqKey = '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';

  static const String prefApiKey = 'custom_gemini_api_key';
  static const String prefGroqKey = 'custom_groq_api_key';

  String? _customGeminiKey;
  String? _customGroqKey;

  // Active Gemini models (free/available models)
  static const List<String> _geminiModels = [
    'gemini-3.1-flash-lite',
    'gemini-3.8-flash',
  ];

  Future<String> getEffectiveApiKey() async {
    if (_customGeminiKey != null && _customGeminiKey!.isNotEmpty) {
      return _customGeminiKey!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefApiKey);
      if (saved != null && saved.isNotEmpty) {
        _customGeminiKey = saved;
        return saved;
      }
    } catch (_) {}
    return _defaultGeminiKey;
  }

  Future<void> setCustomApiKey(String key) async {
    _customGeminiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefApiKey, key.trim());
    } catch (_) {}
  }

  Future<String> getEffectiveGroqKey() async {
    if (_customGroqKey != null && _customGroqKey!.isNotEmpty) {
      return _customGroqKey!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefGroqKey);
      if (saved != null && saved.isNotEmpty) {
        _customGroqKey = saved;
        return saved;
      }
    } catch (_) {}
    return _defaultGroqKey;
  }

  Future<void> setCustomGroqKey(String key) async {
    _customGroqKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefGroqKey, key.trim());
    } catch (_) {}
  }

  static const _visionPrompt = '''
Kamu adalah EcoSense AI, pakar sains lingkungan, pengelolaan limbah, dan ekonomi sirkular Indonesia.
Analisis gambar ini dan kembalikan HANYA JSON valid (tanpa blok markdown atau teks tambahan) dengan struktur:
{
  "name": "nama spesifik objek/material (contoh: Botol Plastik PET, Kardus Bekas, Sisa Makanan, Baterai Bekas)",
  "category": "organik | anorganik | b3 | residu",
  "recyclable": true atau false,
  "disposalAdvice": "langkah pemilahan/pembuangan praktis yang benar",
  "notes": "fakta ilmiah atau tips penanganan material",
  "upcycleIdea": "ide kreatif DIY atau pemanfaatan kembali dari material ini",
  "economicValue": "estimasi nilai jual per kg di bank sampah Indonesia",
  "carbonImpact": "dampak pencegahan emisi karbon atau penghematan energi",
  "decompositionTime": "waktu penguraian alami jika dibuang sembarangan",
  "isUncertain": true jika gambar blur/tidak jelas/bukan objek sampah
}
''';

  /// Multimodal image classification: First tries Groq Vision (~1s), then fallbacks to Gemini.
  Future<GeminiClassificationResult> classifyWasteImage(dynamic imageFile) async {
    List<int> bytes;
    if (imageFile is File) {
      bytes = await imageFile.readAsBytes();
    } else if (imageFile is Uint8List) {
      bytes = imageFile;
    } else {
      return GeminiClassificationResult.uncertain();
    }

    // 1. PRIMARY: Coba Groq Vision (qwen/qwen3.8-27b) untuk kecepatan kilat ~1 detik & akurasi tinggi
    final groqKey = await getEffectiveGroqKey();
    if (groqKey.isNotEmpty) {
      try {
        final base64Image = base64Encode(bytes);
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $groqKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'qwen/qwen3.8-27b',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': _visionPrompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                  }
                ]
              }
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0.1,
            'max_tokens': 600,
          }),
        ).timeout(const Duration(seconds: 14));

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final rawContent = resData['choices']?[0]?['message']?['content'] as String?;
          if (rawContent != null && rawContent.isNotEmpty) {
            final parsed = jsonDecode(rawContent);
            if (parsed['isUncertain'] == true) {
              return GeminiClassificationResult.uncertain();
            }
            return GeminiClassificationResult(
              name: parsed['name'] ?? 'Material Terdeteksi',
              category: WasteCategory.fromString(parsed['category']?.toString()),
              recyclable: parsed['recyclable'] == true,
              disposalAdvice: parsed['disposalAdvice'] ?? 'Pilah sesuai kategori tempat sampah.',
              notes: parsed['notes'] ?? 'Bersihkan sebelum dipilah.',
              upcycleIdea: parsed['upcycleIdea'] ?? 'Dapat dikreasikan menjadi barang guna ulang.',
              economicValue: parsed['economicValue'] ?? 'Bernilai ekonomis di Bank Sampah',
              carbonImpact: parsed['carbonImpact'] ?? 'Mencegah emisi gas rumah kaca',
              decompositionTime: parsed['decompositionTime'] ?? 'Memerlukan waktu penguraian panjang',
              confidence: 0.96,
            );
          }
        } else {
          debugPrint('Groq Vision HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Groq Vision error, falling back to Gemini: $e');
      }
    }

    // 2. FALLBACK: Coba Google Gemini
    final geminiKey = await getEffectiveApiKey();
    if (geminiKey.isNotEmpty) {
      for (final modelName in _geminiModels) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: geminiKey,
            generationConfig: GenerationConfig(
              temperature: 0.1,
              responseMimeType: 'application/json',
              maxOutputTokens: 600,
            ),
          );

          final response = await model.generateContent([
            Content.multi([
              TextPart(_visionPrompt),
              DataPart('image/jpeg', Uint8List.fromList(bytes)),
            ])
          ]).timeout(const Duration(seconds: 25));

          final candidateText = response.text ?? '';
          if (candidateText.isNotEmpty) {
            final parsed = jsonDecode(candidateText);
            if (parsed['isUncertain'] == true) {
              return GeminiClassificationResult.uncertain();
            }
            return GeminiClassificationResult(
              name: parsed['name'] ?? 'Material Terdeteksi',
              category: WasteCategory.fromString(parsed['category']?.toString()),
              recyclable: parsed['recyclable'] == true,
              disposalAdvice: parsed['disposalAdvice'] ?? 'Pilah sesuai kategori tempat sampah.',
              notes: parsed['notes'] ?? 'Bersihkan sebelum dipilah.',
              upcycleIdea: parsed['upcycleIdea'] ?? 'Dapat dikreasikan menjadi barang guna ulang.',
              economicValue: parsed['economicValue'] ?? 'Bernilai ekonomis di Bank Sampah',
              carbonImpact: parsed['carbonImpact'] ?? 'Mencegah emisi gas rumah kaca',
              decompositionTime: parsed['decompositionTime'] ?? 'Memerlukan waktu penguraian panjang',
              confidence: 0.94,
            );
          }
        } catch (e) {
          debugPrint('Gemini vision error on $modelName: $e');
        }
      }
    }

    return const GeminiClassificationResult(
      name: 'Belum Terdeteksi',
      category: WasteCategory.residu,
      recyclable: false,
      disposalAdvice: 'Arahkan kamera lebih dekat ke objek, pastikan pencahayaan terang lalu coba ketuk scan ulang.',
      notes: 'Server AI sedang dalam antrean atau foto kurang fokus.',
      upcycleIdea: 'Pastikan objek bersih dan jelas.',
      economicValue: '-',
      carbonImpact: '-',
      decompositionTime: '-',
      confidence: 0.0,
      isUncertain: true,
    );
  }

  // Conversation history for Groq & Gemini
  final List<Map<String, String>> _groqChatHistory = [];
  ChatSession? _geminiChatSession;

  static const _systemInstruction = '''
Kamu adalah TrashQuest AI, asisten virtual cerdas, ramah, dan edukatif yang KHUSUS berfokus pada topik seputar SAMPAH, pemilahan limbah, daur ulang, dan pelestarian lingkungan hidup.

ATURAN BATASAN KONTEKS (SANGAT PENTING):
1. RUANG LINGKUP RESMI (HANYA SEPUTAR SAMPAH & LIMBAH):
   - Kamu HANYA diperbolehkan menjawab pertanyaan atau berdiskusi seputar:
     * Identifikasi, jenis, dan pemilahan sampah (organik, anorganik, B3, residu, e-waste/elektronik, medis, plastik, kertas, kaca, logam, dll.).
     * Cara penanganan, pembuangan, dan sistem pengelolaan sampah (bank sampah, TPS, TPA, Tempat Pengolahan Sampah Terpadu).
     * Daur ulang (recycling), ide kreatif dan kerajinan upcycling dari barang/sampah bekas.
     * Pembuatan pupuk kompos dari sampah organik/sisa makanan, biopori, eco-enzyme, dan waktu penguraian material sampah.
     * Dampak limbah/sampah terhadap lingkungan hidup, pencemaran air/tanah/udara, emisi karbon, serta gaya hidup ramah lingkungan minim sampah (zero waste).

2. PENOLAKAN KETAT UNTUK PERTANYAAN DI LUAR TOPIK SAMPAH:
   - Jika pengguna menanyakan hal atau membuka obrolan DI LUAR konteks sampah (contoh: koding/programming, matematika umum, politik, asmara/curhat cinta, gosip, resep masakan umum di luar sisa makanan/kompos, teknologi umum, sejarah di luar isu sampah, dll.):
   - Kamu WAJIB menolak secara sopan dan ramah, serta SELALU diawali dengan kata maaf (misalnya: "Maaf, ..." atau "Mohon maaf, ...").
   - Tegaskan bahwa peranmu dibatasi khusus untuk membahas seputar sampah, pemilahan, daur ulang, dan pengelolaan limbah.
   - Berikan rekomendasi singkat mengenai hal seputar sampah yang bisa ditanyakan.
   - Contoh respon penolakan:
     "Maaf, aku hanya bisa menjawab pertanyaan dan berdiskusi seputar sampah, pemilahan limbah, daur ulang, dan kebersihan lingkungan hidup. Ada yang ingin kamu tanyakan tentang cara memilah sampah atau ide daur ulang hari ini?"

3. KEPRIBADIAN & GAYA KOMUNIKASI:
   - Berbicaralah secara ramah, santai, luwes, dan hangat layaknya teman peduli lingkungan.
   - Jawablah langsung to-the-point, jelas, dan solutif.
   - Gunakan bahasa Indonesia sehari-hari yang natural dan mengalir.
''';

  /// Reset sesi percakapan untuk memulai topik baru dari awal
  void resetChatSession() {
    _groqChatHistory.clear();
    _geminiChatSession = null;
  }

  /// Percakapan AI Chatbot — Primary: Groq (~700ms) → Fallback: Gemini
  Future<String> askAi({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    // 1. PRIMARY: Groq Chat (openai/gpt-oss-120b atau qwen/qwen3.8-27b) untuk respons instan < 1 detik
    final groqKey = await getEffectiveGroqKey();
    if (groqKey.isNotEmpty) {
      for (final groqModel in ['openai/gpt-oss-120b', 'qwen/qwen3.8-27b']) {
        try {
          _groqChatHistory.add({'role': 'user', 'content': userMessage});
          if (_groqChatHistory.length > 16) {
            _groqChatHistory.removeRange(0, _groqChatHistory.length - 16);
          }

          final response = await http.post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $groqKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': groqModel,
              'messages': [
                {'role': 'system', 'content': _systemInstruction},
                ..._groqChatHistory,
              ],
              'temperature': 0.7,
              'max_tokens': 450,
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final answer = data['choices']?[0]?['message']?['content'] as String?;
            if (answer != null && answer.trim().isNotEmpty) {
              _groqChatHistory.add({'role': 'assistant', 'content': answer.trim()});
              return answer.trim();
            }
          } else {
            debugPrint('Groq Chat ($groqModel) HTTP ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          debugPrint('Groq Chat error ($groqModel): $e');
        }
      }
    }

    // 2. FALLBACK: Gemini Generative AI
    final geminiKey = await getEffectiveApiKey();
    if (geminiKey.isNotEmpty) {
      for (final modelName in _geminiModels) {
        try {
          if (_geminiChatSession == null) {
            final model = GenerativeModel(
              model: modelName,
              apiKey: geminiKey,
              systemInstruction: Content.system(_systemInstruction),
              generationConfig: GenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 350,
              ),
            );
            _geminiChatSession = model.startChat();
          }

          final response = await _geminiChatSession!
              .sendMessage(Content.text(userMessage))
              .timeout(const Duration(seconds: 20));

          final answer = response.text?.trim();
          if (answer != null && answer.isNotEmpty) {
            return answer;
          }
        } catch (e) {
          debugPrint('Gemini Chat error on $modelName: $e');
          _geminiChatSession = null;
        }
      }
    }

    return 'Waduh, koneksi internetmu sepertinya sempat terputus nih 📶. Coba periksa sinyal lalu kirim lagi ya!';
  }
}