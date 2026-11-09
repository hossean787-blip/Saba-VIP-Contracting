/// Select only from the verified list of contracts for the current company.
class ActiveContract {
  const ActiveContract._();

  static int? resolve(List<Map<String, Object?>> contracts, int? preferredId) {
    if (contracts.isEmpty) return null;
    if (preferredId != null &&
        contracts.any((contract) => contract['id'] == preferredId)) {
      return preferredId;
    }
    return contracts.first['id'] as int;
  }

  static Map<String, Object?>? find(
      List<Map<String, Object?>> contracts, int? contractId) {
    if (contractId == null) return null;
    for (final row in contracts) {
      if (row['id'] == contractId) return row;
    }
    return null;
  }
