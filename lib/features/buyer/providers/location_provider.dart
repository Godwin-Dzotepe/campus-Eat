import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/address_model.dart';

final selectedAddressProvider = StateProvider<AddressModel?>((ref) => null);

final deliveryTypeProvider = StateProvider<String>((ref) => 'pickup');
