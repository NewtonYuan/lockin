import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService extends ChangeNotifier {
  static const subscriptionProductId = 'tempus_premium';
  static const monthlyBasePlanId = 'monthly';
  static const yearlyBasePlanId = 'yearly';
  static const freeTrialOfferId = '3-day-free-trial';
  static const _cachedPremiumKey = 'premium_cached_active_v1';
  static const _cachedProductIdKey = 'premium_cached_product_id_v1';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isInitialized = false;
  bool _isStoreAvailable = false;
  bool _isLoadingProducts = false;
  bool _isCheckingStatus = false;
  bool _isPurchasePending = false;
  bool _isPremium = false;
  String? _activeProductId;
  String? _pendingOfferToken;
  String? _errorMessage;
  String? _lastStoreMessage;
  List<ProductDetails> _products = const [];
  Set<String> _notFoundProductIds = const {};

  static const productIds = {
    subscriptionProductId,
  };

  bool get isStoreAvailable => _isStoreAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isCheckingStatus => _isCheckingStatus;
  bool get isPurchasePending => _isPurchasePending;
  bool get isPremium => _isPremium;
  String? get activeProductId => _activeProductId;
  String? get errorMessage => _errorMessage;
  String? get lastStoreMessage => _lastStoreMessage;
  List<ProductDetails> get products => _products;
  Set<String> get notFoundProductIds => _notFoundProductIds;

  bool isPurchasePendingFor(ProductDetails productDetails) {
    if (!_isPurchasePending) {
      return false;
    }
    if (productDetails is! GooglePlayProductDetails) {
      return false;
    }
    return productDetails.offerToken == _pendingOfferToken;
  }

  String get statusLabel {
    if (_isCheckingStatus && !_isPremium) {
      return 'Checking';
    }
    return _isPremium ? 'Premium' : 'Free';
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {
        _isPurchasePending = false;
        _pendingOfferToken = null;
        _errorMessage = 'Unable to process purchase updates.';
        notifyListeners();
      },
    );
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_cachedPremiumKey) ?? false;
    _activeProductId = prefs.getString(_cachedProductIdKey);
    _isStoreAvailable = await _inAppPurchase.isAvailable();
    _isInitialized = true;
    notifyListeners();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    await initialize();
    if (!_isStoreAvailable) return;

    _isCheckingStatus = true;
    _errorMessage = null;
    _lastStoreMessage = null;
    notifyListeners();

    try {
      final purchases = await _queryCurrentPurchases();
      final activePurchase = purchases
          .where((purchase) => purchase.productID == subscriptionProductId)
          .cast<PurchaseDetails?>()
          .firstWhere((purchase) => purchase != null, orElse: () => null);

      _isPremium = activePurchase != null;
      _activeProductId = activePurchase?.productID;
      await _persistPremiumCache();
    } catch (_) {
      _errorMessage = 'Unable to verify premium status.';
    } finally {
      _isCheckingStatus = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts() async {
    await initialize();
    if (!_isStoreAvailable || _isLoadingProducts) return;

    _isLoadingProducts = true;
    _errorMessage = null;
    _lastStoreMessage = null;
    notifyListeners();

    try {
      final response = await _inAppPurchase.queryProductDetails(productIds);
      _notFoundProductIds = response.notFoundIDs.toSet();
      _products = response.productDetails
          .whereType<GooglePlayProductDetails>()
          .where((product) => product.id == subscriptionProductId)
          .where((product) => _basePlanIdForProduct(product) != null)
          .toList()
        ..sort((a, b) {
          final aRank = _basePlanSortRank(_basePlanIdForProduct(a));
          final bRank = _basePlanSortRank(_basePlanIdForProduct(b));
          return aRank.compareTo(bRank);
        });
      if (response.error != null) {
        _errorMessage = response.error!.message;
        _lastStoreMessage = response.error!.source;
      } else if (_products.isEmpty) {
        _errorMessage = 'No premium products found.';
        if (_notFoundProductIds.isNotEmpty) {
          _lastStoreMessage =
              'Missing product IDs: ${_notFoundProductIds.join(', ')}';
        }
      }
    } catch (_) {
      _errorMessage = 'Unable to load premium plans.';
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails productDetails) async {
    await initialize();
    if (!_isStoreAvailable) return;

    _isPurchasePending = true;
    _pendingOfferToken = null;
    _errorMessage = null;
    _lastStoreMessage = null;

    final PurchaseParam purchaseParam;
    if (Platform.isAndroid) {
      final googleProduct = productDetails as GooglePlayProductDetails;
      _pendingOfferToken = googleProduct.offerToken;
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
        offerToken: googleProduct.offerToken,
      );
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }
    notifyListeners();

    final started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    if (!started) {
      _isPurchasePending = false;
      _pendingOfferToken = null;
      _errorMessage = 'Unable to start purchase.';
      notifyListeners();
    }
  }

  Future<void> buyFreeTrial() async {
    await initialize();
    final trialProduct = _products.cast<ProductDetails?>().firstWhere(
      (product) => _offerIdForProduct(product) == freeTrialOfferId,
      orElse: () => null,
    );
    if (trialProduct == null) {
      _pendingOfferToken = null;
      _errorMessage = 'Free trial is unavailable right now.';
      notifyListeners();
      return;
    }
    await buy(trialProduct);
  }

  Future<void> restorePurchases() async {
    await initialize();
    if (!_isStoreAvailable) return;

    _isPurchasePending = true;
    _pendingOfferToken = null;
    _errorMessage = null;
    _lastStoreMessage = null;
    notifyListeners();

    try {
      await _inAppPurchase.restorePurchases();
      await refreshStatus();
    } catch (_) {
      _errorMessage = 'Unable to restore purchases.';
    } finally {
      _isPurchasePending = false;
      _pendingOfferToken = null;
      notifyListeners();
    }
  }

  String labelForProduct(ProductDetails productDetails) {
    switch (_basePlanIdForProduct(productDetails)) {
      case yearlyBasePlanId:
        return '1 YEAR';
      case monthlyBasePlanId:
        return '1 MONTH';
      default:
        return productDetails.title;
    }
  }

  Future<List<PurchaseDetails>> _queryCurrentPurchases() async {
    if (Platform.isAndroid) {
      final addition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) {
        throw Exception(response.error!.message);
      }
      _lastStoreMessage =
          'Past purchases found: ${response.pastPurchases.length}';
      return response.pastPurchases;
    }
    return const <PurchaseDetails>[];
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    var shouldRefreshStatus = false;

    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isPurchasePending = true;
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        _isPurchasePending = false;
        _pendingOfferToken = null;
        _errorMessage =
            purchaseDetails.error?.message ?? 'Purchase failed.';
      }

      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.productID == subscriptionProductId) {
          _isPremium = true;
          _activeProductId = purchaseDetails.productID;
          shouldRefreshStatus = true;
          await _persistPremiumCache();
        }
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }

    _isPurchasePending = false;
    _pendingOfferToken = null;
    notifyListeners();

    if (shouldRefreshStatus) {
      await refreshStatus();
    }
  }

  Future<void> _persistPremiumCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cachedPremiumKey, _isPremium);
    if (_activeProductId == null) {
      await prefs.remove(_cachedProductIdKey);
    } else {
      await prefs.setString(_cachedProductIdKey, _activeProductId!);
    }
  }

  int _basePlanSortRank(String? basePlanId) {
    switch (basePlanId) {
      case monthlyBasePlanId:
        return 0;
      case yearlyBasePlanId:
        return 1;
      default:
        return 99;
    }
  }

  String? _basePlanIdForProduct(ProductDetails productDetails) {
    if (productDetails is! GooglePlayProductDetails) return null;
    final index = productDetails.subscriptionIndex;
    final offers = productDetails.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return null;
    return offers[index].basePlanId;
  }

  String? _offerIdForProduct(ProductDetails? productDetails) {
    if (productDetails is! GooglePlayProductDetails) return null;
    final index = productDetails.subscriptionIndex;
    final offers = productDetails.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return null;
    return offers[index].offerId;
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
