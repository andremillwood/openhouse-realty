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
  const [query, setQuery] = useState("");
  const [search, setSearch] = useState("");
  const [intent, setIntent] = useState<"all" | "sale" | "rent">("all");
  const [menuOpen, setMenuOpen] = useState(false);
  const [savedOnly, setSavedOnly] = useState(false);
  const [mode, setMode] = useState<"for-you" | "search">("for-you");
  const [profile, setProfile] = useState(initialProfile);
  const [saved, setSaved] = useState<string[]>([]);
  const [hidden, setHidden] = useState<string[]>([]);

  const matches = useMemo(
    () =>
      rankListings(
        listings.filter((listing) => !hidden.includes(listing.id) && (!savedOnly || saved.includes(listing.id)) && (intent === "all" || listing.intent === intent) && `${listing.title} ${listing.area} ${listing.propertyType}`.toLowerCase().includes(search.toLowerCase())),
        profile,
      ),
    [hidden, profile, search, intent, saved, savedOnly],
  );

  return (
    <main>
      <a className="skip-link" href="#homes">Skip to properties</a>
      <header className="site-header">
        <a className="brand" href="#" aria-label="Open House Realty home"><img src="/brand/logo-blue.png" alt="Open House Realty — Unlocking value, building connections" /></a>
        <button className="menu-toggle" aria-expanded={menuOpen} aria-controls="main-nav" onClick={() => setMenuOpen(!menuOpen)}>☰ <span>Menu</span></button>
        <nav id="main-nav" className={menuOpen ? "open" : ""} aria-label="Main navigation">
          <a href="/demo/listings?intent=sale">Buy</a>
          <a href="/demo/listings?intent=rent">Rent</a>
          <a href="#sell">Sell</a><a href="/demo/realtors">Our realtors</a><a href="#manage">Services</a><a href="/demo">Demo</a>
        </nav>
        <a className="header-cta" href="/demo/listings">Find your home <span aria-hidden="true">↗</span></a>
      </header>
      <section className="hero">
        <div className="hero-content">
          <p className="eyebrow">PEOPLE. PROPERTY. POSSIBILITIES.</p>
          <h1>Find more<br />than a property.</h1>
          <p className="hero-copy">Find what moves you.</p>
          <p className="hero-caption">Homes. People. Possibilities. Jamaica and beyond.</p>
          <form className="search-box" onSubmit={(event) => { event.preventDefault(); setSearch(query); setSavedOnly(false); document.getElementById("homes")?.scrollIntoView({ behavior: "smooth" }); }}>
            <div className="search-tabs" aria-label="Property intent">
              {(["all", "sale", "rent"] as const).map(value => <button type="button" key={value} aria-pressed={intent === value} className={intent === value ? "active" : ""} onClick={() => setIntent(value)}>{value === "all" ? "All homes" : value === "sale" ? "Buy" : "Rent"}</button>)}
            </div>
            <div className="search-row"><span aria-hidden="true">⌕</span><input aria-label="Search by location, property name or type" placeholder="Search location, property name, or type…" value={query} onChange={event => setQuery(event.target.value)} /><button type="submit">Search <span aria-hidden="true">↗</span></button></div>
          </form>
          <div className="hero-categories"><span>⌂ Houses</span><span>▥ Apartments</span><span>♧ Land</span><span>▤ Commercial</span></div>
        </div>
        <div className="hero-bottom"><span>YOUR NEXT CHAPTER STARTS HERE</span><span>Unlocking value,<br />building connections.</span></div>
        <span className="photo-caption">Illustrative property photography</span>
      </section>
      <section className="marketplace" id="homes">
        <div className="section-heading">
          <div>
            <p className="eyebrow">A PLACE TO CALL HOME</p>
            <h2>{savedOnly ? "Your saved homes" : mode === "for-you" ? "Homes, chosen for you." : "Explore the possibilities."}</h2>
          </div>
          <div className="segmented" aria-label="Discovery mode">
            <button aria-pressed={savedOnly} className={savedOnly ? "active" : ""} onClick={() => setSavedOnly(!savedOnly)}>Saved ({saved.length})</button>
            <button
              className={mode === "for-you" ? "active" : ""}
              onClick={() => { setMode("for-you"); setSavedOnly(false); }}
            >
              For You
            </button>
            <button
              className={mode === "search" ? "active" : ""}
              onClick={() => { setMode("search"); setSavedOnly(false); }}
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

        <a className="browse-link" href="/demo/listings">Explore all homes on the map ↗</a>
        <div className="inventory-note">Demo homes · illustrative photos · saves last for this visit</div>
        {matches.length === 0 && <div className="empty-state"><h3>No homes found</h3><p>Try another location or explore all our demo homes.</p><button onClick={() => { setQuery(""); setSearch(""); setIntent("all"); setSavedOnly(false); setHidden([]); }}>Show all homes</button></div>}
        <div className="listing-grid" aria-live="polite">
          {matches.map(({ listing, score, reasons }) => (
            <article className="listing-card" key={listing.id}>
              <div className="listing-image">
                <img src={`https://images.unsplash.com/${listing.id === "residence-8c" ? "photo-1600596542815-ffad4c1539a9" : listing.id === "residence-6a" ? "photo-1600607687920-4e2a09cf159d" : "photo-1600047509807-ba8f99d2cdde"}?auto=format&fit=crop&w=900&q=85`} alt={`Illustrative home for ${listing.title}`} loading="lazy" />
                <span className="listing-label">FOR RENT</span>
                {mode === "for-you" && (
                  <span className="match-badge">{score}% match</span>
                )}
              </div>
              <div className="listing-content">
                <p className="eyebrow">{listing.area}</p>
                <h3><a href={`/demo/listings/${listing.id}`}>{listing.title} ↗</a></h3>
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
                    aria-pressed={saved.includes(listing.id)}
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
        <h2>Your property.<br />Its next possibility.</h2>
        <p>
          OpenHouse is being designed to connect seller inventory with active,
          matching prospect demand while keeping sellers informed about views,
          saves, enquiries, viewings, feedback, and offers.
        </p>
        <a className="button-link" href="mailto:ohrealty@flashcreate.co?subject=Property%20valuation%20enquiry">Let’s talk about your property ↗</a>
      </section>

      <section className="management-band" id="manage">
        <p className="eyebrow">PROPERTY MANAGEMENT</p>
        <h2>
          More peace of mind.
          More from your property.
        </h2>
        <p className="service-copy">From finding the right resident to caring for the details, discover a more connected approach to property management.</p>
        <a className="button-link" href="mailto:ohrealty@flashcreate.co?subject=Property%20management%20enquiry">Explore management services ↗</a>
      </section>
      <footer id="about"><img src="/brand/logo-white.png" alt="Open House Realty" /><div><h2>People. Property. Possibilities.</h2><p>A modern real estate platform for a brighter Jamaica.</p><a href="mailto:ohrealty@flashcreate.co">ohrealty@flashcreate.co ↗</a></div><p className="footer-bottom">© {new Date().getFullYear()} Open House Realty · Jamaica</p></footer>
      <nav className="mobile-nav" aria-label="Mobile navigation"><a href="#">⌂<span>Home</span></a><a href="/demo/listings">⌕<span>Search</span></a><a href="#homes" onClick={() => setSavedOnly(true)}>♡<span>Saved ({saved.length})</span></a><a href="mailto:ohrealty@flashcreate.co">✉<span>Contact</span></a></nav>
    </main>
  );
}
