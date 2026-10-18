enum RingNameFamily { luckring, qring }

class RingNamePolicy {
  const RingNamePolicy._();

  // A name selects a candidate SDK only. Capabilities require its handshake.
  static RingNameFamily? familyForName(String name) {
    final normalized = name.trim().toUpperCase();
    if (const ['R7', 'K80', 'HR01', 'HR05'].any(normalized.contains)) {
      return RingNameFamily.luckring;
    }
    // R12 is a user-confirmed QRing candidate; do not match R120 or all R names.
    final isR12 =
        normalized == 'R12' ||
        normalized.startsWith('R12_') ||
        normalized.startsWith('R12-');
    if (isR12 ||
        const ['R8', 'R21', 'R22'].any(normalized.contains) ||
        normalized.startsWith('Q_') ||
        normalized.startsWith('O_') ||
        normalized.startsWith('R2')) {
      return RingNameFamily.qring;
    }
    return null;
  }
}
