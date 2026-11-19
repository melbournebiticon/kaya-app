import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:material_ui/material_ui.dart';

/// Loading status for Life Vault queries.
enum LifeVaultLoadStatus { idle, loading, loaded, error }

/// Application state controller for Phase 6 Life Vault (Documents & Belongings).
class LifeVaultController extends ChangeNotifier {
  LifeVaultController({
    required this.repository,
    DateTime Function()? clock,
    String? initialUserId,
  }) : _clock = clock ?? DateTime.now,
       _activeUserId = initialUserId;

  final LifeVaultRepository repository;
  final DateTime Function() _clock;

  String? _activeUserId;
  int _userEpoch = 0;

  LifeVaultLoadStatus _loadStatus = LifeVaultLoadStatus.idle;
  bool _isMutating = false;
  String? _errorMessage;

  final List<VaultDocument> _documents = <VaultDocument>[];
  final List<BelongingItem> _belongings = <BelongingItem>[];

  DocumentFilterView _docFilter = DocumentFilterView.all;
  DocumentCategory? _docCategoryFilter;
  String _docSearchQuery = '';

  BelongingFilterView _belongingFilter = BelongingFilterView.all;
  BelongingCategory? _belongingCategoryFilter;
  String _belongingSearchQuery = '';

  String? get activeUserId => _activeUserId;
  LifeVaultLoadStatus get loadStatus => _loadStatus;
  bool get isLoading => _loadStatus == LifeVaultLoadStatus.loading;
  bool get hasLoadError => _loadStatus == LifeVaultLoadStatus.error;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;

  DocumentFilterView get docFilter => _docFilter;
  DocumentCategory? get docCategoryFilter => _docCategoryFilter;
  String get docSearchQuery => _docSearchQuery;

  BelongingFilterView get belongingFilter => _belongingFilter;
  BelongingCategory? get belongingCategoryFilter => _belongingCategoryFilter;
  String get belongingSearchQuery => _belongingSearchQuery;

  KayaDateOnly get referenceToday => KayaDateOnly.fromDateTime(_clock());

  List<VaultDocument> get allDocuments {
    final List<VaultDocument> copy = List<VaultDocument>.from(_documents);
    copy.sort(
      (VaultDocument a, VaultDocument b) =>
          VaultDocument.compareByUrgency(a, b, referenceToday),
    );
    return List<VaultDocument>.unmodifiable(copy);
  }

  List<VaultDocument> get expiredDocuments => allDocuments
      .where((VaultDocument d) => d.isExpired(referenceToday))
      .toList(growable: false);

  List<VaultDocument> get expiringSoonDocuments => allDocuments
      .where((VaultDocument d) => d.isExpiringSoon(referenceToday))
      .toList(growable: false);

  /// Documents that are either expired or expiring within 30 days.
  List<VaultDocument> get attentionDocuments => allDocuments
      .where((VaultDocument d) => d.needsAttention(referenceToday))
      .toList(growable: false);

