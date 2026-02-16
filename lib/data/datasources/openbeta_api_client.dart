import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/crag_model.dart';
import '../../core/config.dart';
import '../../domain/entities/aspect.dart';
import '../../domain/entities/rock_type.dart';
import '../../domain/entities/climbing_type.dart';
import '../../domain/entities/crag_source.dart';

class OpenBetaApiClient {
  final http.Client _client;

  OpenBetaApiClient({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<CragModel>> fetchCragsByRegion({
    String? country,
    String? region,
  }) async {
    final query = _buildGraphQLQuery(country: country, region: region);

    try {
      final response = await _client.post(
        Uri.parse(AppConfig.openBetaApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'query': query,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return _parseCragsResponse(jsonData);
      } else {
        throw Exception(
          'Failed to fetch crags: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching crags from OpenBeta: $e');
    }
  }

  String _buildGraphQLQuery({String? country, String? region}) {
    // Build GraphQL query to fetch areas/crags
    // This is a simplified query - adjust based on actual OpenBeta schema
    return '''
      query GetCrags {
        areas(filter: {countries: ${country != null ? '["$country"]' : 'null'}}) {
          area_name
          metadata {
            lat
            lng
          }
          children {
            area_name
            metadata {
              lat
              lng
            }
          }
        }
      }
    ''';
  }

  List<CragModel> _parseCragsResponse(Map<String, dynamic> json) {
    final crags = <CragModel>[];
    
    if (json['data'] != null && json['data']['areas'] != null) {
      final areas = json['data']['areas'] as List<dynamic>;
      
      for (final area in areas) {
        final areaMap = area as Map<String, dynamic>;
        final metadata = areaMap['metadata'] as Map<String, dynamic>?;
        
        if (metadata != null && 
            metadata['lat'] != null && 
            metadata['lng'] != null) {
          // Create crag from area
          final crag = CragModel(
            id: areaMap['area_name'] ?? 'unknown',
            name: areaMap['area_name'] ?? 'Unknown Crag',
            latitude: (metadata['lat'] as num).toDouble(),
            longitude: (metadata['lng'] as num).toDouble(),
            aspectString: Aspect.unknown.name,
            rockTypeString: RockType.limestone.name, // Default, should be inferred or fetched
            climbingTypesString: [ClimbingType.sport.name], // Default
            sourceString: CragSource.fetched.name,
          );
          crags.add(crag);
        }
        
        // Process children (sub-areas/crags)
        if (areaMap['children'] != null) {
          final children = areaMap['children'] as List<dynamic>;
          for (final child in children) {
            final childMap = child as Map<String, dynamic>;
            final childMetadata = childMap['metadata'] as Map<String, dynamic>?;
            
            if (childMetadata != null && 
                childMetadata['lat'] != null && 
                childMetadata['lng'] != null) {
              final childCrag = CragModel(
                id: childMap['area_name'] ?? 'unknown',
                name: childMap['area_name'] ?? 'Unknown Crag',
                latitude: (childMetadata['lat'] as num).toDouble(),
                longitude: (childMetadata['lng'] as num).toDouble(),
                aspectString: Aspect.unknown.name,
                rockTypeString: RockType.limestone.name,
                climbingTypesString: [ClimbingType.sport.name],
                sourceString: CragSource.fetched.name,
              );
              crags.add(childCrag);
            }
          }
        }
      }
    }
    
    return crags;
  }
}
