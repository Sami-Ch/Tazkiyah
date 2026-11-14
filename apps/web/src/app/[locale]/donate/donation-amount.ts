const presets = [500, 1_000, 2_500, 5_000, 10_000] as const;

export const donationPresets = presets;

// Whole rupees, from Rs 1 to the donation ledger's upper bound.
export function parseDonationRupees(value: string) {
  const rupees = value.replaceAll(",", "").trim();
  if (!/^[1-9][0-9]{0,11}$/.test(rupees)) return null;
  const paisa = BigInt(rupees) * 100n;
  return paisa <= 9_999_999_999_9900n ? paisa : null;
}
