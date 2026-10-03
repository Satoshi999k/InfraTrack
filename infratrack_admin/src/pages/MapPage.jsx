import { useEffect, useMemo, useState } from "react";
import { divIcon } from "leaflet";
import { MapContainer, Marker, Popup, TileLayer, ZoomControl, useMap } from "react-leaflet";
import { Search, X } from "lucide-react";

import { searchAddressLocations } from "../mapSearch";

function LeafletResizeHandler() {
  const map = useMap();

  useEffect(() => {
    const resize = () => map.invalidateSize();
    resize();
    window.addEventListener("resize", resize);
    return () => window.removeEventListener("resize", resize);
  }, [map]);

  return null;
}

function MapViewport({ center, zoom, recenterKey }) {
  const map = useMap();

  useEffect(() => {
    map.setView(center, zoom, { animate: false });
  // Recenter only when the selected account/barangay changes. Do not reset
  // the user's pan or zoom when issues refresh or the map re-renders.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recenterKey, map]);

  return null;
}

function MapSearchControl({ issues, map }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [searching, setSearching] = useState(false);

  const search = async (event) => {
    event?.preventDefault();
    const term = query.trim();
    if (!term) return;
    setSearching(true);
    try {
      const data = await searchAddressLocations(term, issues);
      if (data.length) {
        setResults(data);
        map?.flyTo([Number(data[0].lat), Number(data[0].lon)], 16);
      } else {
        setResults([]);
      }
    } catch {
      setResults([]);
    } finally {
      setSearching(false);
    }
  };

  return (
    <div className="map-search-float">
      <form onSubmit={search} className="map-search-form">
        <Search className="map-search-icon" size={15} />
        <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search street or barangay" aria-label="Search street or barangay" />
        {query && <button type="button" className="map-search-clear" onClick={() => { setQuery(""); setResults([]); }}><X size={13} /></button>}
        <button type="submit" className="map-search-submit" disabled={searching}>{searching ? "…" : "Search"}</button>
      </form>
      {results.length > 0 && (
        <div className="map-search-results">
          {results.map((result, index) => (
            <button key={`${result.place_id ?? result.display_name}-${index}`} onClick={() => { map?.flyTo([Number(result.lat), Number(result.lon)], 16); setResults([]); }}>
              <Search size={12} /> <span>{result.display_name}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function issuePinIcon(issue) {
  const severity = issue.severity.toLowerCase();
  const photoCategory = issue.category.toLowerCase();
  return divIcon({
    className: "leaflet-issue-icon",
    iconSize: [40, 48],
    iconAnchor: [20, 44],
    popupAnchor: [0, -42],
    html: `
      <div class="leaflet-pin ${severity}">
        <span class="leaflet-pin-ring">
          <span class="leaflet-pin-photo ${photoCategory}-photo"></span>
        </span>
        <i class="leaflet-pin-status"></i>
      </div>
    `,
  });
}

const barangayCenters = {
  "Brgy. Central": [6.9612515, 126.2069944],
  "Brgy. Dawan": [6.8993278, 126.15106],
  "Brgy. Sainz": [6.9588636, 126.2201871],
  "Brgy. Matiao": [6.9450796, 126.2323952],
  "Brgy. Dahican": [6.9466732, 126.2603384],
};

export function LeafletInfrastructureMap({ large = false, onOpenIssue, issues = [], barangay }) {
  const [mapLayer, setMapLayer] = useState("street");
  const [map, setMap] = useState(null);
  const normalizedBarangay = barangay && (barangayCenters[barangay] ? barangay : Object.keys(barangayCenters).find((name) => name.toLowerCase().includes(String(barangay).toLowerCase())));
  const center = barangayCenters[normalizedBarangay] || (issues[0] ? [Number(issues[0].latitude) || 6.951, Number(issues[0].longitude) || 126.231] : [6.951, 126.231]);
  const zoom = normalizedBarangay ? 15 : 14;
  const recenterKey = normalizedBarangay || "citywide";

  return (
    <div className={`leaflet-map-wrap ${large ? "large" : ""}`}>
      <MapContainer
        center={center}
        zoom={zoom}
        scrollWheelZoom={true}
        zoomControl={false}
        className="leaflet-map"
        whenReady={(event) => setMap(event.target)}
      >
        <ZoomControl position="topright" />
        {mapLayer === "street" ? (
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
        ) : (
          <TileLayer
            attribution='Tiles &copy; Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community'
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
          />
        )}
        <LeafletResizeHandler />
        <MapViewport center={center} zoom={zoom} recenterKey={recenterKey} />
        {issues.map((issue) => (
          <Marker
            key={issue.id || issue.public_id}
            position={[Number(issue.latitude) || 6.951, Number(issue.longitude) || 126.231]}
            icon={issuePinIcon(issue)}
            eventHandlers={{ click: () => onOpenIssue?.(issue) }}
          >
            <Popup>{issue.title}</Popup>
          </Marker>
        ))}
      </MapContainer>
      <MapSearchControl issues={issues} map={map} />
      <div className="map-layer-switcher" role="group" aria-label="Map layer">
        <button className={mapLayer === "street" ? "active" : ""} onClick={() => setMapLayer("street")}>Street</button>
        <button className={mapLayer === "satellite" ? "active" : ""} onClick={() => setMapLayer("satellite")}>Satellite</button>
      </div>
      <div className="map-legend">
        <b>Issue severity</b>
        <span><i className="legend-dot critical" /> Critical</span>
        <span><i className="legend-dot high" /> High</span>
        <span><i className="legend-dot medium" /> Medium</span>
        <span><i className="legend-dot resolved" /> Resolved</span>
      </div>
    </div>
  );
}

export default function MapPage({ onOpenIssue, issues = [], user }) {
  const [category, setCategory] = useState("all");
  const filteredIssues = useMemo(
    () => category === "all" ? issues : issues.filter((issue) => issue.category === category),
    [issues, category],
  );

  return (
    <article className="card full-map">
      <div className="card-head">
        <h2>{user?.barangay ? `${user.barangay} infrastructure map` : "City-wide infrastructure map"}</h2>
        <div className="filters" style={{ marginBottom: 0 }}>
          {[['all', 'All issues'], ['Roads', 'Roads'], ['Water', 'Water'], ['Drainage', 'Drainage'], ['Lighting', 'Lighting']].map(([value, label]) => (
            <button key={value} className={`filter ${category === value ? "active" : ""}`} onClick={() => setCategory(value)}>{label}</button>
          ))}
        </div>
      </div>
      <LeafletInfrastructureMap large issues={filteredIssues} onOpenIssue={onOpenIssue} barangay={user?.barangay} />
    </article>
  );
}
