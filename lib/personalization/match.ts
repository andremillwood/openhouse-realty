import type {
  ListingMatch,
  MatchReason,
  PreferenceProfile,
  PropertyListing,
} from "@/types/marketplace";

export function matchesHardRequirements(
  listing: PropertyListing,
  profile: PreferenceProfile,
) {
  if (profile.maxPriceJmd && listing.priceJmd > profile.maxPriceJmd) return false;
  if (profile.minBedrooms && listing.bedrooms < profile.minBedrooms) return false;
  if (
    profile.minParkingSpaces &&
    listing.parkingSpaces < profile.minParkingSpaces
  ) {
    return false;
  }

  return true;
}

export function scoreListing(
  listing: PropertyListing,
  profile: PreferenceProfile,
): ListingMatch {
  const reasons: MatchReason[] = [];
  const add = (label: string, matched: boolean, weight: number) =>
    reasons.push({ label, matched, weight });

  add(
    `Within JMD ${profile.maxPriceJmd?.toLocaleString() ?? "your"} budget`,
    !profile.maxPriceJmd || listing.priceJmd <= profile.maxPriceJmd,
    30,
  );
  add(
    `${profile.minBedrooms ?? 0}+ bedrooms`,
    !profile.minBedrooms || listing.bedrooms >= profile.minBedrooms,
    20,
  );
  add(
    `${profile.minParkingSpaces ?? 0}+ parking spaces`,
    !profile.minParkingSpaces ||
      listing.parkingSpaces >= profile.minParkingSpaces,
    15,
  );
  add(
    `Preferred area: ${listing.area}`,
    profile.preferredAreas.length === 0 ||
      profile.preferredAreas.includes(listing.area),
    15,
  );

  const features: Record<string, boolean> = {
    balcony: listing.balcony,
    "high floor": (listing.floor ?? 0) >= 5,
    furnished: listing.furnished,
    "modern interior": listing.modernInterior,
  };

  for (const feature of profile.preferredFeatures) {
    add(feature, Boolean(features[feature]), 5);
  }

  const possible = reasons.reduce((sum, reason) => sum + reason.weight, 0);
  const earned = reasons
    .filter((reason) => reason.matched)
    .reduce((sum, reason) => sum + reason.weight, 0);

  return {
    listing,
    score: possible === 0 ? 0 : Math.round((earned / possible) * 100),
    reasons,
  };
}

export function rankListings(
  listings: PropertyListing[],
  profile: PreferenceProfile,
) {
  return listings
    .filter((listing) => matchesHardRequirements(listing, profile))
    .map((listing) => scoreListing(listing, profile))
    .sort((a, b) => b.score - a.score);
}
