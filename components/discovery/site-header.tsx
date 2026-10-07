"use client";
import { useState } from "react";
export function SiteHeader() {
  const [open, setOpen] = useState(false);
  return (
    <header className="site-header">
      <a className="brand" href="/" aria-label="Open House Realty home">
        <img src="/brand/logo-blue.png" alt="Open House Realty" />
      </a>
      <button
        className="menu-toggle"
        aria-expanded={open}
        aria-controls="discovery-nav"
        onClick={() => setOpen(!open)}
      >
        ☰ <span>Menu</span>
      </button>
      <nav
        id="discovery-nav"
        className={open ? "open" : ""}
        aria-label="Main navigation"
      >
        <a href="/listings?intent=sale">Buy</a>
        <a href="/listings?intent=rent">Rent</a>
        <a href="/realtors">Our realtors</a>
        <a href="/open-houses">Open houses</a>
        <a href="/sell">Sell</a>
        <a href="/#manage">Services</a>
        <a href="/inventory">Live properties</a>
        <a href="/demo">Demo</a>
        <a href="/account">My account</a>
      </nav>
      <a className="header-cta" href="/realtors#match">
        Find your realtor ↗
      </a>
    </header>
  );
}
