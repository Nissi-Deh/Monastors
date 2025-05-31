import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  CloudinaryPublic? _cloudinary;
  Dio? _dio;
  String? _cloudName;
  String? _apiKey;
  String? _apiSecret;
  bool _isInitialized = false;
  Map<String, _CachedUrl> _urlCache = {};
  static const int _maxRetries = 3;
  static const Duration _cacheExpiration = Duration(days: 7);
  static const List<String> _allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/jpg',
  ];
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB

  bool get isInitialized => _isInitialized && _cloudinary != null && _dio != null;

  Future<void> initialize({
    required String cloudName,
    required String apiKey,
    required String apiSecret,
  }) async {
    if (isInitialized) {
      print('CloudinaryService déjà initialisé');
      print('- Cloud Name: $_cloudName');
      print('- API Key: ${_apiKey?.substring(0, 4)}...');
      return;
    }

    try {
      print('Initialisation de CloudinaryService...');
      print('- Cloud Name: $cloudName');
      print('- API Key: ${apiKey.substring(0, 4)}...');

      _cloudName = cloudName;
      _apiKey = apiKey;
      _apiSecret = apiSecret;

      print('Création de l\'instance CloudinaryPublic...');
      _cloudinary = CloudinaryPublic(
        cloudName,
        apiKey,
        cache: false,
      );

      print('Configuration de Dio...');
      _dio = Dio(BaseOptions(
        validateStatus: (status) => status! < 500,
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      print('Chargement du cache...');
      await _loadCache();

      _isInitialized = true;
      print('CloudinaryService initialisé avec succès');
      print('- Cloud Name: $_cloudName');
      print('- API Key: ${_apiKey?.substring(0, 4)}...');
    } catch (e) {
      print('Erreur lors de l\'initialisation de CloudinaryService: $e');
      print('Stack trace: ${StackTrace.current}');
      _isInitialized = false;
      _cloudinary = null;
      _dio = null;
      rethrow;
    }
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('profile_urls_cache');

      if (cacheData == null) {
        print('Aucune donnée de cache trouvée');
        return;
      }

      print('Chargement des données du cache...');
      final Map<String, dynamic> decoded = json.decode(cacheData);

      // Réinitialiser le cache
      _urlCache = {};

      // Vérifier si c'est l'ancien format
      if (decoded.isNotEmpty && decoded.values.first is String) {
        print('Migration des anciennes données du cache...');
        for (final entry in decoded.entries) {
          if (entry.value is String) {
            _urlCache[entry.key] = _CachedUrl(
              url: entry.value as String,
              timestamp: DateTime.now(),
            );
          }
        }
        print('Migration terminée: ${_urlCache.length} URLs migrées');

        // Sauvegarder dans le nouveau format
        await _saveCache();
      } else {
        print('Chargement du nouveau format de cache...');
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            final data = entry.value as Map<String, dynamic>;
            if (data.containsKey('url') && data.containsKey('timestamp')) {
              _urlCache[entry.key] = _CachedUrl(
                url: data['url'] as String,
                timestamp: DateTime.parse(data['timestamp'] as String),
              );
            }
          }
        }
        print('Chargement terminé: ${_urlCache.length} URLs chargées');
      }
    } catch (e) {
      print('Erreur lors du chargement du cache: $e');
      print('Stack trace: ${StackTrace.current}');
      // En cas d'erreur, on efface le cache
      await clearCache();
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = json.encode(_urlCache.map((key, value) => MapEntry(
        key,
        {
          'url': value.url,
          'timestamp': value.timestamp.toIso8601String(),
        },
      )));
      await prefs.setString('profile_urls_cache', cacheData);
      print('Cache sauvegardé: ${_urlCache.length} URLs');
    } catch (e) {
      print('Erreur lors de la sauvegarde du cache: $e');
      print('Stack trace: ${StackTrace.current}');
      // En cas d'erreur, on efface le cache
      await clearCache();
    }
  }

  Future<void> clearCache() async {
    try {
      _urlCache = {};
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_urls_cache');
      print('Cache effacé avec succès');
    } catch (e) {
      print('Erreur lors de l\'effacement du cache: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<String?> uploadProfileImage({
    required File imageFile,
    required String userId,
    bool isAdmin = false,
    bool forceRefresh = false,
  }) async {
    try {
      // Vérifier le cache
      final cacheKey = '${isAdmin ? 'admin' : 'user'}_$userId';
      if (!forceRefresh && _urlCache.containsKey(cacheKey)) {
        final cachedUrl = _urlCache[cacheKey]!;
        if (!cachedUrl.isExpired) {
          print('URL trouvée dans le cache pour $cacheKey');
          return cachedUrl.url;
        } else {
          print('URL en cache expirée pour $cacheKey');
          _urlCache.remove(cacheKey);
        }
      }

      // Valider le fichier
      if (!await _validateFile(imageFile)) {
        throw Exception('Fichier invalide');
      }

      String? profileUrl;
      int retryCount = 0;

      while (retryCount < _maxRetries) {
        try {
          profileUrl = await _uploadToCloudinary(
            imageFile: imageFile,
            userId: userId,
            isAdmin: isAdmin,
          );

          if (profileUrl != null) {
            break;
          }

          retryCount++;
          if (retryCount < _maxRetries) {
            print('Tentative $retryCount échouée, nouvelle tentative...');
            await Future.delayed(Duration(seconds: retryCount));
          }
        } catch (e) {
          print('Erreur lors de la tentative $retryCount: $e');
          retryCount++;
          if (retryCount < _maxRetries) {
            await Future.delayed(Duration(seconds: retryCount));
          }
        }
      }

      if (profileUrl != null) {
        _urlCache[cacheKey] = _CachedUrl(
          url: profileUrl,
          timestamp: DateTime.now(),
        );
        await _saveCache();
      }

      return profileUrl;
    } catch (e) {
      print('Erreur lors de l\'upload de la photo de profil: $e');
      return null;
    }
  }

  Future<String?> _uploadToCloudinary({
    required File imageFile,
    required String userId,
    required bool isAdmin,
  }) async {
    _checkInitialization();

    try {
      print('Début de l\'upload de la photo de profil vers Cloudinary...');
      print('Détails de l\'upload:');
      print('- User ID: $userId');
      print('- Type: ${isAdmin ? "Admin" : "User"}');
      print('- Taille du fichier: ${await imageFile.length()} bytes');
      print('- Cloud Name: $_cloudName');
      print('- API Key: ${_apiKey?.substring(0, 4)}...');

      final compressedFile = await _compressProfileImage(imageFile);
      print('Image compressée avec succès');
      print('- Taille après compression: ${await compressedFile.length()} bytes');

      final folder = isAdmin ? 'admin_profiles' : 'user_profiles';
      final publicId = userId;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = {
        'timestamp': timestamp.toString(),
        'folder': folder,
        'public_id': publicId,
        'type': 'upload',
        'transformation': 'c_fill,w_200,h_200,g_face',
      };

      final signature = _generateSignature(params);

      print('Configuration de l\'upload:');
      print('- Folder: $folder');
      print('- Public ID: $publicId');
      print('- Signature: $signature');
      print('- Type: upload');
      print('- String to sign: ${_getStringToSign(params)}');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(compressedFile.path),
        'api_key': _apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
        'folder': folder,
        'public_id': publicId,
        'type': 'upload',
        'transformation': 'c_fill,w_200,h_200,g_face',
      });

      print('Envoi de la requête à Cloudinary...');
      final response = await _dio!.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        data: formData,
        options: Options(
          validateStatus: (status) => status! < 500,
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('Réponse reçue:');
      print('- Status: ${response.statusCode}');
      print('- Data: ${response.data}');

      if (response.statusCode != 200) {
        print('Erreur Cloudinary: ${response.statusCode} - ${response.data}');
        return null;
      }

      print('Upload Cloudinary réussi: ${response.data['secure_url']}');
      await compressedFile.delete();
      return response.data['secure_url'];
    } catch (e) {
      print('Erreur Cloudinary: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  Future<File> _compressProfileImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_profile_compressed.jpg'
      );

      print('Compression de la photo de profil:');
      print('- Source: ${file.path}');
      print('- Destination: $targetPath');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 80,
        minWidth: 400,
        minHeight: 400,
      );

      if (result == null) {
        print('La compression a échoué, utilisation du fichier original');
        return file;
      }

      return File(result.path);
    } catch (e) {
      print('Erreur lors de la compression de la photo de profil: $e');
      return file;
    }
  }

  Future<bool> _validateFile(File file) async {
    try {
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        print('Fichier trop volumineux: ${fileSize} bytes');
        return false;
      }

      final mimeType = await _getMimeType(file);
      if (!_allowedMimeTypes.contains(mimeType)) {
        print('Type de fichier non autorisé: $mimeType');
        return false;
      }

      return true;
    } catch (e) {
      print('Erreur lors de la validation du fichier: $e');
      return false;
    }
  }

  Future<String> _getMimeType(File file) async {
    final extension = path.extension(file.path).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  String _getStringToSign(Map<String, String> params) {
    final sortedParams = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedParams
        .map((e) => '${e.key}=${e.value}')
        .join('&');
  }

  String _generateSignature(Map<String, String> params) {
    final stringToSign = _getStringToSign(params);
    print('String to sign: $stringToSign');

    final bytes = utf8.encode(stringToSign + _apiSecret!);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  Future<String?> uploadImage({
    required File imageFile,
    required String folder,
    String? publicId,
  }) async {
    _checkInitialization();

    try {
      print('Début de l\'upload vers Cloudinary...');
      print('Détails de l\'upload:');
      print('- Dossier: $folder');
      print('- Public ID: $publicId');
      print('- Taille du fichier: ${await imageFile.length()} bytes');

      // Valider le fichier
      if (!await _validateFile(imageFile)) {
        throw Exception('Fichier invalide');
      }

      // Compression de l'image
      final compressedFile = await _compressProductImage(imageFile);
      print('Image compressée avec succès');
      print('- Taille après compression: ${await compressedFile.length()} bytes');

      // Génération de la signature
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = {
        'timestamp': timestamp.toString(),
        'folder': folder,
        'type': 'upload',
      };
      if (publicId != null) {
        params['public_id'] = publicId;
      }

      final signature = _generateSignature(params);

      // Création du formulaire multipart
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(compressedFile.path),
        'api_key': _apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
        'folder': folder,
        'type': 'upload',
      });
      if (publicId != null) {
        formData.fields.add(MapEntry('public_id', publicId));
      }

      print('Configuration de l\'upload:');
      print('- Cloud Name: $_cloudName');
      print('- Signature: $signature');
      print('- Type: upload');
      print('- String to sign: ${_getStringToSign(params)}');

      final response = await _dio!.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        data: formData,
        options: Options(
          validateStatus: (status) => status! < 500,
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode != 200) {
        print('Erreur de réponse:');
        print('- Status: ${response.statusCode}');
        print('- Data: ${response.data}');
        throw Exception('Erreur lors de l\'upload: ${response.statusCode} - ${response.data}');
      }

      print('Upload vers Cloudinary réussi: ${response.data['secure_url']}');

      // Nettoyage du fichier temporaire
      await compressedFile.delete();

      return response.data['secure_url'];
    } on DioException catch (e) {
      print('Erreur Dio lors de l\'upload vers Cloudinary:');
      print('- Type: ${e.type}');
      print('- Message: ${e.message}');
      if (e.response != null) {
        print('- Status: ${e.response!.statusCode}');
        print('- Data: ${e.response!.data}');
      }
      return null;
    } catch (e) {
      print('Erreur lors de l\'upload vers Cloudinary: $e');
      return null;
    }
  }

  Future<File> _compressProductImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_product_compressed.jpg'
      );

      print('Compression de l\'image produit:');
      print('- Source: ${file.path}');
      print('- Destination: $targetPath');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) {
        print('La compression a échoué, utilisation du fichier original');
        return file;
      }

      return File(result.path);
    } catch (e) {
      print('Erreur lors de la compression de l\'image produit: $e');
      return file;
    }
  }

  Future<void> deleteImage(String publicId) async {
    _checkInitialization();

    try {
      print('Tentative de suppression de l\'image: $publicId');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
      };
      final signature = _generateSignature(params);

      final response = await _dio!.delete(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy',
        queryParameters: {
          'public_id': publicId,
          'api_key': _apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur lors de la suppression de l\'image: ${response.statusCode} - ${response.data}');
      }
      print('Image supprimée avec succès');
    } catch (e) {
      print('Erreur lors de la suppression de l\'image: $e');
      rethrow;
    }
  }

  void _checkInitialization() {
    if (!isInitialized) {
      throw Exception('CloudinaryService non initialisé. Appelez initialize() avant d\'utiliser le service.');
    }
  }
}

class _CachedUrl {
  final String url;
  final DateTime timestamp;

  _CachedUrl({
    required this.url,
    required this.timestamp,
  });

  bool get isExpired =>
    DateTime.now().difference(timestamp) > CloudinaryService._cacheExpiration;
}
