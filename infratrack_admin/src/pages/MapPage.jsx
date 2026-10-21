import { useEffect, useMemo, useRef, useState } from "react";
import L, { divIcon } from "leaflet";
import "leaflet.markercluster/dist/MarkerCluster.css";
import { MapContainer, Marker, Popup, TileLayer, ZoomControl, useMap } from "react-leaflet";
import { Search, X } from "lucide-react";

import { getBarangayMapCenter, normalizeBarangayName } from "../barangayMap";
import { searchAddressLocations } from "../mapSearch";

let markerClusterPluginPromise;

function loadMarkerClusterPlugin() {
  globalThis.L = L;
  markerClusterPluginPromise ??= import("leaflet.markercluster");
  return markerClusterPluginPromise;
}

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
  const severity = String(issue.severity || "medium").toLowerCase();
  const categoryInitial = escapeHtmlAttribute(
    String(issue.category || "?").slice(0, 1).toUpperCase(),
  );
  const markerContent = issue.media_url
    ? `<img src="${escapeHtmlAttribute(issue.media_url)}" alt="" />`
    : `<span>${categoryInitial}</span>`;
  return divIcon({
    className: "leaflet-issue-icon",
    iconSize: [44, 54],
    iconAnchor: [22, 52],
    popupAnchor: [0, -50],
    html: `
      <div class="leaflet-pin ${severity}">
        <i class="leaflet-pin-tail"></i>
        <span class="leaflet-pin-ring">
          <span class="leaflet-pin-photo">${markerContent}</span>
          <i class="leaflet-pin-center"></i>
        </span>
        <i class="leaflet-pin-status"></i>
      </div>
    `,
  });
}

function issueClusterIcon(cluster) {
  const count = cluster.getChildCount();
  return divIcon({
    className: "leaflet-issue-cluster-icon",
    iconSize: [44, 44],
    iconAnchor: [22, 22],
    html: `<span class="leaflet-issue-cluster" title="${count} reports"><span>${count}</span></span>`,
  });
}

function bindIssuePopup(marker, issue) {
  const popupContent = document.createElement("div");
  popupContent.textContent = issue.title || "Infrastructure report";
  marker.bindPopup(popupContent);
}

function issueCoordinates(issue) {
  if (
    issue.latitude == null ||
    issue.latitude === "" ||
    issue.longitude == null ||
    issue.longitude === ""
  ) {
    return null;
  }
  const latitude = Number(issue.latitude);
  const longitude = Number(issue.longitude);
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    Math.abs(latitude) > 90 ||
    Math.abs(longitude) > 180
  ) {
    return null;
  }
  return [latitude, longitude];
}

function ClusteredIssues({ issues, onOpenIssue }) {
  const map = useMap();
  const [clusterUnavailable, setClusterUnavailable] = useState(false);
  const onOpenIssueRef = useRef(onOpenIssue);

  useEffect(() => {
    onOpenIssueRef.current = onOpenIssue;
  }, [onOpenIssue]);

  useEffect(() => {
    let active = true;
    let clusterGroup;
    setClusterUnavailable(false);

    loadMarkerClusterPlugin()
      .then(() => {
        if (!active) return;
        clusterGroup = L.markerClusterGroup({
          maxClusterRadius: 44,
          spiderfyOnMaxZoom: true,
          zoomToBoundsOnClick: true,
          showCoverageOnHover: false,
          iconCreateFunction: issueClusterIcon,
        });
        for (const issue of issues) {
          const coordinates = issueCoordinates(issue);
          if (!coordinates) continue;
          const marker = L.marker(coordinates, {
            icon: issuePinIcon(issue),
          });
          bindIssuePopup(marker, issue);
          marker.on("click", () => onOpenIssueRef.current?.(issue));
          clusterGroup.addLayer(marker);
        }
        map.addLayer(clusterGroup);
      })
      .catch((error) => {
        console.error("Could not load clustered map markers.", error);
        if (active) setClusterUnavailable(true);
      });

    return () => {
      active = false;
      if (clusterGroup) map.removeLayer(clusterGroup);
    };
  }, [issues, map]);

  if (!clusterUnavailable) return null;
  return issues.map((issue) => {
    const coordinates = issueCoordinates(issue);
    if (!coordinates) return null;
    return (
      <Marker
        key={issue.id || issue.public_id}
        position={coordinates}
        icon={issuePinIcon(issue)}
        eventHandlers={{ click: () => onOpenIssueRef.current?.(issue) }}
      >
        <Popup>{issue.title}</Popup>
      </Marker>
    );
  });
}

function escapeHtmlAttribute(value) {
  return value.replace(/[&"'<>]/g, (character) => ({
    "&": "&amp;",
    '"': "&quot;",
    "'": "&#39;",
    "<": "&lt;",
    ">": "&gt;",
  })[character]);
}

export function LeafletInfrastructureMap({ large = false, onOpenIssue, issues = [], barangay }) {
  const [mapLayer, setMapLayer] = useState("street");
  const [map, setMap] = useState(null);
  const normalizedBarangay = normalizeBarangayName(barangay);
  const barangayCenter = getBarangayMapCenter(barangay);
  const center = barangayCenter || (normalizedBarangay
    ? [6.951, 126.231]
    : issues[0]
      ? [Number(issues[0].latitude) || 6.951, Number(issues[0].longitude) || 126.231]
      : [6.951, 126.231]);
  const zoom = barangayCenter ? 15 : 14;
  const recenterKey = barangayCenter ? normalizedBarangay : "citywide";

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
        <ClusteredIssues issues={issues} onOpenIssue={onOpenIssue} />
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
