// Distance helpers for the worker-matching engine.
// All distances are in kilometres.

const EARTH_RADIUS_KM = 6371;

/**
 * Great-circle distance between two lat/lng points (Haversine formula).
 */
export function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_KM * c;
}

/**
 * True when point 2 is within `radiusKm` of point 1.
 */
export function withinRadiusKm(lat1, lon1, lat2, lon2, radiusKm) {
  return haversineKm(lat1, lon1, lat2, lon2) <= radiusKm;
}
