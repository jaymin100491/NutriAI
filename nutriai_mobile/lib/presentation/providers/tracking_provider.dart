import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/tracking_model.dart';
import '../../data/repositories/tracking_repository.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return TrackingRepository(dioClient);
});

final trackingDataProvider = FutureProvider<List<DailyTracking>>((ref) async {
  final repository = ref.watch(trackingRepositoryProvider);
  try {
    return await repository.getDailyTracking(days: 1500);
  } catch (e) {
    return [];
  }
});

final progressDataProvider = FutureProvider<ProgressData?>((ref) async {
  final repository = ref.watch(trackingRepositoryProvider);
  try {
    return await repository.getProgress(days: 1500);
  } catch (e) {
    return null;
  }
});

class TrackingState {
  final List<DailyTracking> trackingData;
  final bool isLoading;
  final String? error;

  TrackingState({
    this.trackingData = const [],
    this.isLoading = false,
    this.error,
  });

  TrackingState copyWith({
    List<DailyTracking>? trackingData,
    bool? isLoading,
    String? error,
  }) {
    return TrackingState(
      trackingData: trackingData ?? this.trackingData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  final TrackingRepository _repository;

  TrackingNotifier(this._repository) : super(TrackingState());

  Future<void> loadTrackingData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repository.getDailyTracking(days: 1500);
      state = state.copyWith(trackingData: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load tracking data', isLoading: false);
    }
  }

  Future<void> submitTracking(DailyTracking tracking) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.submitTracking(tracking);
      await loadTrackingData();
    } catch (e) {
      state = state.copyWith(error: 'Failed to submit tracking', isLoading: false);
    }
  }
}

final trackingNotifierProvider = StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  final repository = ref.watch(trackingRepositoryProvider);
  return TrackingNotifier(repository);
});
