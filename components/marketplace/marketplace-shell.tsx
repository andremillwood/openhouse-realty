"use client";

import { useMemo, useState } from "react";
import { rankListings } from "@/lib/personalization/match";
import type { PreferenceProfile, PropertyListing } from "@/types/marketplace";

const listings: PropertyListing[] = [
  {
    id: "residence-8c",
    title: "Residence 8C",
    area: "Kingston 6",
    intent: "rent",
    propertyType: "apartment",
    priceJmd: 295000,
    bedrooms: 2,
    bathrooms: 2,
    parkingSpaces: 1,
    floor: 8,
    balcony: true,
    furnished: false,
    modernInterior: true,
    sizeSqFt: 1310,
  },
  {
    id: "residence-6a",
    title: "Residence 6A",
    area: "Kingston 6",
    intent: "rent",
    propertyType: "apartment",
    priceJmd: 285000,
    bedrooms: 2,
    bathrooms: 2.5,
    parkingSpaces: 2,
    floor: 6,
    balcony: false,
    furnished: false,
    modernInterior: true,
    sizeSqFt: 1420,
  },
  {
    id: "norbrook-12",
    title: "Norbrook Residence",
    area: "Norbrook",
    intent: "rent",
    propertyType: "apartment",
    priceJmd: 315000,
    bedrooms: 2,
    bathrooms: 2,
    parkingSpaces: 2,
    floor: 3,
    balcony: true,
    furnished: true,
    modernInterior: false,
    sizeSqFt: 1480,
  },
];

const initialProfile: PreferenceProfile = {
  maxPriceJmd: 320000,
  minBedrooms: 2,
  minParkingSpaces: 1,
  preferredAreas: ["Kingston 6"],
  preferredFeatures: ["balcony", "high floor", "modern interior"],
  avoidedFeatures: ["ground floor"],
};

export function MarketplaceShell() {
  const [mode, setMode] = useState<"for-you" | "search">("for-you");
  const [profile, setProfile] = useState(initialProfile);
  const [saved, setSaved] = useState<string[]>([]);
  const [hidden, setHidden] = useState<string[]>([]);

  const matches = useMemo(
    () =>
      rankListings(
        listings.filter((listing) => !hidden.includes(listing.id)),
        profile,
      ),
    [hidden, profile],
  );

  return (
    <main>
      <header className="site-header">
        <a className="brand" href="#">OpenHouse</a>
        <nav aria-label="Main navigation">
          <a href="#homes">Buy</a>
          <a href="#homes">Rent</a>
          <a href="#sell">Sell</a>
          <a href="#manage">Property Management</a>
        </nav>
        <button className="text-button">Sign in</button>
      </header>

      <section className="hero">
        <p className="eyebrow">REAL ESTATE · JAMAICA</p>
        <h1>Find what fits your life, not just your filters.</h1>
        <p className="hero-copy">
          Search the market yourself, or tell OpenHouse what matters and let
          your property feed become more useful over time.
        </p>
        <div className="search-box">
          <input
            aria-label="Property search"
            placeholder="Try: 2 bedrooms in Kingston 6 under JMD 320K with parking"
          />
          <button>Search</button>
        </div>
      </section>

      <section className="marketplace" id="homes">
        <div className="section-heading">
          <div>
            <p className="eyebrow">DISCOVERY</p>
            <h2>{mode === "for-you" ? "For You" : "Search"}</h2>
          </div>
          <div className="segmented" aria-label="Discovery mode">
            <button
              className={mode === "for-you" ? "active" : ""}
              onClick={() => setMode("for-you")}
            >
              For You
            </button>
            <button
              className={mode === "search" ? "active" : ""}
              onClick={() => setMode("search")}
            >
              Search
            </button>
          </div>
        </div>

        {mode === "for-you" && (
          <aside className="preference-panel">
            <div>
              <p className="eyebrow">YOUR PREFERENCES</p>
              <strong>Must have</strong>
              <p>2+ bedrooms · parking · up to JMD 320,000</p>
            </div>
            <div>
              <strong>Prefer</strong>
              <p>Kingston 6 · balcony · high floor · modern interior</p>
            </div>
            <div>
              <strong>We noticed</strong>
              <p>You seem to prefer higher-floor apartments.</p>
              <button
                className="text-button"
                onClick={() =>
                  setProfile((current) => ({
                    ...current,
                    preferredFeatures: current.preferredFeatures.includes("high floor")
                      ? current.preferredFeatures.filter(
                          (feature) => feature !== "high floor",
                        )
                      : [...current.preferredFeatures, "high floor"],
                  }))
                }
              >
                {profile.preferredFeatures.includes("high floor")
                  ? "Remove preference"
                  : "Use this preference"}
              </button>
            </div>
          </aside>
        )}

        <div className="listing-grid">
          {matches.map(({ listing, score, reasons }) => (
            <article className="listing-card" key={listing.id}>
              <div className="listing-image">
                {mode === "for-you" && (
                  <span className="match-badge">{score}% match</span>
                )}
              </div>
              <div className="listing-content">
                <p className="eyebrow">{listing.area}</p>
                <h3>{listing.title}</h3>
                <strong>JMD {listing.priceJmd.toLocaleString()} / month</strong>
                <p className="listing-meta">
                  {listing.bedrooms} bed · {listing.bathrooms} bath ·{" "}
                  {listing.sizeSqFt.toLocaleString()} sq ft
                </p>

                {mode === "for-you" && (
                  <ul className="reasons">
                    {reasons.slice(0, 4).map((reason) => (
                      <li key={reason.label} data-match={reason.matched}>
                        {reason.matched ? "✓" : "△"} {reason.label}
                      </li>
                    ))}
                  </ul>
                )}

                <div className="listing-actions">
                  <button
                    className="primary"
                    onClick={() =>
                      setSaved((current) =>
                        current.includes(listing.id)
                          ? current.filter((id) => id !== listing.id)
                          : [...current, listing.id],
                      )
                    }
                  >
                    {saved.includes(listing.id) ? "Saved" : "Save"}
                  </button>
                  <button
                    className="secondary"
                    onClick={() =>
                      setHidden((current) => [...current, listing.id])
                    }
                  >
                    Not for me
                  </button>
                </div>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="seller-band" id="sell">
        <p className="eyebrow">THINKING ABOUT SELLING?</p>
        <h2>Understand the demand before we simply list the property.</h2>
        <p>
          OpenHouse is being designed to connect seller inventory with active,
          matching prospect demand while keeping sellers informed about views,
          saves, enquiries, viewings, feedback, and offers.
        </p>
        <button>Start with my property</button>
      </section>

      <section className="management-band" id="manage">
        <p className="eyebrow">PROPERTY MANAGEMENT</p>
        <h2>
          Own the property. Understand what is happening without running it
          yourself.
        </h2>
      </section>
    </main>
  );
}