  List<VaultDocument> get filteredDocuments {
    final KayaDateOnly today = referenceToday;
    final String q = _docSearchQuery.trim().toLowerCase();

    return allDocuments
        .where((VaultDocument d) {
          final DocumentExpirationStatus status = d.expirationStatus(today);
          final bool matchesView = switch (_docFilter) {
            DocumentFilterView.all => true,
            DocumentFilterView.expiringSoon =>
              status == DocumentExpirationStatus.expiringSoon,
            DocumentFilterView.expired =>
              status == DocumentExpirationStatus.expired,
            DocumentFilterView.valid =>
              status == DocumentExpirationStatus.valid ||
                  status == DocumentExpirationStatus.noExpiration,
          };
          if (!matchesView) {
            return false;
          }
          if (_docCategoryFilter != null && d.category != _docCategoryFilter) {
            return false;
          }
          if (q.isNotEmpty) {
            final bool hit =
                d.title.toLowerCase().contains(q) ||
                d.physicalLocation.toLowerCase().contains(q) ||
                d.notes.toLowerCase().contains(q) ||
                d.category.label.toLowerCase().contains(q);
            if (!hit) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  List<BelongingItem> get allBelongings {
    final List<BelongingItem> copy = List<BelongingItem>.from(_belongings);
    copy.sort(
      (BelongingItem a, BelongingItem b) =>
          BelongingItem.compareByPriority(a, b, referenceToday),
    );
    return List<BelongingItem>.unmodifiable(copy);
  }

  List<BelongingItem> get activeLoans => allBelongings
      .where((BelongingItem b) => b.isActiveLoan)
      .toList(growable: false);

  List<BelongingItem> get filteredBelongings {
    final String q = _belongingSearchQuery.trim().toLowerCase();

    return allBelongings
        .where((BelongingItem b) {
          final bool matchesView = switch (_belongingFilter) {
            BelongingFilterView.all => true,
            BelongingFilterView.owned =>
              b.custodyType == BelongingCustodyType.owned,
            BelongingFilterView.lentOut =>
              b.custodyType == BelongingCustodyType.lentOut && !b.isReturned,
            BelongingFilterView.borrowed =>
              b.custodyType == BelongingCustodyType.borrowed && !b.isReturned,
            BelongingFilterView.returned => b.isLoanItem && b.isReturned,
          };
          if (!matchesView) {
            return false;
          }
          if (_belongingCategoryFilter != null &&
              b.category != _belongingCategoryFilter) {
            return false;
          }
          if (q.isNotEmpty) {
            final bool hit =
                b.title.toLowerCase().contains(q) ||
                b.storageLocation.toLowerCase().contains(q) ||
                b.counterpartyName.toLowerCase().contains(q) ||
                b.notes.toLowerCase().contains(q) ||
                b.category.label.toLowerCase().contains(q);
            if (!hit) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> bindAuthenticatedUser(String? userId) async {
    final String? normalized = (userId?.trim().isEmpty ?? true)
        ? null
        : userId!.trim();
    if (_activeUserId == normalized &&
        _loadStatus != LifeVaultLoadStatus.idle) {
      return;
    }

    _userEpoch++;
    _activeUserId = normalized;
    _clearPrivateCaches();

    if (normalized == null) {
      _loadStatus = LifeVaultLoadStatus.idle;
      notifyListeners();
      return;
    }

    await loadVault();
  }

  void setDocFilter(DocumentFilterView view) {
    if (_docFilter != view) {
      _docFilter = view;
      notifyListeners();
    }
  }

  void setDocCategoryFilter(DocumentCategory? category) {
    if (_docCategoryFilter != category) {
      _docCategoryFilter = category;
      notifyListeners();
    }
  }

  void setDocSearchQuery(String query) {
    if (_docSearchQuery != query) {
      _docSearchQuery = query;
      notifyListeners();
    }
  }

  void clearDocFilters() {
    _docFilter = DocumentFilterView.all;
    _docCategoryFilter = null;
    _docSearchQuery = '';
    notifyListeners();
  }

  void setBelongingFilter(BelongingFilterView view) {
    if (_belongingFilter != view) {
      _belongingFilter = view;
      notifyListeners();
    }
  }

  void setBelongingCategoryFilter(BelongingCategory? category) {
    if (_belongingCategoryFilter != category) {
      _belongingCategoryFilter = category;
      notifyListeners();
    }
  }

  void setBelongingSearchQuery(String query) {
    if (_belongingSearchQuery != query) {
      _belongingSearchQuery = query;
      notifyListeners();
    }
  }

  void clearBelongingFilters() {
    _belongingFilter = BelongingFilterView.all;
    _belongingCategoryFilter = null;
    _belongingSearchQuery = '';
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> loadVault() async {
    final String? uid = _activeUserId;
    if (uid == null) {
      _clearPrivateCaches();
      _loadStatus = LifeVaultLoadStatus.idle;
      notifyListeners();
      return;
    }

    final int requestEpoch = ++_userEpoch;
    _loadStatus = LifeVaultLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<VaultDocument> docs = await repository.fetchDocuments(
        authenticatedUserId: uid,
      );
      final List<BelongingItem> items = await repository.fetchBelongings(
        authenticatedUserId: uid,
      );
      if (requestEpoch != _userEpoch) {
        return;
      }
      _documents
        ..clear()
        ..addAll(docs);
      _belongings
        ..clear()
        ..addAll(items);
      _loadStatus = LifeVaultLoadStatus.loaded;
    } on AuthFailure catch (failure) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = failure.message;
      _loadStatus = LifeVaultLoadStatus.error;
    } catch (_) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = 'Unable to load Life Vault records. Please check your connection and try again.';
      _loadStatus = LifeVaultLoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> createDocument({
    required String title,
    required DocumentCategory category,
    required String physicalLocation,
    String notes = '',
    KayaDateOnly? issueDate,
    KayaDateOnly? expirationDate,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final VaultDocument created = await repository.createDocument(
        authenticatedUserId: uid,
        title: title,
        category: category,
        physicalLocation: physicalLocation,
        notes: notes,
        issueDate: issueDate,
        expirationDate: expirationDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _documents.add(created);
      _loadStatus = LifeVaultLoadStatus.loaded;
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to save document. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateDocument({
    required String documentId,
    required String title,
    required DocumentCategory category,
    required String physicalLocation,
    required String notes,
    required KayaDateOnly? issueDate,
    required KayaDateOnly? expirationDate,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final VaultDocument updated = await repository.updateDocument(
        authenticatedUserId: uid,
        documentId: documentId,
        title: title,
        category: category,
        physicalLocation: physicalLocation,
        notes: notes,
        issueDate: issueDate,
        expirationDate: expirationDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _documents.indexWhere(
        (VaultDocument d) => d.id == documentId,
      );
      if (idx != -1) {
        _documents[idx] = updated;
      }
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to update document. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteDocument(
        authenticatedUserId: uid,
        documentId: documentId,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _documents.removeWhere((VaultDocument d) => d.id == documentId);
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to delete document. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> createBelonging({
    required String title,
    required BelongingCategory category,
    required String storageLocation,
    String notes = '',
    required BelongingCustodyType custodyType,
    String counterpartyName = '',
    KayaDateOnly? dueReturnDate,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final BelongingItem created = await repository.createBelonging(
        authenticatedUserId: uid,
        title: title,
        category: category,
        storageLocation: storageLocation,
        notes: notes,
        custodyType: custodyType,
        counterpartyName: counterpartyName,
        dueReturnDate: dueReturnDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _belongings.add(created);
      _loadStatus = LifeVaultLoadStatus.loaded;
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to save belonging. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateBelonging({
    required String belongingId,
    required String title,
    required BelongingCategory category,
    required String storageLocation,
    required String notes,
    required BelongingCustodyType custodyType,
    required String counterpartyName,
    required KayaDateOnly? dueReturnDate,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final BelongingItem updated = await repository.updateBelonging(
        authenticatedUserId: uid,
        belongingId: belongingId,
        title: title,
        category: category,
        storageLocation: storageLocation,
        notes: notes,
        custodyType: custodyType,
        counterpartyName: counterpartyName,
        dueReturnDate: dueReturnDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _belongings.indexWhere(
        (BelongingItem b) => b.id == belongingId,
      );
      if (idx != -1) {
        _belongings[idx] = updated;
      }
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to update belonging. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> setBelongingReturned({
    required String belongingId,
    required bool isReturned,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final BelongingItem updated = await repository.setBelongingReturned(
        authenticatedUserId: uid,
        belongingId: belongingId,
        isReturned: isReturned,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _belongings.indexWhere(
        (BelongingItem b) => b.id == belongingId,
      );
      if (idx != -1) {
        _belongings[idx] = updated;
      }
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to update return status. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteBelonging(String belongingId) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteBelonging(
        authenticatedUserId: uid,
        belongingId: belongingId,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _belongings.removeWhere((BelongingItem b) => b.id == belongingId);
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to delete belonging. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  void _clearPrivateCaches() {
    _documents.clear();
    _belongings.clear();
    _docFilter = DocumentFilterView.all;
    _docCategoryFilter = null;
    _docSearchQuery = '';
    _belongingFilter = BelongingFilterView.all;
    _belongingCategoryFilter = null;
    _belongingSearchQuery = '';
    _errorMessage = null;
    _isMutating = false;
  }
}
