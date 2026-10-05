export type ListingIntent = "sale" | "rent";

export type PropertyListing = {
  id: string;
  title: string;
  area: string;
  intent: ListingIntent;
  propertyType: "apartment" | "townhouse" | "house";
  priceJmd: number;
  bedrooms: number;
  bathrooms: number;
  parkingSpaces: number;
  floor?: number;
  balcony: boolean;
  furnished: boolean;
  modernInterior: boolean;
  sizeSqFt: number;
};

export type PreferenceProfile = {
  maxPriceJmd?: number;
  minBedrooms?: number;
  minParkingSpaces?: number;
  preferredAreas: string[];
  preferredFeatures: string[];
  avoidedFeatures: string[];
};

export type MatchReason = {
  label: string;
  matched: boolean;
  weight: number;
};

export type ListingMatch = {
  listing: PropertyListing;
  score: number;
  reasons: MatchReason[];
};
