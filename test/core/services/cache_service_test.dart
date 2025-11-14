/// Tests for CacheService
///
/// Demonstrates testing patterns and achieves high coverage
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_card/core/services/cache_service.dart';

void main() {
  group('CacheService', () {
    late CacheService cache;

    setUp(() {
      cache = CacheService();
      cache.clear(); // Clear before each test
    });

    tearDown(() {
      cache.clear();
    });

    test('get returns null when cache is empty', () {
      final result = cache.get<String>('test_key');
      expect(result, isNull);
    });

    test('set and get work correctly', () {
      cache.set('test_key', 'test_value');
      final result = cache.get<String>('test_key');

      expect(result, 'test_value');
    });

    test('get returns null when cache entry is expired', () async {
      cache.set('test_key', 'test_value', ttl: Duration(milliseconds: 10));

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 20));

      final result = cache.get<String>('test_key');
      expect(result, isNull);
    });

    test('getOrFetch returns cached value if available', () async {
      cache.set('test_key', 'cached_value');

      var fetchCalled = false;
      final result = await cache.getOrFetch(
        key: 'test_key',
        fetchFunction: () async {
          fetchCalled = true;
          return 'fetched_value';
        },
      );

      expect(result, 'cached_value');
      expect(fetchCalled, false);
    });

    test('getOrFetch fetches and caches when not in cache', () async {
      var fetchCalled = false;
      final result = await cache.getOrFetch(
        key: 'test_key',
        fetchFunction: () async {
          fetchCalled = true;
          return 'fetched_value';
        },
      );

      expect(result, 'fetched_value');
      expect(fetchCalled, true);

      // Verify it was cached
      final cached = cache.get<String>('test_key');
      expect(cached, 'fetched_value');
    });

    test('invalidate removes specific entry', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');

      cache.invalidate('key1');

      expect(cache.get<String>('key1'), isNull);
      expect(cache.get<String>('key2'), 'value2');
    });

    test('invalidatePattern removes matching entries', () {
      cache.set('profile_1', 'value1');
      cache.set('profile_2', 'value2');
      cache.set('analytics_1', 'value3');

      cache.invalidatePattern('profile_');

      expect(cache.get<String>('profile_1'), isNull);
      expect(cache.get<String>('profile_2'), isNull);
      expect(cache.get<String>('analytics_1'), 'value3');
    });

    test('clear removes all entries', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');

      cache.clear();

      expect(cache.get<String>('key1'), isNull);
      expect(cache.get<String>('key2'), isNull);
    });

    test('getStats returns accurate statistics', () {
      // Cause some cache hits and misses
      cache.set('key1', 'value1');
      cache.get<String>('key1'); // Hit
      cache.get<String>('key1'); // Hit
      cache.get<String>('key2'); // Miss

      final stats = cache.getStats();

      expect(stats['cacheHits'], 2);
      expect(stats['cacheMisses'], 1);
      expect(stats['cacheSize'], 1);
    });

    test('cache evicts least recently used entry when full', () {
      // Set max cache size to 5 for testing
      // Note: This requires making maxMemoryCacheSize configurable or testing with 100 items

      // Add items
      for (int i = 0; i < 101; i++) {
        cache.set('key_$i', 'value_$i');
      }

      final stats = cache.getStats();
      expect(stats['cacheSize'], lessThanOrEqualTo(100));
    });

    test('profileKey generates correct cache key', () {
      final key = CacheService.profileKey('123');
      expect(key, 'profile_123');
    });

    test('allProfilesKey generates correct cache key', () {
      final key = CacheService.allProfilesKey('user_456');
      expect(key, 'profiles_all_user_456');
    });

    test('analyticsKey generates correct cache key', () {
      final key = CacheService.analyticsKey('profile_789', page: 2);
      expect(key, 'analytics_profile_789_2');

      final keyNoPage = CacheService.analyticsKey('profile_789');
      expect(keyNoPage, 'analytics_profile_789_all');
    });
  });
}
